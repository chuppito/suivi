import 'package:flutter/material.dart';

class PizzaSelection {
 final String description;
 const PizzaSelection(this.description);
}
class PizzaRecipePicker extends StatefulWidget {
 const PizzaRecipePicker({super.key});
 @override State<PizzaRecipePicker> createState()=>_PizzaRecipePickerState();
}
class _PizzaRecipePickerState extends State<PizzaRecipePicker> {
 bool personal=true;
 bool cream=false;
 final dough=TextEditingController(text:'220');
 final sauce=TextEditingController(text:'60');
 final mozzarella=TextEditingController(text:'80');
 final emmental=TextEditingController(text:'0');
 final cheddar=TextEditingController(text:'0');
 final extras=TextEditingController();
 @override void dispose(){for(final c in [dough,sauce,mozzarella,emmental,cheddar,extras]){c.dispose();}super.dispose();}
 Widget amount(String label,TextEditingController c)=>TextField(controller:c,keyboardType:TextInputType.number,decoration:InputDecoration(labelText:label,suffixText:'g'));
 @override Widget build(BuildContext context)=>AlertDialog(
 title:const Text('Ma pizza maison'),
 content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
 SwitchListTile(title:const Text('Pizza personnelle'),subtitle:Text(personal?'Pâton de 220 g':'Pâton de 285 g'),value:personal,onChanged:(v)=>setState((){personal=v;dough.text=v?'220':'285';sauce.text=v?'60':'100';})),
 amount('Pâte crue maison',dough),
 SwitchListTile(title:Text(cream?'Crème liquide':'Sauce Mutti Pizza'),value:cream,onChanged:(v)=>setState(()=>cream=v)),
 amount(cream?'Crème liquide':'Sauce Mutti',sauce),
 amount('Mozzarella',mozzarella),amount('Emmental',emmental),amount('Cheddar râpé',cheddar),
 TextField(controller:extras,maxLines:2,decoration:const InputDecoration(labelText:'Garniture supplémentaire',hintText:'Ex : jambon 60g, champignons 50g')),
 const SizedBox(height:8),
 const Text('Corniche entièrement comptée. Fromages indicatifs : tu peux ajuster les quantités.',style:TextStyle(fontSize:12))
 ])),
 actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('Annuler')),
 FilledButton(onPressed:(){
  double? value(TextEditingController c)=>double.tryParse(c.text.replaceAll(',','.'));
  final d=value(dough),sa=value(sauce),mo=value(mozzarella),em=value(emmental),ch=value(cheddar);
  if([d,sa,mo,em,ch].any((v)=>v==null||v<0)||d==0){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Vérifier les quantités.')));return;}
  final parts=<String>['pâte pizza maison ${d!.toStringAsFixed(0)}g',if(sa!>0)'${cream?'crème liquide':'sauce mutti pizza'} ${sa!.toStringAsFixed(0)}g',if(mo!>0)'mozzarella ${mo!.toStringAsFixed(0)}g',if(em!>0)'emmental ${em!.toStringAsFixed(0)}g',if(ch!>0)'cheddar ${ch!.toStringAsFixed(0)}g',if(extras.text.trim().isNotEmpty)extras.text.trim()];
  Navigator.pop(context,PizzaSelection(parts.join(', ')));
 },child:const Text('Utiliser'))]);
}
