import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:fl_chart/fl_chart.dart';

void main() async { WidgetsFlutterBinding.ensureInitialized(); await Store.init(); runApp(const NutritionApp()); }
class Store {
 static late Database db;
 static Future<void> init() async {
  db=await openDatabase(p.join(await getDatabasesPath(),'nutrition.db'),version:1,onCreate:(d,v) async {
   await d.execute('CREATE TABLE measures(id INTEGER PRIMARY KEY AUTOINCREMENT,date TEXT NOT NULL,weight REAL,waist REAL,approx INTEGER DEFAULT 0,note TEXT DEFAULT "")');
   await d.execute('CREATE TABLE meals(id INTEGER PRIMARY KEY AUTOINCREMENT,date TEXT NOT NULL,category TEXT NOT NULL,description TEXT NOT NULL,photo TEXT,calories REAL,protein REAL,carbs REAL,fat REAL,uncertainty TEXT DEFAULT "",notes TEXT DEFAULT "")');
   await d.execute('CREATE TABLE supplements(id INTEGER PRIMARY KEY AUTOINCREMENT,name TEXT NOT NULL,brand TEXT,dose TEXT,details TEXT,active INTEGER DEFAULT 1)');
   await d.execute('CREATE TABLE intakes(id INTEGER PRIMARY KEY AUTOINCREMENT,supplement_id INTEGER,date TEXT NOT NULL)');
   await d.execute('CREATE TABLE activities(id INTEGER PRIMARY KEY AUTOINCREMENT,date TEXT,type TEXT,duration INTEGER,intensity TEXT,notes TEXT)');
   await d.execute('CREATE TABLE settings(key TEXT PRIMARY KEY,value TEXT)');
  });
  if((await db.rawQuery('SELECT COUNT(*) n FROM measures')).first['n']==0){
   for(final r in seedMeasurements){await db.insert('measures',{'date':r.$1,'weight':r.$2,'waist':r.$3,'approx':r.$4,'note':r.$5});}
  }
  if((await db.rawQuery('SELECT COUNT(*) n FROM supplements')).first['n']==0){
   for(final s in seedSupplements){await db.insert('supplements',s);}
  }
 }
 static Future<List<Map<String,Object?>>> all(String table,{String order='id DESC'})=>db.query(table,orderBy:order);
 static Future<void> export() async {
  final data=<String,dynamic>{'schema':1};
  for(final t in ['measures','meals','supplements','intakes','activities','settings']){data[t]=await all(t);}
  final dir=await getTemporaryDirectory();final file=File(p.join(dir.path,'nutrition_sauvegarde.json'));
  await file.writeAsString(jsonEncode(data));await Share.shareXFiles([XFile(file.path)],text:'Sauvegarde Suivi Nutrition');
 }
 static Future<void> restore() async {
  final result=await FilePicker.platform.pickFiles(type:FileType.custom,allowedExtensions:['json']);
  if(result==null||result.files.single.path==null)return;
  final data=jsonDecode(await File(result.files.single.path!).readAsString()) as Map<String,dynamic>;
  if(data['schema']!=1)throw const FormatException('Format de sauvegarde incompatible');
  await db.transaction((tx) async {for(final t in ['measures','meals','supplements','intakes','activities','settings']){
   final rows=data[t];if(rows is! List)throw const FormatException('Sauvegarde incomplète');
   await tx.delete(t);for(final row in rows){await tx.insert(t,Map<String,Object?>.from(row as Map));}
  }});
 }
}
const seedMeasurements=< (String,double,double?,int,String)>[
 ('2026-06-26',90,null,1,'Poids déclaré au démarrage des compléments ; mesure hebdomadaire non confirmée'),
 ('2026-07-12',95.85,104,0,''),('2026-07-19',95.65,104,0,''),('2026-07-26',96,103,0,''),
 ('2026-08-02',96.4,103,0,''),('2026-08-09',95.2,102,0,''),('2026-09-01',92.65,101,1,'Date approximative'),
 ('2026-09-06',91.9,100,0,''),('2026-09-13',92.4,100,0,''),('2026-09-20',92,99.5,0,''),
 ('2026-09-27',91.7,99.5,0,''),('2026-10-04',92.15,100,0,''),('2026-10-11',93,98.5,0,''),('2026-10-18',92.6,99.5,0,'')];
const seedSupplements=<Map<String,Object?>>[
 {'name':'Whey chocolat','brand':'Decathlon','dose':'30 g','details':'1,5 kg ; environ 21 g protéines et 113 kcal pour 30 g','active':1},
 {'name':'Collagène bovin hydrolysé','brand':'Bloom Naturals','dose':'15 g','details':'1,5 kg ; types I et III ; vitamine C 80 mg/100 g (12 mg/15 g)','active':1},
 {'name':'Créatine monohydrate','brand':'ESN Ultrapure','dose':'5 g','details':'Prise habituelle depuis le 26 juillet 2026','active':1},
 {'name':'Électrolytes','brand':'À compléter','dose':'Selon besoin','details':'Par comprimé : C 24 mg ; B1 0,33 mg ; B2 0,42 mg ; B6 0,42 mg','active':1},
 {'name':'Psyllium blond','brand':'À compléter','dose':'1 cuillère à café','details':'Après-midi, avec au moins 250 à 300 ml d’eau','active':1},
 {'name':'Vitamine C C1000','brand':'À compléter','dose':'','details':'Ancien complément arrêté','active':0}];
class NutritionApp extends StatelessWidget {const NutritionApp({super.key});@override Widget build(BuildContext context)=>MaterialApp(title:'Suivi Nutrition & Corps',debugShowCheckedModeBanner:false,theme:ThemeData(colorSchemeSeed:Colors.teal,useMaterial3:true),home:const Home());}
class Home extends StatefulWidget{const Home({super.key});@override State<Home> createState()=>_HomeState();}
class _HomeState extends State<Home>{int tab=0;int refresh=0;void reload()=>setState(()=>refresh++);
 @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Suivi Nutrition & Corps')),body:SafeArea(top:false,child:IndexedStack(index:tab,children:[Dashboard(key:ValueKey('d$refresh')),Measurements(key:ValueKey('m$refresh'),reload:reload),Meals(key:ValueKey('r$refresh'),reload:reload),Supplements(key:ValueKey('s$refresh'),reload:reload),More(key:ValueKey('o$refresh'),reload:reload)])),bottomNavigationBar:NavigationBar(selectedIndex:tab,onDestinationSelected:(i)=>setState(()=>tab=i),destinations:const [NavigationDestination(icon:Icon(Icons.home),label:'Accueil'),NavigationDestination(icon:Icon(Icons.monitor_weight),label:'Mesures'),NavigationDestination(icon:Icon(Icons.restaurant),label:'Repas'),NavigationDestination(icon:Icon(Icons.medication),label:'Compléments'),NavigationDestination(icon:Icon(Icons.more_horiz),label:'Plus')]));
}
String today()=>DateTime.now().toIso8601String().substring(0,10);
String fmt(Object? v)=>v==null?'—':v.toString();
Future<void> editForm(BuildContext context, String title,
    List<(String, TextEditingController)> fields,
    Future<void> Function() save) async {
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: fields.map((f) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: TextField(
              controller: f.$2,
              decoration: InputDecoration(
                labelText: f.$1,
                border: const OutlineInputBorder(),
              ),
            ),
          )).toList(),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
        FilledButton(
          onPressed: () async {
            await save();
            if (ctx.mounted) Navigator.pop(ctx);
          },
          child: const Text('Enregistrer'),
        ),
      ],
    ),
  );
}

class Dashboard extends StatelessWidget {
  const Dashboard({super.key});
  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: Future.wait([
      Store.all('measures', order: 'date DESC'),
      Store.all('meals', order: 'date DESC'),
    ]),
    builder: (context, snapshot) {
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final measures = snapshot.data![0];
      final meals = snapshot.data![1]
          .where((r) => (r['date'] as String).startsWith(today())).toList();
      final calories = meals.fold<double>(
        0, (value, meal) => value + ((meal['calories'] as num?)?.toDouble() ?? 0),
      );
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Dernières mesures', style: Theme.of(context).textTheme.titleLarge),
          if (measures.isNotEmpty)
            Card(child: ListTile(
              title: Text("${fmt(measures.first['weight'])} kg"),
              subtitle: Text("Tour de taille : ${fmt(measures.first['waist'])} cm • ${measures.first['date']}"),
            )),
          const SizedBox(height: 12),
          Text('Aujourd’hui', style: Theme.of(context).textTheme.titleLarge),
          Card(child: ListTile(
            title: Text("${calories.toStringAsFixed(0)} kcal estimées"),
            subtitle: Text("${meals.length} repas enregistré(s)"),
          )),
          const Text('Les estimations alimentaires ne sont pas des mesures exactes.'),
          const SizedBox(height: 12),
          FutureBuilder(
            future: Store.all('measures', order: 'date DESC'),
            builder: (context, history) {
              if (!history.hasData || history.data!.length < 2) return const SizedBox.shrink();
              final recent = history.data!.first;
              final previous = history.data![1];
              final currentWeight = (recent['weight'] as num?)?.toDouble();
              final previousWeight = (previous['weight'] as num?)?.toDouble();
              if (currentWeight == null || previousWeight == null) return const SizedBox.shrink();
              final difference = currentWeight - previousWeight;
              return Card(child: ListTile(
                leading: const Icon(Icons.trending_down),
                title: const Text('Évolution depuis la mesure précédente'),
                subtitle: Text("${difference >= 0 ? '+' : ''}${difference.toStringAsFixed(2)} kg"),
              ));
            },
          ),
          const SizedBox(height: 12),
          const Text('Shaker après sport : 30 g whey, 15 g collagène, 5 g créatine, 300–400 ml d’eau. Enregistrer les prises séparément sans les doubler.'),
        ],
      );
    },
  );
}
class Measurements extends StatelessWidget {
  final VoidCallback reload;
  const Measurements({super.key, required this.reload});
  Future<void> edit(BuildContext context, [Map<String, Object?>? row]) async {
    final date = TextEditingController(text: row?['date'] as String? ?? today());
    final weight = TextEditingController(text: row?['weight']?.toString() ?? '');
    final waist = TextEditingController(text: row?['waist']?.toString() ?? '');
    final note = TextEditingController(text: row?['note'] as String? ?? '');
    await editForm(context, 'Mesure', [
      ('Date AAAA-MM-JJ', date), ('Poids (kg)', weight),
      ('Tour de taille (cm)', waist), ('Note', note),
    ], () async {
      final data = <String, Object?>{
        'date': date.text,
        'weight': double.tryParse(weight.text.replaceAll(',', '.')),
        'waist': double.tryParse(waist.text.replaceAll(',', '.')),
        'note': note.text,
        'approx': row?['approx'] ?? 0,
      };
      if (row == null) {
        await Store.db.insert('measures', data);
      } else {
        await Store.db.update('measures', data, where: 'id=?', whereArgs: [row['id']]);
      }
      reload();
    });
  }
  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: Store.all('measures', order: 'date ASC'),
    builder: (context, snapshot) {
      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
      final rows = snapshot.data!;
      return Column(children: [
        Expanded(child: ListView(children: [
          if (rows.length > 1)
            SizedBox(height: 190, child: Padding(
              padding: const EdgeInsets.all(16),
              child: LineChart(LineChartData(
                titlesData: const FlTitlesData(show: false),
                lineBarsData: [LineChartBarData(
                  spots: [
                    for (var i = 0; i < rows.length; i++)
                      if (rows[i]['weight'] != null)
                        FlSpot(i.toDouble(), (rows[i]['weight'] as num).toDouble()),
                  ],
                  isCurved: false,
                  dotData: const FlDotData(show: true),
                )],
              )),
            )),
          for (final row in rows.reversed)
            ListTile(
              title: Text("${row['date']} : ${fmt(row['weight'])} kg • ${fmt(row['waist'])} cm"),
              subtitle: Text("${row['approx'] == 1 ? 'Approximation • ' : ''}${fmt(row['note'])}"),
              onTap: () => edit(context, row),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  await Store.db.delete('measures', where: 'id=?', whereArgs: [row['id']]);
                  reload();
                },
              ),
            ),
        ])),
        Padding(padding: const EdgeInsets.all(12), child: FilledButton.icon(
          onPressed: () => edit(context),
          icon: const Icon(Icons.add),
          label: const Text('Ajouter une mesure'),
        )),
      ]);
    },
  );
}
class Meals extends StatelessWidget{final VoidCallback reload;const Meals({super.key,required this.reload});Future<void> edit(BuildContext context,[Map<String,Object?>? row]) async{String? photo=row?['photo'] as String?;final date=TextEditingController(text:row?['date'] as String? ??today()),category=TextEditingController(text:row?['category'] as String? ??'Déjeuner'),desc=TextEditingController(text:row?['description'] as String? ??''),cal=TextEditingController(text:fmt(row?['calories'])=='—'?'':fmt(row?['calories'])),pro=TextEditingController(text:fmt(row?['protein'])=='—'?'':fmt(row?['protein'])),carb=TextEditingController(text:fmt(row?['carbs'])=='—'?'':fmt(row?['carbs'])),fat=TextEditingController(text:fmt(row?['fat'])=='—'?'':fmt(row?['fat'])),unc=TextEditingController(text:row?['uncertainty'] as String? ??''),notes=TextEditingController(text:row?['notes'] as String? ??'');
 await showModalBottomSheet(context:context,isScrollControlled:true,useSafeArea:true,builder:(ctx)=>StatefulBuilder(builder:(ctx,setLocal)=>Padding(padding:EdgeInsets.fromLTRB(16,16,16,MediaQuery.of(ctx).viewInsets.bottom+MediaQuery.of(ctx).viewPadding.bottom+24),child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[const Text('Repas : valeurs estimées, à vérifier'),for(final f in [('Date',date),('Catégorie',category),('Aliments et quantités',desc),('Calories (kcal)',cal),('Protéines (g)',pro),('Glucides (g)',carb),('Lipides (g)',fat),('Incertitudes',unc),('Commentaires',notes)])TextField(controller:f.$2,decoration:InputDecoration(labelText:f.$1)),Wrap(children:[TextButton.icon(onPressed:() async{final x=await ImagePicker().pickImage(source:ImageSource.camera);if(x!=null){final dir=await getApplicationDocumentsDirectory();final dest=p.join(dir.path,'meal_${DateTime.now().microsecondsSinceEpoch}${p.extension(x.path)}');await File(x.path).copy(dest);setLocal(()=>photo=dest);}},icon:const Icon(Icons.camera_alt),label:const Text('Photo')),TextButton.icon(onPressed:() async{final x=await ImagePicker().pickImage(source:ImageSource.gallery);if(x!=null){final dir=await getApplicationDocumentsDirectory();final dest=p.join(dir.path,'meal_${DateTime.now().microsecondsSinceEpoch}${p.extension(x.path)}');await File(x.path).copy(dest);setLocal(()=>photo=dest);}},icon:const Icon(Icons.photo_library),label:const Text('Galerie')),if(photo!=null)TextButton(onPressed:(){setLocal(()=>photo=null);},child:const Text('Retirer la photo'))]),FilledButton(onPressed:() async{double? numValue(TextEditingController c)=>double.tryParse(c.text.replaceAll(',','.'));final data={'date':date.text,'category':category.text,'description':desc.text,'photo':photo,'calories':numValue(cal),'protein':numValue(pro),'carbs':numValue(carb),'fat':numValue(fat),'uncertainty':unc.text,'notes':notes.text};if(row==null){await Store.db.insert('meals',data);}else{await Store.db.update('meals',data,where:'id=?',whereArgs:[row['id']]);}if(ctx.mounted)Navigator.pop(ctx);reload();},child:const Text('Valider le repas'))])))));}
 @override Widget build(BuildContext context)=>FutureBuilder(future:Store.all('meals',order:'date DESC'),builder:(c,s)=>Column(children:[Expanded(child:ListView(children:[for(final r in s.data??<Map<String,Object?>>[])ListTile(leading:r['photo']!=null&&File(r['photo'] as String).existsSync()?Image.file(File(r['photo'] as String),width:55,height:55,fit:BoxFit.cover):const Icon(Icons.restaurant),title:Text('${r['category']} • ${r['date']}'),subtitle:Text('${r['description']}\n${fmt(r['calories'])} kcal estimées'),isThreeLine:true,onTap:()=>edit(context,r),trailing:PopupMenuButton<String>(onSelected:(v) async{if(v=='duplicate'){final data=Map<String,Object?>.from(r)..remove('id');data['date']=today();await Store.db.insert('meals',data);}else if(v=='delete'){await Store.db.delete('meals',where:'id=?',whereArgs:[r['id']]);}else if(v=='photo'){await Store.db.update('meals',{'photo':null},where:'id=?',whereArgs:[r['id']]);}reload();},itemBuilder:(_)=>const [PopupMenuItem(value:'duplicate',child:Text('Dupliquer')),PopupMenuItem(value:'photo',child:Text('Retirer la photo')),PopupMenuItem(value:'delete',child:Text('Supprimer'))]))])),FilledButton.icon(onPressed:()=>edit(context),icon:const Icon(Icons.add),label:const Text('Ajouter un repas'))]));
}
class Supplements extends StatelessWidget{final VoidCallback reload;const Supplements({super.key,required this.reload});@override Widget build(BuildContext context)=>FutureBuilder(future:Future.wait([Store.all('supplements'),Store.all('intakes')]),builder:(c,s){if(!s.hasData)return const Center(child:CircularProgressIndicator());final taken=s.data![1].where((r)=>r['date']==today()).map((r)=>r['supplement_id']).toSet();return ListView(children:[for(final r in s.data![0])SwitchListTile(title:Text('${r['name']} • ${r['dose']}'),subtitle:Text('${r['brand']}\n${r['details']}'),isThreeLine:true,value:taken.contains(r['id']),onChanged:r['active']==0?null:(v) async{if(v){await Store.db.insert('intakes',{'supplement_id':r['id'],'date':today()});}else{await Store.db.delete('intakes',where:'supplement_id=? AND date=?',whereArgs:[r['id'],today()]);}reload();},secondary:IconButton(icon:const Icon(Icons.edit),onPressed:() async{final dose=TextEditingController(text:fmt(r['dose'])),details=TextEditingController(text:fmt(r['details']));await editForm(context,'Modifier le complément',[('Dose',dose),('Composition / notes',details)],() async{await Store.db.update('supplements',{'dose':dose.text,'details':details.text},where:'id=?',whereArgs:[r['id']]);reload();});}))]);});}
class More extends StatelessWidget{final VoidCallback reload;const More({super.key,required this.reload});@override Widget build(BuildContext context)=>ListView(children:[ListTile(title:const Text('Exporter les données JSON'),leading:const Icon(Icons.upload_file),onTap:Store.export),ListTile(title:const Text('Restaurer les données JSON'),subtitle:const Text('Remplace les données locales ; conserver une sauvegarde avant.'),leading:const Icon(Icons.download),onTap:() async{try{await Store.restore();reload();}catch(e){if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Restauration impossible : $e')));}}),ListTile(title:const Text('Activité et récupération'),onTap:() async{final kind=TextEditingController(),duration=TextEditingController(),intensity=TextEditingController(),notes=TextEditingController();await editForm(context,'Nouvelle activité',[('Type',kind),('Durée (minutes)',duration),('Intensité',intensity),('Fatigue, sommeil, douleurs, chaleur',notes)],() async{await Store.db.insert('activities',{'date':today(),'type':kind.text,'duration':int.tryParse(duration.text),'intensity':intensity.text,'notes':notes.text});reload();});}),ListTile(title:const Text('Objectif quotidien en calories'),subtitle:const Text('Définir un objectif personnel, sans calcul automatique'),leading:const Icon(Icons.flag_outlined),onTap:() async{
 final existing=await Store.db.query('settings',where:'key=?',whereArgs:['calorie_goal']);
 final controller=TextEditingController(text:existing.isEmpty?'':(existing.first['value'] as String? ?? ''));
 if(!context.mounted)return;
 await editForm(context,'Objectif calorique',[('kcal par jour',controller)],() async{
 final value=int.tryParse(controller.text);
 if(value==null||value<500||value>10000)throw const FormatException('Objectif hors limites');
 await Store.db.insert('settings',{'key':'calorie_goal','value':'$value'},conflictAlgorithm:ConflictAlgorithm.replace);
 reload();
 });
}),const ListTile(title:Text('Analyse IA des photos'),subtitle:Text('À venir : aucune photo n’est transmise à un serveur.'))]);}
