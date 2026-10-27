import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

class ProductHistory extends StatefulWidget {
 final Database db;
 final VoidCallback onAdded;
 const ProductHistory({super.key,required this.db,required this.onAdded});
 @override State<ProductHistory> createState()=>_ProductHistoryState();
}
class _ProductHistoryState extends State<ProductHistory> {
 String search='';
 Future<void> add(Map<String,Object?> product) async {
  final grams=TextEditingController(text:'30');
  
  final chosen=await showDialog<double>(context:context,builder:(ctx)=>AlertDialog(
   title:Text(product['name'].toString()),
   content:Column(mainAxisSize:MainAxisSize.min,children:[
    Text('Pour 100 g : ${product['kcal']} kcal'),
    TextField(controller:grams,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Quantité mangée (g)')),
   ]),
   actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Annuler')),
    FilledButton(onPressed:(){
     final n=double.tryParse(grams.text.replaceAll(',','.'));
     if(n!=null&&n>0)Navigator.pop(ctx,n);
    },child:const Text('Ajouter en collation'))],
  ));
  if(chosen==null)return;
  final factor=chosen/100;
  double nutrient(String key)=>((product[key] as num?)?.toDouble()??0)*factor;
  final now=DateTime.now().toIso8601String().substring(0,10);
  await widget.db.insert('meals',{
   'date':now,'category':'Collation',
   'description':'${product['name']} ${chosen.toStringAsFixed(0)} g',
   'calories':nutrient('kcal').ceil(),'protein':nutrient('protein'),
   'carbs':nutrient('carbs'),'fat':nutrient('fat'),
   'uncertainty':'Produit issu de la bibliothèque personnelle ; valeurs pour 100 g à vérifier.',
   'notes':'Code-barres : ${product['barcode']??''}'
  });
  widget.onAdded();
  if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Portion ajoutée au journal du jour')));
 }
 Future<void> editProduct(Map<String,Object?> product) async {
  final name=TextEditingController(text:product['name']?.toString()??'');
  String value(String key)=>(product[key]??0).toString();
  final kcal=TextEditingController(text:value('kcal'));
  final protein=TextEditingController(text:value('protein'));
  final carbs=TextEditingController(text:value('carbs'));
  final fat=TextEditingController(text:value('fat'));
  final saved=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
   title:const Text('Modifier le produit'),
   content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
    TextField(controller:name,decoration:const InputDecoration(labelText:'Nom')),
    for(final entry in <(String,TextEditingController)>[
     ('Calories (kcal / 100 g)',kcal),('Protéines (g / 100 g)',protein),
     ('Glucides (g / 100 g)',carbs),('Lipides (g / 100 g)',fat)
    ])TextField(controller:entry.$2,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:InputDecoration(labelText:entry.$1)),
   ])),
   actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Annuler')),
    FilledButton(onPressed:(){
     double? parse(TextEditingController c)=>double.tryParse(c.text.trim().replaceAll(',','.'));
     final values=[parse(kcal),parse(protein),parse(carbs),parse(fat)];
     if(name.text.trim().isEmpty||values.any((v)=>v==null||v<0)){
      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content:Text('Vérifie le nom et les valeurs positives.')));
      return;
     }
     Navigator.pop(ctx,true);
    },child:const Text('Enregistrer'))],
  ));
  if(saved==true){
   double parse(TextEditingController c)=>double.parse(c.text.trim().replaceAll(',','.'));
   await widget.db.update('food_library',{'name':name.text.trim(),'kcal':parse(kcal),'protein':parse(protein),'carbs':parse(carbs),'fat':parse(fat)},where:'id=?',whereArgs:[product['id']]);
   if(mounted)setState((){});
  }
  name.dispose();kcal.dispose();protein.dispose();carbs.dispose();fat.dispose();
 }
 @override Widget build(BuildContext context)=>Scaffold(
  appBar:AppBar(title:const Text('Historique des produits')),
  body:Column(children:[
   Padding(padding:const EdgeInsets.all(12),child:TextField(decoration:const InputDecoration(prefixIcon:Icon(Icons.search),labelText:'Rechercher un produit'),onChanged:(v)=>setState(()=>search=v.toLowerCase()))),
   Expanded(child:FutureBuilder<List<Map<String,Object?>>>(
    future:widget.db.query('food_library',orderBy:'id DESC'),
    builder:(ctx,s){
     if(s.hasError)return Center(child:Text('Erreur : ${s.error}'));
     if(!s.hasData)return const Center(child:CircularProgressIndicator());
     final products=s.data!.where((p)=>p['name'].toString().toLowerCase().contains(search)).toList();
     if(products.isEmpty)return const Center(child:Text('Aucun produit enregistré. Scanne un produit pour commencer.'));
     return ListView.builder(itemCount:products.length,itemBuilder:(ctx,i){
      final p=products[i];
      return ListTile(leading:const Icon(Icons.inventory_2_outlined),title:Text(p['name'].toString()),
       subtitle:Text('${p['kcal']} kcal / 100 g • ${p['barcode']??'Sans code-barres'}'),
       trailing:Row(mainAxisSize:MainAxisSize.min,children:[IconButton(tooltip:'Modifier',icon:const Icon(Icons.edit_outlined),onPressed:()=>editProduct(p)),IconButton(tooltip:'Ajouter en collation',icon:const Icon(Icons.add_circle_outline),onPressed:()=>add(p))]),onTap:()=>add(p));
     });
    },
   )),
  ]),
 );
}
