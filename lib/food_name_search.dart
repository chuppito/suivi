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
   final urls=[
    Uri.https('search.openfoodfacts.org','/search',{'q':name,'langs':'fr,en','page_size':'30'}),
    Uri.https('world.openfoodfacts.org','/cgi/search.pl',{'search_terms':name,'search_simple':'1','action':'process','json':'1','page_size':'30','fields':'code,product_name,nutriments'}),
   ];
   final failures=<String>[];
   bool onlineSuccess=false;
   for(final uri in urls){
    try{
     final response=await http.get(uri,headers:{'User-Agent':'SuiviNutritionCorps/0.2 (https://github.com/chuppito/suivi)','Accept':'application/json'}).timeout(const Duration(seconds:10));
     if(response.statusCode!=200){failures.add(uri.host+': HTTP '+response.statusCode.toString());continue;}
     final data=jsonDecode(response.body);
     if(data is! Map){failures.add(uri.host+': format inattendu');continue;}
     final map=Map<String,dynamic>.from(data);
     final products=map['products']??map['hits']??map['results'];
     if(products is! List){failures.add(uri.host+': résultats non reconnus');continue;}
     onlineSuccess=true;
     for(final raw in products){
      if(raw is! Map)continue;
      final p=Map<String,dynamic>.from(raw);
      final source=p['_source'] is Map?Map<String,dynamic>.from(p['_source'] as Map):p;
      final label=(source['product_name_fr']??source['product_name']??'').toString().trim();
      if(label.isEmpty||source['nutriments'] is! Map)continue;
      final n=Map<String,dynamic>.from(source['nutriments'] as Map);
      var kcal=number(n['energy-kcal_100g']);
      if(kcal<=0){final kj=number(n['energy-kj_100g']);if(kj>0)kcal=kj/4.184;}
      if(kcal<=0||found.any((f)=>f.name.toLowerCase()==label.toLowerCase()))continue;
      found.add(FoodScanResult(label,kcal,number(n['proteins_100g']),number(n['carbohydrates_100g']),number(n['fat_100g']),100));
     }
     if(found.isNotEmpty)break;
    }catch(e){failures.add(uri.host+': '+e.runtimeType.toString());}
   }
   if(!onlineSuccess&&failures.isNotEmpty)error='Recherche en ligne indisponible : '+failures.join(' ; ')+'. Bibliothèque locale disponible.';
   else if(found.isEmpty)error='Aucun produit trouvé. Essaie un autre nom ou scanne son code-barres.';
  }catch(e){error='Erreur de recherche : '+e.runtimeType.toString();}

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
