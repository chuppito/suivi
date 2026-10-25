import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_scanner/mobile_scanner.dart';

class FoodScanResult {
 final String name;
 final double kcal, protein, carbs, fat, grams;
 const FoodScanResult(this.name,this.kcal,this.protein,this.carbs,this.fat,this.grams);
}
class FoodBarcodeScanner extends StatefulWidget {
 const FoodBarcodeScanner({super.key});
 @override State<FoodBarcodeScanner> createState()=>_FoodBarcodeScannerState();
}
class _FoodBarcodeScannerState extends State<FoodBarcodeScanner> {
 final controller=MobileScannerController();
 bool loading=false;
 String? error;
 Future<void> lookup(String barcode) async {
  if(loading)return;
  setState((){loading=true;error=null;});
  try {
   final uri=Uri.https('world.openfoodfacts.org','/api/v2/product/'+barcode+'.json',{'fields':'product_name,product_quantity,nutriments'});
   final response=await http.get(uri,headers:{'User-Agent':'SuiviNutritionCorps/0.1 (github.com/chuppito/suivi)','Accept':'application/json'}).timeout(const Duration(seconds:12));
   if(response.statusCode!=200)throw Exception('Service indisponible');
   final data=jsonDecode(response.body) as Map<String,dynamic>;
   if(data['status']!=1)throw Exception('Produit absent de Open Food Facts');
   final product=data['product'] as Map<String,dynamic>;
   final nutrients=(product['nutriments'] as Map<String,dynamic>?)??{};
   double? number(dynamic v)=>v is num?v.toDouble():double.tryParse(v?.toString()??'');
   final kcal=number(nutrients['energy-kcal_100g'])??((number(nutrients['energy_100g'])??0)/4.184);
   if(kcal<=0)throw Exception('Calories non renseignées pour ce produit');
   final grams=number(product['product_quantity'])??100;
   if(!mounted)return;
   Navigator.of(context).pop(FoodScanResult((product['product_name']??'Produit scanné').toString(),kcal,number(nutrients['proteins_100g'])??0,number(nutrients['carbohydrates_100g'])??0,number(nutrients['fat_100g'])??0,grams>0?grams:100));
  }catch(e){if(mounted)setState(()=>error=e.toString().replaceFirst('Exception: ',''));}
  finally{if(mounted)setState(()=>loading=false);}
 }
 @override void dispose(){controller.dispose();super.dispose();}
 @override Widget build(BuildContext context)=>Scaffold(
  appBar:AppBar(title:const Text('Scanner un produit')),
  body:Column(children:[
   Expanded(child:MobileScanner(controller:controller,onDetect:(capture){
    if(loading)return;
    final codes=capture.barcodes;
    if(codes.isNotEmpty&&codes.first.rawValue!=null)lookup(codes.first.rawValue!);
   })),
   if(loading)const Padding(padding:EdgeInsets.all(16),child:CircularProgressIndicator()),
   if(error!=null)Padding(padding:const EdgeInsets.all(16),child:Text(error!,style:const TextStyle(color:Colors.red))),
   const Padding(padding:EdgeInsets.all(16),child:Text('Scanne le code-barres. Données fournies par Open Food Facts.')),
  ]),
 );
}
