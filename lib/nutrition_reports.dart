import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:archive/archive.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class NutritionReports {
 static String key(DateTime d)=>d.toIso8601String().substring(0,10);
 static String csv(List<String> keys,List<Map<String,Object?>> rows){
  String quote(Object? v)=>'"'+(v??'').toString().replaceAll('"','""')+'"';
  return '\uFEFF'+keys.map(quote).join(';')+'\r\n'+rows.map((r)=>keys.map((k)=>quote(r[k])).join(';')).join('\r\n');
 }
 static Future<void> exportCsv(Database db) async{
  final zip=Archive();
  for(final table in ['meals','measures','supplements','intakes','activities','food_library']){
   final rows=await db.query(table);
   final cols=rows.isEmpty?<String>[]:rows.first.keys.toList();
   final bytes=utf8.encode(csv(cols,rows));
   zip.addFile(ArchiveFile(table+'.csv',bytes.length,bytes));
  }
  final meals=await db.query('meals');
  final days=<String,Map<String,Object?>>{};
  for(final m in meals){
   final date=m['date'].toString();
   final row=days.putIfAbsent(date,()=>{'date':date,'calories':0.0,'protein':0.0,'carbs':0.0,'fat':0.0,'meals':0});
   for(final k in ['calories','protein','carbs','fat']){row[k]=(row[k] as double)+((m[k] as num?)?.toDouble()??0);}
   row['meals']=(row['meals'] as int)+1;
  }
  final summary=utf8.encode(csv(['date','calories','protein','carbs','fat','meals'],days.values.toList()));
  zip.addFile(ArchiveFile('totaux_par_jour.csv',summary.length,summary));
  final file=File(p.join((await getTemporaryDirectory()).path,'suivi_nutrition_csv.zip'));
  await file.writeAsBytes(ZipEncoder().encode(zip));
  await Share.shareXFiles([XFile(file.path)]);
 }
 static Future<ReportData> report(Database db,int days) async{
  final now=DateTime.now(),end=DateTime(now.year,now.month,now.day),start=end.subtract(Duration(days:days-1));
  final meals=await db.query('meals',where:'date>=? AND date<=?',whereArgs:[key(start),key(end)]);
  final measures=await db.query('measures',where:'date>=? AND date<=?',whereArgs:[key(start),key(end)],orderBy:'date ASC');
  final dates=meals.map((m)=>m['date'].toString()).toSet();
  final missing=<String>[],missingMeasures=<String>[];
  for(var i=0;i<days;i++){
   final d=key(start.add(Duration(days:i)));
   if(!dates.contains(d))missing.add(d);
   if(!measures.any((m)=>m['date']==d))missingMeasures.add(d);
  }
  double mean(String field)=>dates.isEmpty?0:meals.fold<double>(0,(a,m)=>a+((m[field] as num?)?.toDouble()??0))/dates.length;
  double? change(String field){
   final valid=measures.where((m)=>m[field] is num).toList();
   if(valid.length<2)return null;
   return (valid.last[field] as num).toDouble()-(valid.first[field] as num).toDouble();
  }
  return ReportData(days,dates.length,missing,missingMeasures,measures,mean('calories'),mean('protein'),mean('carbs'),mean('fat'),change('weight'),change('waist'));
 }
 static Future<void> exportPdf(Database db) async{
  final r=await report(db,30);
  final doc=pw.Document();
  pw.Widget graph(String field,String title){
   final points=r.measures.where((m)=>m[field] is num).toList();
   if(points.length<2)return pw.Text(title+': données insuffisantes');
   final values=points.map((m)=>(m[field] as num).toDouble()).toList();
   final low=values.reduce((a,b)=>a<b?a:b),high=values.reduce((a,b)=>a>b?a:b);
   final span=high-low==0?1.0:high-low;
   return pw.Column(crossAxisAlignment:pw.CrossAxisAlignment.start,children:[
    pw.Text(title),pw.SizedBox(height:8),
    pw.SizedBox(height:90,child:pw.CustomPaint(painter:(canvas,size){
     for(var i=1;i<values.length;i++){
      canvas.setStrokeColor(PdfColors.teal);
      canvas.setLineWidth(2);
      canvas.drawLine((i-1)/(values.length-1)*size.x,(values[i-1]-low)/span*size.y,i/(values.length-1)*size.x,(values[i]-low)/span*size.y);
      canvas.strokePath();
     }
    })),
    pw.Text('Début : '+values.first.toStringAsFixed(1)+' / Fin : '+values.last.toStringAsFixed(1)),
   ]);
  }
  doc.addPage(pw.MultiPage(build:(context)=>[
   pw.Header(level:0,text:'Bilan nutritionnel - 30 jours'),
   pw.Text('Jours renseignés : '+r.recorded.toString()+' / 30'),
   pw.Text('Calories moyennes : '+r.kcal.toStringAsFixed(0)+' kcal'),
   pw.Text('Protéines : '+r.protein.toStringAsFixed(1)+' g ; glucides : '+r.carbs.toStringAsFixed(1)+' g ; lipides : '+r.fat.toStringAsFixed(1)+' g'),
   pw.Text('Variation du poids : '+(r.weightDelta?.toStringAsFixed(2)??'non disponible')+' kg'),
   pw.Text('Variation du tour de taille : '+(r.waistDelta?.toStringAsFixed(2)??'non disponible')+' cm'),
   pw.SizedBox(height:16),graph('weight','Évolution du poids'),pw.SizedBox(height:16),graph('waist','Évolution du tour de taille'),
   pw.Text('Jours sans repas : '+r.missingMeals.length.toString()+' ; sans mesure : '+r.missingMeasures.length.toString()),
   pw.Text('Les jours sans repas saisi sont exclus des moyennes. Les estimations restent indicatives.'),
  ]));
  final file=File(p.join((await getTemporaryDirectory()).path,'bilan_nutrition_30_jours.pdf'));
  await file.writeAsBytes(await doc.save());
  await Share.shareXFiles([XFile(file.path)]);
 }
}
class ReportData {
 final int days,recorded;
 final List<String> missingMeals,missingMeasures;
 final List<Map<String,Object?>> measures;
 final double kcal,protein,carbs,fat;
 final double? weightDelta,waistDelta;
 ReportData(this.days,this.recorded,this.missingMeals,this.missingMeasures,this.measures,this.kcal,this.protein,this.carbs,this.fat,this.weightDelta,this.waistDelta);
}
class ReportsPage extends StatelessWidget {
 final Database db;
 const ReportsPage({super.key,required this.db});
 @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Bilans et exports')),
 body:ListView(children:[
  for(final days in [7,30])FutureBuilder<ReportData>(future:NutritionReports.report(db,days),builder:(ctx,s){
   if(!s.hasData)return const ListTile(title:Text('Chargement...'));
   final r=s.data!;
   String n(double v)=>v.toStringAsFixed(1);
   return Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Text('Bilan sur '+days.toString()+' jours',style:Theme.of(context).textTheme.titleLarge),
    Text(r.recorded.toString()+' jours avec repas'),
    Text('Moyenne : '+n(r.kcal)+' kcal • protéines '+n(r.protein)+' g'),
    Text('Glucides : '+n(r.carbs)+' g • lipides : '+n(r.fat)+' g'),
    Text('Variation poids : '+(r.weightDelta?.toStringAsFixed(2)??'—')+' kg'),
    Text('Variation taille : '+(r.waistDelta?.toStringAsFixed(2)??'—')+' cm'),
    Text('Jours sans repas : '+r.missingMeals.length.toString()),
    Text('Jours sans mesure : '+r.missingMeasures.length.toString()),
    if(r.missingMeals.isNotEmpty)ExpansionTile(title:const Text('Dates sans repas'),children:[for(final d in r.missingMeals)ListTile(dense:true,title:Text(d))]),
    const Text('Moyennes sur les jours renseignés uniquement.',style:TextStyle(fontSize:12)),
   ])));
  }),
  ListTile(leading:const Icon(Icons.table_chart),title:const Text('Exporter mes données CSV'),subtitle:const Text('ZIP avec CSV séparés et totaux quotidiens'),onTap:()async{try{await NutritionReports.exportCsv(db);}catch(e){if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Export impossible : '+e.toString())));}}),
  ListTile(leading:const Icon(Icons.picture_as_pdf),title:const Text('Rapport PDF des 30 derniers jours'),onTap:()async{try{await NutritionReports.exportPdf(db);}catch(e){if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('PDF impossible : '+e.toString())));}}),
 ]));
}
