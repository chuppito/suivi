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
  var category='Collation';
  final chosen=await showDialog<(double,String)>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,refresh)=>AlertDialog(
   title:Text(product['name'].toString()),
   content:Column(mainAxisSize:MainAxisSize.min,children:[
    Text('Pour 100 g : ${product['kcal']} kcal'),
    TextField(controller:grams,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Quantité mangée (g)')),
    DropdownButtonFormField<String>(value:category,items:const [
     DropdownMenuItem(value:'Petit-déjeuner',child:Text('Petit-déjeuner')),
     DropdownMenuItem(value:'Déjeuner',child:Text('Déjeuner')),
     DropdownMenuItem(value:'Dîner',child:Text('Dîner')),
     DropdownMenuItem(value:'Collation',child:Text('Collation')),
    ],onChanged:(v){if(v!=null)refresh(()=>category=v);}),
   ]),
   actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Annuler')),
    FilledButton(onPressed:(){
     final n=double.tryParse(grams.text.replaceAll(',','.'));
     if(n!=null&&n>0)Navigator.pop(ctx,(n,category));
    },child:const Text('Ajouter au jour'))],
  )));
  if(chosen==null)return;
  final factor=chosen.$1/100;
  double nutrient(String key)=>((product[key] as num?)?.toDouble()??0)*factor;
  final now=DateTime.now().toIso8601String().substring(0,10);
  await widget.db.insert('meals',{
   'date':now,'category':chosen.$2,
   'description':'${product['name']} ${chosen.$1.toStringAsFixed(0)} g',
   'calories':nutrient('kcal').ceil(),'protein':nutrient('protein'),
   'carbs':nutrient('carbs'),'fat':nutrient('fat'),
   'uncertainty':'Produit issu de la bibliothèque personnelle ; valeurs pour 100 g à vérifier.',
   'notes':'Code-barres : ${product['barcode']??''}'
  });
  widget.onAdded();
  if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Portion ajoutée au journal du jour')));
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
       trailing:const Icon(Icons.add_circle_outline),onTap:()=>add(p));
     });
    },
   )),
  ]),
 );
}
