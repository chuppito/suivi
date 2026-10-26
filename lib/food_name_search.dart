import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';
import 'food_barcode_scanner.dart';

class FoodNameSearch extends StatefulWidget {
 final Database db;
 const FoodNameSearch({super.key,required this.db});
 @override State<FoodNameSearch> createState()=>_FoodNameSearchState();
}
class _FoodNameSearchState extends State<FoodNameSearch> {
 final query=TextEditingController();
 bool loading=false;
 String? error;
 List<FoodScanResult> results=[];
 double number(dynamic v)=>v is num?v.toDouble():double.tryParse(v?.toString()??'')??0;
 Future<void> search() async {
  final name=query.text.trim();
  if(name.length<2)return;
  setState((){loading=true;error=null;results=[];});
  final found=<FoodScanResult>[];
  try {
   final local=await widget.db.query('food_library',where:'LOWER(name) LIKE ?',whereArgs:['%'+name.toLowerCase()+'%'],limit:25);
   for(final p in local){found.add(FoodScanResult(p['name'].toString(),number(p['kcal']),number(p['protein']),number(p['carbs']),number(p['fat']),100));}
   final uri=Uri.https('world.openfoodfacts.org','/cgi/search.pl',{'search_terms':name,'search_simple':'1','action':'process','json':'1','page_size':'30','fields':'product_name,nutriments'});
   final response=await http.get(uri,headers:{'User-Agent':'SuiviNutritionCorps/0.2 (https://github.com/chuppito/suivi)'}).timeout(const Duration(seconds:12));
   if(response.statusCode==200){
    final data=jsonDecode(response.body) as Map<String,dynamic>;
    for(final raw in (data['products'] as List? ?? [])){
     if(raw is! Map)continue;
     final p=Map<String,dynamic>.from(raw),label=(p['product_name']??'').toString().trim();
     if(label.isEmpty||p['nutriments'] is! Map)continue;
     final n=Map<String,dynamic>.from(p['nutriments'] as Map);
     final kcal=number(n['energy-kcal_100g']);
     if(kcal<=0||found.any((f)=>f.name.toLowerCase()==label.toLowerCase()))continue;
     found.add(FoodScanResult(label,kcal,number(n['proteins_100g']),number(n['carbohydrates_100g']),number(n['fat_100g']),100));
    }
   }else{error='Recherche en ligne indisponible.';}
  }catch(e){error='Recherche en ligne indisponible. Résultats locaux affichés.';}
  if(mounted)setState((){results=found;loading=false;});
 }
 Future<void> choose(FoodScanResult item) async {
  final grams=TextEditingController(text:'100');
  final amount=await showDialog<double>(context:context,builder:(ctx)=>AlertDialog(
   title:Text(item.name),
   content:Column(mainAxisSize:MainAxisSize.min,children:[
    Text('Pour 100 g : '+item.kcal.toStringAsFixed(0)+' kcal'),
    TextField(controller:grams,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Quantité consommée (g ou ml)')),
   ]),
   actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Annuler')),FilledButton(onPressed:()=>Navigator.pop(ctx,double.tryParse(grams.text.replaceAll(',','.'))),child:const Text('Ajouter'))],
  ));
  if(amount!=null&&amount>0&&mounted)Navigator.pop(context,FoodScanResult(item.name,item.kcal,item.protein,item.carbs,item.fat,amount));
 }
 @override void dispose(){query.dispose();super.dispose();}
 @override Widget build(BuildContext context)=>Scaffold(
  appBar:AppBar(title:const Text('Rechercher un aliment')),
  body:Column(children:[
   Padding(padding:const EdgeInsets.all(12),child:Row(children:[
    Expanded(child:TextField(controller:query,textInputAction:TextInputAction.search,onSubmitted:(_)=>search(),decoration:const InputDecoration(labelText:'Nom de l’aliment',hintText:'Coca-Cola, pâtes, yaourt…'))),
    IconButton(onPressed:search,icon:const Icon(Icons.search)),
   ])),
   if(loading)const LinearProgressIndicator(),
   if(error!=null)Padding(padding:const EdgeInsets.all(8),child:Text(error!)),
   Expanded(child:ListView.builder(itemCount:results.length,itemBuilder:(ctx,i){
    final item=results[i];
    return ListTile(title:Text(item.name),subtitle:Text(item.kcal.toStringAsFixed(0)+' kcal / 100 g'),onTap:()=>choose(item));
   })),
  ]),
 );
}
