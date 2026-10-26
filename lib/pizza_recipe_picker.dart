import 'package:flutter/material.dart';
import 'food_barcode_scanner.dart';
import 'package:sqflite/sqflite.dart';

class PizzaSelection {
 final String description;
 final double kcal,protein,carbs,fat;
 const PizzaSelection(this.description,{this.kcal=0,this.protein=0,this.carbs=0,this.fat=0});
}
class PizzaRecipePicker extends StatefulWidget {
 final Database db;
 const PizzaRecipePicker({super.key,required this.db});
 @override State<PizzaRecipePicker> createState()=>_PizzaRecipePickerState();
}
class _PizzaRecipePickerState extends State<PizzaRecipePicker> {
 bool personal=true;
 bool cream=false;
 int eatenEighths=8;
 final dough=TextEditingController(text:'220');
 final sauce=TextEditingController(text:'60');
 final mozzarella=TextEditingController(text:'80');
 final emmental=TextEditingController(text:'0');
 final cheddar=TextEditingController(text:'0');
 final extras=TextEditingController();
 String scaledExtra(String input,double fraction){
  final match=RegExp(r'(\d+(?:[.,]\d+)?)\s*g\b',caseSensitive:false).firstMatch(input);
  if(match==null)return input;
  final grams=double.tryParse(match.group(1)!.replaceAll(',','.'));
  if(grams==null)return input;
  final name=input.replaceRange(match.start,match.end,'').trim();
  return '
 final List<String> extraItems=[];
 final List<FoodScanResult> scanned=[];
 @override void dispose(){for(final c in [dough,sauce,mozzarella,emmental,cheddar,extras]){c.dispose();}super.dispose();}
 void addExtra(){final item=extras.text.trim();if(item.isEmpty)return;setState((){extraItems.add(item);extras.clear();});}
 Widget amount(String label,TextEditingController c)=>TextField(controller:c,keyboardType:TextInputType.number,decoration:InputDecoration(labelText:label,suffixText:'g'));
 @override Widget build(BuildContext context)=>AlertDialog(
 title:const Text('Ma pizza maison'),
 content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
 SwitchListTile(title:const Text('Pizza personnelle'),subtitle:Text(personal?'Pâton de 220 g':'Pâton de 285 g'),value:personal,onChanged:(v)=>setState((){personal=v;dough.text=v?'220':'285';sauce.text=v?'60':'100';})),
 amount('Pâte crue maison',dough),
 SwitchListTile(title:Text(cream?'Crème liquide':'Sauce Mutti Pizza'),value:cream,onChanged:(v)=>setState(()=>cream=v)),
 amount(cream?'Crème liquide':'Sauce Mutti',sauce),
 amount('Mozzarella',mozzarella),amount('Emmental',emmental),amount('Cheddar râpé',cheddar),
 DropdownButtonFormField<int>(value:eatenEighths,decoration:const InputDecoration(labelText:'Portion de pizza mangée'),items:[
 for(var i=1;i<=8;i++)DropdownMenuItem(value:i,child:Text(i==8?'Pizza entière (8/8)':'
 Row(children:[
 Expanded(child:TextField(controller:extras,decoration:const InputDecoration(labelText:'Ajouter une garniture',hintText:'Ex : poivron 100g'),onSubmitted:(_)=>addExtra())),
 IconButton(tooltip:'Ajouter cet ingrédient',onPressed:addExtra,icon:const Icon(Icons.add_circle_outline)),
 ]),
 for(final item in extraItems)ListTile(dense:true,leading:const Icon(Icons.check_circle,color:Colors.green),title:Text(item),trailing:IconButton(tooltip:'Retirer',onPressed:()=>setState(()=>extraItems.remove(item)),icon:const Icon(Icons.close))),

 const SizedBox(height:8),
 OutlinedButton.icon(onPressed:()async{
  final product=await Navigator.of(context).push<FoodScanResult>(MaterialPageRoute(builder:(_)=>FoodBarcodeScanner(db:widget.db)));
  if(product!=null&&mounted)setState(()=>scanned.add(product));
 },icon:const Icon(Icons.qr_code_scanner),label:const Text('Scanner un ingrédient')),
 for(final product in scanned)ListTile(dense:true,title:Text(product.name),subtitle:Text('${product.grams.toStringAsFixed(0)} g • ${(product.kcal*product.grams/100).toStringAsFixed(0)} kcal'),trailing:IconButton(icon:const Icon(Icons.close),onPressed:()=>setState(()=>scanned.remove(product)))),
 const SizedBox(height:8),
 const Text('Corniche entièrement comptée. Fromages indicatifs : tu peux ajuster les quantités.',style:TextStyle(fontSize:12))
 ])),
 actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('Annuler')),
 FilledButton(onPressed:(){
  double? value(TextEditingController c)=>c.text.trim().isEmpty?0:double.tryParse(c.text.replaceAll(',','.'));
  final d=value(dough),sa=value(sauce),mo=value(mozzarella),em=value(emmental),ch=value(cheddar);
  if([d,sa,mo,em,ch].any((v)=>v==null||v<0)||d==0){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Vérifier les quantités.')));return;}
  final fraction=eatenEighths/8.0;
  String grams(double amount)=> (amount*fraction).toStringAsFixed(1)+'g';
  final parts=<String>['pâte pizza maison ${d!.toStringAsFixed(0)}g',if(sa!>0)'${cream?'crème liquide':'sauce mutti pizza'} ${grams(sa!)}',if(mo!>0)'mozzarella ${grams(mo!)}',if(em!>0)'emmental ${grams(em!)}',if(ch!>0)'cheddar ${grams(ch!)}',...extraItems.map((e)=>scaledExtra(e,fraction)),if(extras.text.trim().isNotEmpty)scaledExtra(extras.text.trim(),fraction)];
  for(final product in scanned){parts.add('${product.name} ${grams(product.grams)}');}
  double sum(double Function(FoodScanResult) field)=>scanned.fold<double>(0,(v,p)=>v+field(p)*p.grams*fraction/100);
  Navigator.pop(context,PizzaSelection(parts.join(', '),kcal:sum((p)=>p.kcal),protein:sum((p)=>p.protein),carbs:sum((p)=>p.carbs),fat:sum((p)=>p.fat)));
 },child:const Text('Utiliser'))]);
}
+'name '+'
 final List<String> extraItems=[];
 final List<FoodScanResult> scanned=[];
 @override void dispose(){for(final c in [dough,sauce,mozzarella,emmental,cheddar,extras]){c.dispose();}super.dispose();}
 void addExtra(){final item=extras.text.trim();if(item.isEmpty)return;setState((){extraItems.add(item);extras.clear();});}
 Widget amount(String label,TextEditingController c)=>TextField(controller:c,keyboardType:TextInputType.number,decoration:InputDecoration(labelText:label,suffixText:'g'));
 @override Widget build(BuildContext context)=>AlertDialog(
 title:const Text('Ma pizza maison'),
 content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
 SwitchListTile(title:const Text('Pizza personnelle'),subtitle:Text(personal?'Pâton de 220 g':'Pâton de 285 g'),value:personal,onChanged:(v)=>setState((){personal=v;dough.text=v?'220':'285';sauce.text=v?'60':'100';})),
 amount('Pâte crue maison',dough),
 SwitchListTile(title:Text(cream?'Crème liquide':'Sauce Mutti Pizza'),value:cream,onChanged:(v)=>setState(()=>cream=v)),
 amount(cream?'Crème liquide':'Sauce Mutti',sauce),
 amount('Mozzarella',mozzarella),amount('Emmental',emmental),amount('Cheddar râpé',cheddar),
 Row(children:[
 Expanded(child:TextField(controller:extras,decoration:const InputDecoration(labelText:'Ajouter une garniture',hintText:'Ex : poivron 100g'),onSubmitted:(_)=>addExtra())),
 IconButton(tooltip:'Ajouter cet ingrédient',onPressed:addExtra,icon:const Icon(Icons.add_circle_outline)),
 ]),
 for(final item in extraItems)ListTile(dense:true,leading:const Icon(Icons.check_circle,color:Colors.green),title:Text(item),trailing:IconButton(tooltip:'Retirer',onPressed:()=>setState(()=>extraItems.remove(item)),icon:const Icon(Icons.close))),

 const SizedBox(height:8),
 OutlinedButton.icon(onPressed:()async{
  final product=await Navigator.of(context).push<FoodScanResult>(MaterialPageRoute(builder:(_)=>FoodBarcodeScanner(db:widget.db)));
  if(product!=null&&mounted)setState(()=>scanned.add(product));
 },icon:const Icon(Icons.qr_code_scanner),label:const Text('Scanner un ingrédient')),
 for(final product in scanned)ListTile(dense:true,title:Text(product.name),subtitle:Text('${product.grams.toStringAsFixed(0)} g • ${(product.kcal*product.grams/100).toStringAsFixed(0)} kcal'),trailing:IconButton(icon:const Icon(Icons.close),onPressed:()=>setState(()=>scanned.remove(product)))),
 const SizedBox(height:8),
 const Text('Corniche entièrement comptée. Fromages indicatifs : tu peux ajuster les quantités.',style:TextStyle(fontSize:12))
 ])),
 actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('Annuler')),
 FilledButton(onPressed:(){
  double? value(TextEditingController c)=>double.tryParse(c.text.replaceAll(',','.'));
  final d=value(dough),sa=value(sauce),mo=value(mozzarella),em=value(emmental),ch=value(cheddar);
  if([d,sa,mo,em,ch].any((v)=>v==null||v<0)||d==0){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Vérifier les quantités.')));return;}
  final parts=<String>['pâte pizza maison ${d!.toStringAsFixed(0)}g',if(sa!>0)'${cream?'crème liquide':'sauce mutti pizza'} ${sa!.toStringAsFixed(0)}g',if(mo!>0)'mozzarella ${mo!.toStringAsFixed(0)}g',if(em!>0)'emmental ${em!.toStringAsFixed(0)}g',if(ch!>0)'cheddar ${ch!.toStringAsFixed(0)}g',...extraItems,if(extras.text.trim().isNotEmpty)extras.text.trim()];
  for(final product in scanned){parts.add('${product.name} ${product.grams.toStringAsFixed(0)}g');}
  double sum(double Function(FoodScanResult) field)=>scanned.fold<double>(0,(v,p)=>v+field(p)*p.grams/100);
  Navigator.pop(context,PizzaSelection(parts.join(', '),kcal:sum((p)=>p.kcal),protein:sum((p)=>p.protein),carbs:sum((p)=>p.carbs),fat:sum((p)=>p.fat)));
 },child:const Text('Utiliser'))]);
}
+'{(grams*fraction).toStringAsFixed(1)}g';
 }

 final List<String> extraItems=[];
 final List<FoodScanResult> scanned=[];
 @override void dispose(){for(final c in [dough,sauce,mozzarella,emmental,cheddar,extras]){c.dispose();}super.dispose();}
 void addExtra(){final item=extras.text.trim();if(item.isEmpty)return;setState((){extraItems.add(item);extras.clear();});}
 Widget amount(String label,TextEditingController c)=>TextField(controller:c,keyboardType:TextInputType.number,decoration:InputDecoration(labelText:label,suffixText:'g'));
 @override Widget build(BuildContext context)=>AlertDialog(
 title:const Text('Ma pizza maison'),
 content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
 SwitchListTile(title:const Text('Pizza personnelle'),subtitle:Text(personal?'Pâton de 220 g':'Pâton de 285 g'),value:personal,onChanged:(v)=>setState((){personal=v;dough.text=v?'220':'285';sauce.text=v?'60':'100';})),
 amount('Pâte crue maison',dough),
 SwitchListTile(title:Text(cream?'Crème liquide':'Sauce Mutti Pizza'),value:cream,onChanged:(v)=>setState(()=>cream=v)),
 amount(cream?'Crème liquide':'Sauce Mutti',sauce),
 amount('Mozzarella',mozzarella),amount('Emmental',emmental),amount('Cheddar râpé',cheddar),
 Row(children:[
 Expanded(child:TextField(controller:extras,decoration:const InputDecoration(labelText:'Ajouter une garniture',hintText:'Ex : poivron 100g'),onSubmitted:(_)=>addExtra())),
 IconButton(tooltip:'Ajouter cet ingrédient',onPressed:addExtra,icon:const Icon(Icons.add_circle_outline)),
 ]),
 for(final item in extraItems)ListTile(dense:true,leading:const Icon(Icons.check_circle,color:Colors.green),title:Text(item),trailing:IconButton(tooltip:'Retirer',onPressed:()=>setState(()=>extraItems.remove(item)),icon:const Icon(Icons.close))),

 const SizedBox(height:8),
 OutlinedButton.icon(onPressed:()async{
  final product=await Navigator.of(context).push<FoodScanResult>(MaterialPageRoute(builder:(_)=>FoodBarcodeScanner(db:widget.db)));
  if(product!=null&&mounted)setState(()=>scanned.add(product));
 },icon:const Icon(Icons.qr_code_scanner),label:const Text('Scanner un ingrédient')),
 for(final product in scanned)ListTile(dense:true,title:Text(product.name),subtitle:Text('${product.grams.toStringAsFixed(0)} g • ${(product.kcal*product.grams/100).toStringAsFixed(0)} kcal'),trailing:IconButton(icon:const Icon(Icons.close),onPressed:()=>setState(()=>scanned.remove(product)))),
 const SizedBox(height:8),
 const Text('Corniche entièrement comptée. Fromages indicatifs : tu peux ajuster les quantités.',style:TextStyle(fontSize:12))
 ])),
 actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('Annuler')),
 FilledButton(onPressed:(){
  double? value(TextEditingController c)=>double.tryParse(c.text.replaceAll(',','.'));
  final d=value(dough),sa=value(sauce),mo=value(mozzarella),em=value(emmental),ch=value(cheddar);
  if([d,sa,mo,em,ch].any((v)=>v==null||v<0)||d==0){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Vérifier les quantités.')));return;}
  final parts=<String>['pâte pizza maison ${d!.toStringAsFixed(0)}g',if(sa!>0)'${cream?'crème liquide':'sauce mutti pizza'} ${sa!.toStringAsFixed(0)}g',if(mo!>0)'mozzarella ${mo!.toStringAsFixed(0)}g',if(em!>0)'emmental ${em!.toStringAsFixed(0)}g',if(ch!>0)'cheddar ${ch!.toStringAsFixed(0)}g',...extraItems,if(extras.text.trim().isNotEmpty)extras.text.trim()];
  for(final product in scanned){parts.add('${product.name} ${product.grams.toStringAsFixed(0)}g');}
  double sum(double Function(FoodScanResult) field)=>scanned.fold<double>(0,(v,p)=>v+field(p)*p.grams/100);
  Navigator.pop(context,PizzaSelection(parts.join(', '),kcal:sum((p)=>p.kcal),protein:sum((p)=>p.protein),carbs:sum((p)=>p.carbs),fat:sum((p)=>p.fat)));
 },child:const Text('Utiliser'))]);
}
+'i/8 de la pizza')),
 ],onChanged:(v){if(v!=null)setState(()=>eatenEighths=v);}),

 Row(children:[
 Expanded(child:TextField(controller:extras,decoration:const InputDecoration(labelText:'Ajouter une garniture',hintText:'Ex : poivron 100g'),onSubmitted:(_)=>addExtra())),
 IconButton(tooltip:'Ajouter cet ingrédient',onPressed:addExtra,icon:const Icon(Icons.add_circle_outline)),
 ]),
 for(final item in extraItems)ListTile(dense:true,leading:const Icon(Icons.check_circle,color:Colors.green),title:Text(item),trailing:IconButton(tooltip:'Retirer',onPressed:()=>setState(()=>extraItems.remove(item)),icon:const Icon(Icons.close))),

 const SizedBox(height:8),
 OutlinedButton.icon(onPressed:()async{
  final product=await Navigator.of(context).push<FoodScanResult>(MaterialPageRoute(builder:(_)=>FoodBarcodeScanner(db:widget.db)));
  if(product!=null&&mounted)setState(()=>scanned.add(product));
 },icon:const Icon(Icons.qr_code_scanner),label:const Text('Scanner un ingrédient')),
 for(final product in scanned)ListTile(dense:true,title:Text(product.name),subtitle:Text('${product.grams.toStringAsFixed(0)} g • ${(product.kcal*product.grams/100).toStringAsFixed(0)} kcal'),trailing:IconButton(icon:const Icon(Icons.close),onPressed:()=>setState(()=>scanned.remove(product)))),
 const SizedBox(height:8),
 const Text('Corniche entièrement comptée. Fromages indicatifs : tu peux ajuster les quantités.',style:TextStyle(fontSize:12))
 ])),
 actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('Annuler')),
 FilledButton(onPressed:(){
  double? value(TextEditingController c)=>double.tryParse(c.text.replaceAll(',','.'));
  final d=value(dough),sa=value(sauce),mo=value(mozzarella),em=value(emmental),ch=value(cheddar);
  if([d,sa,mo,em,ch].any((v)=>v==null||v<0)||d==0){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Vérifier les quantités.')));return;}
  final parts=<String>['pâte pizza maison ${d!.toStringAsFixed(0)}g',if(sa!>0)'${cream?'crème liquide':'sauce mutti pizza'} ${sa!.toStringAsFixed(0)}g',if(mo!>0)'mozzarella ${mo!.toStringAsFixed(0)}g',if(em!>0)'emmental ${em!.toStringAsFixed(0)}g',if(ch!>0)'cheddar ${ch!.toStringAsFixed(0)}g',...extraItems,if(extras.text.trim().isNotEmpty)extras.text.trim()];
  for(final product in scanned){parts.add('${product.name} ${product.grams.toStringAsFixed(0)}g');}
  double sum(double Function(FoodScanResult) field)=>scanned.fold<double>(0,(v,p)=>v+field(p)*p.grams/100);
  Navigator.pop(context,PizzaSelection(parts.join(', '),kcal:sum((p)=>p.kcal),protein:sum((p)=>p.protein),carbs:sum((p)=>p.carbs),fat:sum((p)=>p.fat)));
 },child:const Text('Utiliser'))]);
}
+'name '+'
 final List<String> extraItems=[];
 final List<FoodScanResult> scanned=[];
 @override void dispose(){for(final c in [dough,sauce,mozzarella,emmental,cheddar,extras]){c.dispose();}super.dispose();}
 void addExtra(){final item=extras.text.trim();if(item.isEmpty)return;setState((){extraItems.add(item);extras.clear();});}
 Widget amount(String label,TextEditingController c)=>TextField(controller:c,keyboardType:TextInputType.number,decoration:InputDecoration(labelText:label,suffixText:'g'));
 @override Widget build(BuildContext context)=>AlertDialog(
 title:const Text('Ma pizza maison'),
 content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
 SwitchListTile(title:const Text('Pizza personnelle'),subtitle:Text(personal?'Pâton de 220 g':'Pâton de 285 g'),value:personal,onChanged:(v)=>setState((){personal=v;dough.text=v?'220':'285';sauce.text=v?'60':'100';})),
 amount('Pâte crue maison',dough),
 SwitchListTile(title:Text(cream?'Crème liquide':'Sauce Mutti Pizza'),value:cream,onChanged:(v)=>setState(()=>cream=v)),
 amount(cream?'Crème liquide':'Sauce Mutti',sauce),
 amount('Mozzarella',mozzarella),amount('Emmental',emmental),amount('Cheddar râpé',cheddar),
 Row(children:[
 Expanded(child:TextField(controller:extras,decoration:const InputDecoration(labelText:'Ajouter une garniture',hintText:'Ex : poivron 100g'),onSubmitted:(_)=>addExtra())),
 IconButton(tooltip:'Ajouter cet ingrédient',onPressed:addExtra,icon:const Icon(Icons.add_circle_outline)),
 ]),
 for(final item in extraItems)ListTile(dense:true,leading:const Icon(Icons.check_circle,color:Colors.green),title:Text(item),trailing:IconButton(tooltip:'Retirer',onPressed:()=>setState(()=>extraItems.remove(item)),icon:const Icon(Icons.close))),

 const SizedBox(height:8),
 OutlinedButton.icon(onPressed:()async{
  final product=await Navigator.of(context).push<FoodScanResult>(MaterialPageRoute(builder:(_)=>FoodBarcodeScanner(db:widget.db)));
  if(product!=null&&mounted)setState(()=>scanned.add(product));
 },icon:const Icon(Icons.qr_code_scanner),label:const Text('Scanner un ingrédient')),
 for(final product in scanned)ListTile(dense:true,title:Text(product.name),subtitle:Text('${product.grams.toStringAsFixed(0)} g • ${(product.kcal*product.grams/100).toStringAsFixed(0)} kcal'),trailing:IconButton(icon:const Icon(Icons.close),onPressed:()=>setState(()=>scanned.remove(product)))),
 const SizedBox(height:8),
 const Text('Corniche entièrement comptée. Fromages indicatifs : tu peux ajuster les quantités.',style:TextStyle(fontSize:12))
 ])),
 actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('Annuler')),
 FilledButton(onPressed:(){
  double? value(TextEditingController c)=>double.tryParse(c.text.replaceAll(',','.'));
  final d=value(dough),sa=value(sauce),mo=value(mozzarella),em=value(emmental),ch=value(cheddar);
  if([d,sa,mo,em,ch].any((v)=>v==null||v<0)||d==0){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Vérifier les quantités.')));return;}
  final parts=<String>['pâte pizza maison ${d!.toStringAsFixed(0)}g',if(sa!>0)'${cream?'crème liquide':'sauce mutti pizza'} ${sa!.toStringAsFixed(0)}g',if(mo!>0)'mozzarella ${mo!.toStringAsFixed(0)}g',if(em!>0)'emmental ${em!.toStringAsFixed(0)}g',if(ch!>0)'cheddar ${ch!.toStringAsFixed(0)}g',...extraItems,if(extras.text.trim().isNotEmpty)extras.text.trim()];
  for(final product in scanned){parts.add('${product.name} ${product.grams.toStringAsFixed(0)}g');}
  double sum(double Function(FoodScanResult) field)=>scanned.fold<double>(0,(v,p)=>v+field(p)*p.grams/100);
  Navigator.pop(context,PizzaSelection(parts.join(', '),kcal:sum((p)=>p.kcal),protein:sum((p)=>p.protein),carbs:sum((p)=>p.carbs),fat:sum((p)=>p.fat)));
 },child:const Text('Utiliser'))]);
}
+'{(grams*fraction).toStringAsFixed(1)}g';
 }

 final List<String> extraItems=[];
 final List<FoodScanResult> scanned=[];
 @override void dispose(){for(final c in [dough,sauce,mozzarella,emmental,cheddar,extras]){c.dispose();}super.dispose();}
 void addExtra(){final item=extras.text.trim();if(item.isEmpty)return;setState((){extraItems.add(item);extras.clear();});}
 Widget amount(String label,TextEditingController c)=>TextField(controller:c,keyboardType:TextInputType.number,decoration:InputDecoration(labelText:label,suffixText:'g'));
 @override Widget build(BuildContext context)=>AlertDialog(
 title:const Text('Ma pizza maison'),
 content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
 SwitchListTile(title:const Text('Pizza personnelle'),subtitle:Text(personal?'Pâton de 220 g':'Pâton de 285 g'),value:personal,onChanged:(v)=>setState((){personal=v;dough.text=v?'220':'285';sauce.text=v?'60':'100';})),
 amount('Pâte crue maison',dough),
 SwitchListTile(title:Text(cream?'Crème liquide':'Sauce Mutti Pizza'),value:cream,onChanged:(v)=>setState(()=>cream=v)),
 amount(cream?'Crème liquide':'Sauce Mutti',sauce),
 amount('Mozzarella',mozzarella),amount('Emmental',emmental),amount('Cheddar râpé',cheddar),
 Row(children:[
 Expanded(child:TextField(controller:extras,decoration:const InputDecoration(labelText:'Ajouter une garniture',hintText:'Ex : poivron 100g'),onSubmitted:(_)=>addExtra())),
 IconButton(tooltip:'Ajouter cet ingrédient',onPressed:addExtra,icon:const Icon(Icons.add_circle_outline)),
 ]),
 for(final item in extraItems)ListTile(dense:true,leading:const Icon(Icons.check_circle,color:Colors.green),title:Text(item),trailing:IconButton(tooltip:'Retirer',onPressed:()=>setState(()=>extraItems.remove(item)),icon:const Icon(Icons.close))),

 const SizedBox(height:8),
 OutlinedButton.icon(onPressed:()async{
  final product=await Navigator.of(context).push<FoodScanResult>(MaterialPageRoute(builder:(_)=>FoodBarcodeScanner(db:widget.db)));
  if(product!=null&&mounted)setState(()=>scanned.add(product));
 },icon:const Icon(Icons.qr_code_scanner),label:const Text('Scanner un ingrédient')),
 for(final product in scanned)ListTile(dense:true,title:Text(product.name),subtitle:Text('${product.grams.toStringAsFixed(0)} g • ${(product.kcal*product.grams/100).toStringAsFixed(0)} kcal'),trailing:IconButton(icon:const Icon(Icons.close),onPressed:()=>setState(()=>scanned.remove(product)))),
 const SizedBox(height:8),
 const Text('Corniche entièrement comptée. Fromages indicatifs : tu peux ajuster les quantités.',style:TextStyle(fontSize:12))
 ])),
 actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('Annuler')),
 FilledButton(onPressed:(){
  double? value(TextEditingController c)=>double.tryParse(c.text.replaceAll(',','.'));
  final d=value(dough),sa=value(sauce),mo=value(mozzarella),em=value(emmental),ch=value(cheddar);
  if([d,sa,mo,em,ch].any((v)=>v==null||v<0)||d==0){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Vérifier les quantités.')));return;}
  final parts=<String>['pâte pizza maison ${d!.toStringAsFixed(0)}g',if(sa!>0)'${cream?'crème liquide':'sauce mutti pizza'} ${sa!.toStringAsFixed(0)}g',if(mo!>0)'mozzarella ${mo!.toStringAsFixed(0)}g',if(em!>0)'emmental ${em!.toStringAsFixed(0)}g',if(ch!>0)'cheddar ${ch!.toStringAsFixed(0)}g',...extraItems,if(extras.text.trim().isNotEmpty)extras.text.trim()];
  for(final product in scanned){parts.add('${product.name} ${product.grams.toStringAsFixed(0)}g');}
  double sum(double Function(FoodScanResult) field)=>scanned.fold<double>(0,(v,p)=>v+field(p)*p.grams/100);
  Navigator.pop(context,PizzaSelection(parts.join(', '),kcal:sum((p)=>p.kcal),protein:sum((p)=>p.protein),carbs:sum((p)=>p.carbs),fat:sum((p)=>p.fat)));
 },child:const Text('Utiliser'))]);
}
