import 'package:flutter/material.dart';
import 'food_barcode_scanner.dart';
import 'pizza_catalog.dart';
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
 PizzaRecipe? selectedRecipe;
 bool personal=false;
 bool cream=false;
 int eighths=8;
 final dough=TextEditingController(text:'285');
 final sauce=TextEditingController(text:'60');
 final mozzarella=TextEditingController(text:'80');
 final emmental=TextEditingController(text:'0');
 final cheddar=TextEditingController(text:'0');
 final extras=TextEditingController();
 final List<String> extraItems=[];
 final List<FoodScanResult> scanned=[];
 @override void dispose(){for(final c in [dough,sauce,mozzarella,emmental,cheddar,extras]){c.dispose();}super.dispose();}
 void selectRecipe(PizzaRecipe? recipe){
  if(recipe==null)return;
  setState((){
   selectedRecipe=recipe;
   cream=recipe.base=='crème';
   dough.text='285';personal=false;
   sauce.text=cream?'100':'100';
   mozzarella.text='0';emmental.text='0';cheddar.text='0';
   extraItems.clear();
   for(final ingredient in recipe.ingredients){
    final lower=ingredient.toLowerCase();
    if(lower=='mozzarella'){mozzarella.text='80';}
    else if(lower=='emmental'){emmental.text='80';}
    else if(lower=='cheddar'){cheddar.text='40';}
    else {extraItems.add(ingredient+' 40g');}
   }
  });
 }
 void addExtra(){final item=extras.text.trim();if(item.isEmpty)return;setState((){extraItems.add(item);extras.clear();});}
 void resizeRecipe(double grams){
  final previous=double.tryParse(dough.text.replaceAll(',','.'))??285;
  if(previous<=0)return;
  final factor=grams/previous;
  for(final c in [sauce,mozzarella,emmental,cheddar]){
   final value=double.tryParse(c.text.replaceAll(',','.'))??0;
   c.text=(value*factor).toStringAsFixed(1);
  }
  for(var i=0;i<extraItems.length;i++){
   extraItems[i]=extraItems[i].replaceAllMapped(RegExp(r'(\d+(?:[.,]\d+)?)\s*g\b',caseSensitive:false),(m){
    final value=double.tryParse(m.group(1)!.replaceAll(',','.'))??0;
    return (value*factor).toStringAsFixed(1)+'g';
   });
  }
  dough.text=grams.toStringAsFixed(0);
  setState((){});
 }
 Widget amount(String label,TextEditingController c)=>TextField(controller:c,keyboardType:TextInputType.number,decoration:InputDecoration(labelText:label,suffixText:'g'));
 @override Widget build(BuildContext context)=>AlertDialog(
 title:const Text('Ma pizza maison'),
 content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
 DropdownButtonFormField<String>(value:selectedRecipe?.name,decoration:const InputDecoration(labelText:'Recette La Casita'),hint:Text('Choisir une pizza'),isExpanded:true,items:[for(final recipe in ([...pizzaRecipes]..sort((a,b)=>a.name.toLowerCase().compareTo(b.name.toLowerCase()))))DropdownMenuItem(value:recipe.name,child:Text(recipe.name,overflow:TextOverflow.ellipsis))],onChanged:(name){for(final recipe in pizzaRecipes){if(recipe.name==name){selectRecipe(recipe);break;}}}),
 const Text('Grammages indicatifs : corrige-les selon ta recette réelle.',style:TextStyle(fontSize:12)),
 SwitchListTile(title:const Text('Pizza personnelle'),subtitle:Text(personal?'Pâton de 200 g':'Pâton de 285 g'),value:personal,onChanged:(v){personal=v;resizeRecipe(v?200:285);}),
 amount('Pâte crue maison',dough),
 SwitchListTile(title:Text(cream?'Crème liquide':'Sauce Mutti Pizza'),value:cream,onChanged:(v)=>setState(()=>cream=v)),
 amount(cream?'Crème liquide':'Sauce Mutti',sauce),
 amount('Mozzarella',mozzarella),amount('Emmental',emmental),amount('Cheddar râpé',cheddar),
 DropdownButtonFormField<int>(value:eighths,decoration:const InputDecoration(labelText:'Portion mangée'),items:[for(var i=1;i<=8;i++)DropdownMenuItem(value:i,child:Text(i==8?'Pizza entière':i.toString()+'/8 de la pizza'))],onChanged:(v){if(v!=null)setState(()=>eighths=v);}),
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
  final parts=<String>['pâte pizza maison ${d!.toStringAsFixed(0)}g',if(sa!>0)'${cream?'crème liquide':'sauce mutti pizza'} ${sa!.toStringAsFixed(0)}g',if(mo!>0)'mozzarella ${mo!.toStringAsFixed(0)}g',if(em!>0)'emmental ${em!.toStringAsFixed(0)}g',if(ch!>0)'cheddar ${ch!.toStringAsFixed(0)}g',...extraItems,if(extras.text.trim().isNotEmpty)extras.text.trim()];
  for(final product in scanned){parts.add('${product.name} ${product.grams.toStringAsFixed(0)}g');}
  final fraction=eighths/8.0;
  for(var i=0;i<parts.length;i++){
   parts[i]=parts[i].replaceAllMapped(RegExp(r'(\d+(?:[.,]\d+)?)\s*g\b',caseSensitive:false),(m){
    final n=double.tryParse(m.group(1)!.replaceAll(',','.'));
    return n==null?m.group(0)!:(n*fraction).toStringAsFixed(1)+'g';
   });
  }
  double sum(double Function(FoodScanResult) field)=>scanned.fold<double>(0,(v,p)=>v+field(p)*p.grams*fraction/100);
  Navigator.pop(context,PizzaSelection((selectedRecipe==null?'Pizza maison':selectedRecipe!.name)+': '+parts.join(', '),kcal:sum((p)=>p.kcal),protein:sum((p)=>p.protein),carbs:sum((p)=>p.carbs),fat:sum((p)=>p.fat)));
 },child:const Text('Utiliser'))]);
}
