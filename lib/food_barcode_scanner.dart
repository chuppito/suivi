import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:sqflite/sqflite.dart';

class FoodScanResult {
 final String name;
 final double kcal,protein,carbs,fat,grams;
 const FoodScanResult(this.name,this.kcal,this.protein,this.carbs,this.fat,this.grams);
}
class FoodBarcodeScanner extends StatefulWidget {
 final Database db;
 const FoodBarcodeScanner({super.key,required this.db});
 @override State<FoodBarcodeScanner> createState()=>_FoodBarcodeScannerState();
}
class _FoodBarcodeScannerState extends State<FoodBarcodeScanner> {
 final controller=MobileScannerController();
 final manual=TextEditingController();
 bool loading=false,scanning=true;
 String? error;
 String? barcode;
 Map<String,dynamic>? online;
 List<Map<String,Object?>> suggestions=[];
 Future<void> lookup(String code) async {
  if(loading)return;
  setState((){loading=true;error=null;barcode=code;scanning=false;online=null;suggestions=[];});
  await controller.stop();
  try{
   final local=await widget.db.query('food_library',where:'barcode=?',whereArgs:[code],limit:1);
   if(local.isNotEmpty){if(mounted)showProduct(local.first);return;}
   final uri=Uri.https('world.openfoodfacts.org','/api/v2/product/$code.json',{'fields':'product_name,product_quantity,nutriments'});
   final response=await http.get(uri,headers:{'User-Agent':'SuiviNutritionCorps/0.2 (https://github.com/chuppito/suivi)','Accept':'application/json'}).timeout(const Duration(seconds:10));
   if(response.statusCode==200){
    final data=jsonDecode(response.body) as Map<String,dynamic>;
    if(data['status']==1){online=data['product'] as Map<String,dynamic>;if(mounted)await showOnline();return;}
   }
   if(mounted)await editProduct(code);
  }catch(e){if(mounted){setState(()=>error='Recherche impossible : $e');await editProduct(code);}}
  finally{if(mounted)setState(()=>loading=false);}
 }
 double? number(dynamic v)=>v is num?v.toDouble():double.tryParse(v?.toString()??'');
 Future<void> showOnline() async {
  final p=online!,n=(p['nutriments'] as Map<String,dynamic>?)??{};
  final kcal=number(n['energy-kcal_100g'])??((number(n['energy_100g'])??0)/4.184);
  if(kcal<=0){editProduct(barcode!);return;}
  final item=<String,Object?>{'barcode':barcode,'name':p['product_name']??'Produit scanné','kcal':kcal,'protein':number(n['proteins_100g'])??0,'carbs':number(n['carbohydrates_100g'])??0,'fat':number(n['fat_100g'])??0};
  await widget.db.insert('food_library',item,conflictAlgorithm:ConflictAlgorithm.replace);
  if(mounted)showProduct({...item,'grams':number(p['product_quantity'])??100});
 }
 Future<void> showProduct(Map<String,dynamic> p) async {
  if(!mounted)return;
  final name=p['name'].toString();
  final kcal=number(p['kcal'])??0,protein=number(p['protein'])??0,carbs=number(p['carbs'])??0,fat=number(p['fat'])??0;
  final grams=TextEditingController(text:(number(p['grams'])??100).toStringAsFixed(0));
  final result=await showDialog<double>(context:context,builder:(ctx)=>AlertDialog(
   title:Text(name),content:Column(mainAxisSize:MainAxisSize.min,children:[
    Text('Pour 100 g : ${kcal.toStringAsFixed(0)} kcal • ${protein.toStringAsFixed(1)} g protéines • ${fat.toStringAsFixed(1)} g lipides'),
    TextField(controller:grams,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Quantité mangée (g)')),
   ]),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Annuler')),
   FilledButton(onPressed:()=>Navigator.pop(ctx,double.tryParse(grams.text.replaceAll(',','.'))),child:const Text('Utiliser'))]));
  // Ne pas disposer le contrôleur avant la fin de l'animation du dialogue.
  if(result!=null&&result>0&&mounted)Navigator.of(context).pop(FoodScanResult(name,kcal,protein,carbs,fat,result));
 }
 Future<void> editProduct(String code) async {
  if(!mounted)return;
  final name=TextEditingController(),kcal=TextEditingController(),protein=TextEditingController(),carbs=TextEditingController(),fat=TextEditingController();
  final candidates=await widget.db.query('food_library',orderBy:'name ASC');
  if(!mounted)return;
  await showDialog<void>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,refresh)=>AlertDialog(
   title:const Text('Produit absent : créer une fiche'),
   content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
    const Text('Recopie les valeurs de l’étiquette pour 100 g. Tu peux photographier l’étiquette avec ton téléphone pour la consulter, mais elle n’est pas lue automatiquement.'),
    TextField(controller:name,decoration:const InputDecoration(labelText:'Nom du produit (ex : Grana)'),onChanged:(v)=>refresh((){})),
    if(name.text.trim().length>=2)...[
     for(final candidate in candidates.where((p)=>p['name'].toString().toLowerCase().contains(name.text.trim().toLowerCase())).take(4))
      ListTile(title:Text(candidate['name'].toString()),subtitle:const Text('Réutiliser la fiche enregistrée'),onTap:()async{
       await widget.db.insert('food_library',{'barcode':code,'name':candidate['name'],'kcal':candidate['kcal'],'protein':candidate['protein'],'carbs':candidate['carbs'],'fat':candidate['fat']},conflictAlgorithm:ConflictAlgorithm.replace);
       if(ctx.mounted)Navigator.pop(ctx);
       if(mounted)showProduct(candidate);
      }),
    ],
    for(final field in [('Calories (kcal)',kcal),('Protéines (g)',protein),('Glucides (g)',carbs),('Lipides (g)',fat)])
     TextField(controller:field.$2,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:InputDecoration(labelText:field.$1)),
   ])),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Annuler')),
   FilledButton(onPressed:()async{
    final n=name.text.trim(),k=double.tryParse(kcal.text.replaceAll(',','.'));
    if(n.isEmpty||k==null||k<0){ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content:Text('Nom et calories obligatoires.')));return;}
    double val(TextEditingController c)=>double.tryParse(c.text.replaceAll(',','.'))??0;
    final item=<String,Object?>{'barcode':code,'name':n,'kcal':k,'protein':val(protein),'carbs':val(carbs),'fat':val(fat)};
    await widget.db.insert('food_library',item,conflictAlgorithm:ConflictAlgorithm.replace);
    if(ctx.mounted)Navigator.pop(ctx);
    if(mounted)showProduct(item);
   },child:const Text('Enregistrer'))],
  )));
 }
 @override void dispose(){manual.dispose();controller.dispose();super.dispose();}
 @override Widget build(BuildContext context)=>Scaffold(
  appBar:AppBar(title:const Text('Scanner un produit')),
  body:Column(children:[
   if(scanning)Expanded(child:MobileScanner(controller:controller,onDetect:(capture){
    if(loading||capture.barcodes.isEmpty)return;
    final code=capture.barcodes.first.rawValue;
    if(code!=null&&code.isNotEmpty)lookup(code);
   }))else const Expanded(child:Center(child:Icon(Icons.inventory_2_outlined,size:72))),
   if(loading)const LinearProgressIndicator(),
   if(error!=null)Padding(padding:const EdgeInsets.all(8),child:Text(error!,style:const TextStyle(color:Colors.red))),
   Padding(padding:const EdgeInsets.all(12),child:Column(children:[
    TextField(controller:manual,keyboardType:TextInputType.number,decoration:InputDecoration(labelText:'Code-barres (saisie manuelle)',suffixIcon:IconButton(icon:const Icon(Icons.search),onPressed:()=>lookup(manual.text.trim())))),
    TextButton.icon(onPressed:()async{await controller.start();if(mounted)setState(()=>scanning=true);},icon:const Icon(Icons.qr_code_scanner),label:const Text('Reprendre le scan')),
    const Text('Open Food Facts ou bibliothèque personnelle, gratuite et conservée sur ce téléphone.'),
   ])),
  ]),
 );
}
