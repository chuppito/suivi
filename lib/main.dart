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
  for(final entry in <String,String>{'calorie_goal':'2350','points_goal':'48','protein_goal':'140','fat_goal':'75','carb_goal':'280','weight_goal':'88'}.entries){
    await db.insert('settings',{'key':entry.key,'value':entry.value},conflictAlgorithm:ConflictAlgorithm.ignore);
  }
  if((await db.rawQuery('SELECT COUNT(*) n FROM measures')).first['n']==0){
   for(final r in seedMeasurements){await db.insert('measures',{'date':r.$1,'weight':r.$2,'waist':r.$3,'approx':r.$4,'note':r.$5});}
  }
  for (final entry in {'calorie_goal':'2350','points_goal':'48','protein_goal':'140','fat_goal':'75','carb_goal':'280','weight_goal':'88'}.entries) {
    await db.insert('settings',{'key':entry.key,'value':entry.value},conflictAlgorithm:ConflictAlgorithm.ignore);
  }
  if((await db.rawQuery('SELECT COUNT(*) n FROM supplements')).first['n']==0){
   for(final s in seedSupplements){await db.insert('supplements',s);}
  }
 }
 static Future<List<Map<String,Object?>>> all(String table,{String order='id DESC'})=>db.query(table,orderBy:table=='settings'?'key ASC':order);
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

/// Barème indépendant et indicatif, différent des points WeightWatchers.
/// 1 point pour environ 50 kcal, ajusté légèrement selon la composition.
int? mealPoints(Map<String,Object?> meal) {
 final kcal=(meal['calories'] as num?)?.toDouble();
 if(kcal==null) return null;
 final protein=(meal['protein'] as num?)?.toDouble() ?? 0;
 final fat=(meal['fat'] as num?)?.toDouble() ?? 0;
 final score=(kcal/50 + fat/12 - protein/25).round();
 return score < 0 ? 0 : score;
}
class Dashboard extends StatefulWidget {
  const Dashboard({super.key});
  @override State<Dashboard> createState() => _DashboardState();
}
class _DashboardState extends State<Dashboard> {
  late final Future<List<List<Map<String, Object?>>>> data;
  @override void initState() { super.initState(); data = Future.wait([Store.all('measures',order:'date DESC'),Store.all('meals',order:'date DESC'),Store.all('settings')]); }
  @override
  Widget build(BuildContext context) => FutureBuilder<List<List<Map<String, Object?>>>>(
    future: data,
    // Cached future prevents restarting SQLite reads on every frame.
    
    builder: (context, snapshot) {
      if (snapshot.hasError) { return Center(child: Padding(padding: const EdgeInsets.all(20),child:Text('Impossible de charger l’accueil : ${snapshot.error}'))); }
      if (!snapshot.hasData) { return const Center(child: CircularProgressIndicator()); }
      final measures = snapshot.data![0];
      final meals = snapshot.data![1]
          .where((r) => (r['date'] as String).startsWith(today())).toList();
      final goalSetting = snapshot.data![2].where((row) => row['key'] == 'calorie_goal');
      final goal = goalSetting.isEmpty ? 2350 : int.tryParse(goalSetting.first['value'] as String? ?? '');
      final pointsGoalRow = snapshot.data![2].where((row)=>row['key']=='points_goal');
      final pointsGoal = pointsGoalRow.isEmpty ? 48 : (int.tryParse(pointsGoalRow.first['value'] as String? ?? '') ?? 48);
      final counted = meals.map(mealPoints).whereType<int>().toList();
      final usedPoints = counted.fold<int>(0,(sum,value)=>sum+value);
      final missingPoints = meals.length-counted.length;
      final protein = meals.fold<double>(0,(sum,meal)=>sum+((meal['protein'] as num?)?.toDouble() ?? 0));
      final proteinRow = snapshot.data![2].where((row)=>row['key']=='protein_goal');
      final proteinGoal = proteinRow.isEmpty ? 140 : (int.tryParse(proteinRow.first['value'] as String? ?? '') ?? 140);
      final weightRow = snapshot.data![2].where((row)=>row['key']=='weight_goal');
      final weightGoal = weightRow.isEmpty ? 88.0 : (double.tryParse(weightRow.first['value'] as String? ?? '') ?? 88.0);
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
            subtitle: Text(goal == null ? "${meals.length} repas enregistré(s)" : "${meals.length} repas • objectif : $goal kcal"),
          )),
          Card(child: Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text('Budget de points du jour',style:Theme.of(context).textTheme.titleMedium),
            const SizedBox(height:8),
            Text('$usedPoints / $pointsGoal points utilisés'),
            const SizedBox(height:8),
            LinearProgressIndicator(value:(usedPoints/pointsGoal).clamp(0.0,1.0)),
            const SizedBox(height:8),
            Text(usedPoints<=pointsGoal?'Il reste ${pointsGoal-usedPoints} points':'Budget dépassé de ${usedPoints-pointsGoal} points'),
            if(missingPoints>0)Text('$missingPoints repas sans calories estimées : points non comptés.'),
            const Text('Barème indicatif indépendant, différent de WeightWatchers.'),
          ]))),
          Card(child: ListTile(leading:const Icon(Icons.fitness_center_outlined),title:Text('Protéines : ${protein.toStringAsFixed(0)} / $proteinGoal g'),subtitle:Text('Premier objectif de poids : ${weightGoal.toStringAsFixed(1)} kg'))),
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
const mealCategories = ['Petit-déjeuner', 'Déjeuner', 'Dîner', 'Collation'];
/// Values per 100 g, approximate. A weighed portion improves reliability.
const foodReference = <String, (double,double,double,double)>{
 'lait entier':(64,3.2,4.8,3.6),'nesquik':(380,4.5,80,3.5),
 'miel':(304,0.3,82,0),'pain de campagne':(255,8.5,50,1.5),
 'pain':(265,9,49,3.2),'riz cuit':(130,2.7,28,0.3),
 'pâtes cuites':(155,5.8,30,0.9),'poulet':(165,31,0,3.6),
 'saumon':(208,20,0,13),'oeuf':(143,13,1.1,9.5),
 'œuf':(143,13,1.1,9.5),'banane':(89,1.1,23,0.3),
 'pomme de terre':(87,1.9,20,0.1),'pomme':(52,0.3,14,0.2),
 'brocoli':(35,2.4,7,0.4),'huile olive':(884,0,0,100),
 'huile':(884,0,0,100),'beurre':(717,0.9,0.1,81),
 'fromage blanc':(75,8,4,3),'yaourt nature':(61,3.5,4.7,3.3),
 'flocons avoine':(389,17,66,7),'whey':(377,70,8,6),
};
/// Approximations: teaspoon 5 ml, tablespoon 15 ml, glass 200 ml,
/// bowl 250 ml, small bread slice 25 g. Density depends on food.
double? estimateGrams(String item,String food) {
 final explicit=RegExp(r'(\d+(?:[.,]\d+)?)\s*(kg|grammes?|g|ml|cl|l)\b').firstMatch(item);
 if(explicit!=null){
  final n=double.parse(explicit.group(1)!.replaceAll(',','.'));
  switch(explicit.group(2)){case 'kg':return n*1000;case 'cl':return n*10;case 'l':return n*1000;default:return n;}
 }
 final words=<String,double>{'un':1,'une':1,'deux':2,'trois':3,'quatre':4,'cinq':5,'six':6,'sept':7,'huit':8};
 final qty=RegExp(r'\b(\d+(?:[.,]\d+)?|un|une|deux|trois|quatre|cinq|six|sept|huit)\b').firstMatch(item);
 final count=qty==null?1.0:(words[qty.group(1)]??double.tryParse(qty.group(1)!.replaceAll(',','.'))??1.0);
 if(RegExp(r'cuill[eè]res?\s+(?:[àa]\s+)?caf[eé]|c\.?\s*[àa]\s*c\.?').hasMatch(item)){
  return count*(food.contains('nesquik')?6:food.contains('miel')?8:food.contains('beurre')?6:5);
 }
 if(RegExp(r'cuill[eè]res?\s+(?:[àa]\s+)?soupe|c\.?\s*[àa]\s*s\.?').hasMatch(item)){
  return count*(food.contains('nesquik')?15:food.contains('miel')?22:food.contains('beurre')?15:15);
 }
 if(RegExp(r'bols?\b').hasMatch(item))return count*250;
 if(RegExp(r'verres?\b').hasMatch(item))return count*200;
 if(RegExp(r'tranches?\b').hasMatch(item))return count*(food.contains('pain')?25:25);
 return null;
}
(String,int) describeEstimate(String input) {
 final parts=input.toLowerCase().split(RegExp(r'[,;\n]+')).where((s)=>s.trim().isNotEmpty).toList();
 final unknown=<String>[];
 for(final part in parts){
  final matches=foodReference.keys.where((name)=>part.contains(name)).toList()..sort((a,b)=>b.length.compareTo(a.length));
  if(matches.isEmpty||estimateGrams(part,matches.first)==null)unknown.add(part.trim());
 }
 return (unknown.join(', '),parts.length);
}
(double,double,double,double,int) estimateFoods(String input) {
 double kcal=0,protein=0,carbs=0,fat=0;
 int recognized=0;
 for(final raw in input.toLowerCase().split(RegExp(r'[,;\n]+'))){
  final item=raw.trim();
  final names=foodReference.keys.where((name)=>item.contains(name)).toList()
    ..sort((a,b)=>b.length.compareTo(a.length));
  if(names.isEmpty)continue;
  final grams=estimateGrams(item,names.first);
  if(grams==null||grams<=0)continue;
  final values=foodReference[names.first]!,factor=grams/100;
  kcal+=values.$1*factor;protein+=values.$2*factor;
  carbs+=values.$3*factor;fat+=values.$4*factor;recognized++;
 }
 return (kcal,protein,carbs,fat,recognized);
}

class Meals extends StatelessWidget{final VoidCallback reload;const Meals({super.key,required this.reload});Future<void> edit(BuildContext context,[Map<String,Object?>? row]) async{String? photo=row?['photo'] as String?;final date=TextEditingController(text:row?['date'] as String? ??today()),category=TextEditingController(text:row?['category'] as String? ??'Déjeuner'),desc=TextEditingController(text:row?['description'] as String? ??''),cal=TextEditingController(text:fmt(row?['calories'])=='—'?'':fmt(row?['calories'])),pro=TextEditingController(text:fmt(row?['protein'])=='—'?'':fmt(row?['protein'])),carb=TextEditingController(text:fmt(row?['carbs'])=='—'?'':fmt(row?['carbs'])),fat=TextEditingController(text:fmt(row?['fat'])=='—'?'':fmt(row?['fat'])),unc=TextEditingController(text:row?['uncertainty'] as String? ??''),notes=TextEditingController(text:row?['notes'] as String? ??'');
 await showModalBottomSheet(context:context,isScrollControlled:true,useSafeArea:true,builder:(ctx)=>StatefulBuilder(builder:(ctx,setLocal)=>Padding(padding:EdgeInsets.fromLTRB(16,16,16,MediaQuery.of(ctx).viewInsets.bottom+MediaQuery.of(ctx).viewPadding.bottom+24),child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[const Text('Repas : valeurs estimées, à vérifier'),DropdownButtonFormField<String>(value:mealCategories.contains(category.text)?category.text:'Déjeuner',decoration:const InputDecoration(labelText:'Catégorie du repas'),items:[for(final name in mealCategories)DropdownMenuItem(value:name,child:Text(name))],onChanged:(v){if(v!=null)category.text=v;}),for(final f in [('Date',date),('Aliments et portions (ex : lait entier 1 bol, nesquik 2 cuillères à café)',desc),('Calories (kcal)',cal),('Protéines (g)',pro),('Glucides (g)',carb),('Lipides (g)',fat),('Incertitudes',unc),('Commentaires',notes)])TextField(controller:f.$2,decoration:InputDecoration(labelText:f.$1)),TextButton.icon(onPressed:(){final estimate=estimateFoods(desc.text);final missing=describeEstimate(desc.text);if(missing.$1.isNotEmpty){ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content:Text('Aliments non évalués : ${missing.$1}. Préciser les quantités ou compléter manuellement.')));return;}if(estimate.$5==0){ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content:Text('Indiquer un aliment et sa portion (ex : lait entier 1 bol, nesquik 2 cuillères à café, pain 4 tranches).')));return;}setLocal((){cal.text=estimate.$1.toStringAsFixed(0);pro.text=estimate.$2.toStringAsFixed(1);carb.text=estimate.$3.toStringAsFixed(1);fat.text=estimate.$4.toStringAsFixed(1);unc.text='Estimation PARTIELLE sur ${estimate.$5} aliment(s) reconnus ; tous les autres ingrédients ne sont pas comptés. Vérifier et compléter avant enregistrement.';});},icon:const Icon(Icons.calculate_outlined),label:const Text('Estimer les calories et macros')),const Text('Portions indicatives : cuillère à café 5 ml, cuillère à soupe 15 ml, bol 250 ml, verre 200 ml, petite tranche de pain 25 g. Les poids réels varient selon l’aliment. L’analyse photo par IA nécessite un service en ligne sécurisé.'),Wrap(children:[TextButton.icon(onPressed:() async{final x=await ImagePicker().pickImage(source:ImageSource.camera);if(x!=null){final dir=await getApplicationDocumentsDirectory();final dest=p.join(dir.path,'meal_${DateTime.now().microsecondsSinceEpoch}${p.extension(x.path)}');await File(x.path).copy(dest);setLocal(()=>photo=dest);}},icon:const Icon(Icons.camera_alt),label:const Text('Photo')),TextButton.icon(onPressed:() async{final x=await ImagePicker().pickImage(source:ImageSource.gallery);if(x!=null){final dir=await getApplicationDocumentsDirectory();final dest=p.join(dir.path,'meal_${DateTime.now().microsecondsSinceEpoch}${p.extension(x.path)}');await File(x.path).copy(dest);setLocal(()=>photo=dest);}},icon:const Icon(Icons.photo_library),label:const Text('Galerie')),if(photo!=null)TextButton(onPressed:(){setLocal(()=>photo=null);},child:const Text('Retirer la photo'))]),FilledButton(onPressed:() async{double? numValue(TextEditingController c)=>double.tryParse(c.text.replaceAll(',','.'));final estimate=estimateFoods(desc.text);
 final missing=describeEstimate(desc.text);
 if(missing.$1.isNotEmpty && numValue(cal)==null){ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content:Text('Aliments non évalués : ${missing.$1}. Compléter les calories manuellement.')));return;}
 if(estimate.$5==0 && numValue(cal)==null){ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content:Text('Renseigne les calories ou des aliments avec leurs quantités.')));return;}
 final data={'date':date.text,'category':category.text,'description':desc.text,'photo':photo,'calories':numValue(cal),'protein':numValue(pro),'carbs':numValue(carb),'fat':numValue(fat),'uncertainty':unc.text,'notes':notes.text};if(row==null){await Store.db.insert('meals',data);}else{await Store.db.update('meals',data,where:'id=?',whereArgs:[row['id']]);}if(ctx.mounted)Navigator.pop(ctx);reload();},child:const Text('Valider le repas'))])))));}
 @override Widget build(BuildContext context)=>FutureBuilder(future:Store.all('meals',order:'date DESC'),builder:(c,s)=>Column(children:[Expanded(child:ListView(children:[for(final r in s.data??<Map<String,Object?>>[])ListTile(leading:r['photo']!=null&&File(r['photo'] as String).existsSync()?Image.file(File(r['photo'] as String),width:55,height:55,fit:BoxFit.cover):const Icon(Icons.restaurant),title:Text('${r['category']} • ${r['date']}'),subtitle:Text('${r['description']}\n${fmt(r['calories'])} kcal estimées • ${mealPoints(r)?.toString() ?? '—'} points'),isThreeLine:true,onTap:()=>edit(context,r),trailing:PopupMenuButton<String>(onSelected:(v) async{if(v=='duplicate'){final data=Map<String,Object?>.from(r)..remove('id');data['date']=today();await Store.db.insert('meals',data);}else if(v=='delete'){await Store.db.delete('meals',where:'id=?',whereArgs:[r['id']]);}else if(v=='photo'){await Store.db.update('meals',{'photo':null},where:'id=?',whereArgs:[r['id']]);}reload();},itemBuilder:(_)=>const [PopupMenuItem(value:'duplicate',child:Text('Dupliquer')),PopupMenuItem(value:'photo',child:Text('Retirer la photo')),PopupMenuItem(value:'delete',child:Text('Supprimer'))]))])),FilledButton.icon(onPressed:()=>edit(context),icon:const Icon(Icons.add),label:const Text('Ajouter un repas'))]));
}
class Supplements extends StatefulWidget {
 final VoidCallback reload;
 const Supplements({super.key,required this.reload});
 @override State<Supplements> createState()=>_SupplementsState();
}
class _SupplementsState extends State<Supplements> {
 late Future<List<List<Map<String,Object?>>>> future;
 @override void initState(){super.initState();refresh();}
 void refresh(){future=Future.wait([Store.all('supplements'),Store.all('intakes')]);}
 void changed(){setState(refresh);widget.reload();}
 Future<void> mark(Map<String,Object?> supplement,bool value) async {
  if(value){
   final exists=await Store.db.query('intakes',where:'supplement_id=? AND date=?',whereArgs:[supplement['id'],today()]);
   if(exists.isEmpty)await Store.db.insert('intakes',{'supplement_id':supplement['id'],'date':today()});
  }else{
   await Store.db.delete('intakes',where:'supplement_id=? AND date=?',whereArgs:[supplement['id'],today()]);
  }
 }
 @override Widget build(BuildContext context)=>FutureBuilder<List<List<Map<String,Object?>>>>(
 future:future,builder:(context,s){
  if(s.hasError)return Center(child:Text('Erreur compléments : ${s.error}'));
  if(!s.hasData)return const Center(child:CircularProgressIndicator());
  final supplements=s.data![0];
  final taken=s.data![1].where((r)=>r['date']==today()).map((r)=>r['supplement_id']).toSet();
  final shaker=supplements.where((r){
   final name=(r['name'] as String).toLowerCase();
   return name.contains('whey')||name.contains('créatine')||name.contains('collagène');
  }).toList();
  final shakerDone=shaker.isNotEmpty&&shaker.every((r)=>taken.contains(r['id']));
  return ListView(padding:const EdgeInsets.all(12),children:[
   Card(child:SwitchListTile(
    secondary:const Icon(Icons.local_drink_outlined),
    title:const Text('Shaker pris aujourd’hui'),
    subtitle:const Text('Whey 30 g + collagène 15 g + créatine 5 g. Coche les trois prises ensemble.'),
    value:shakerDone,
    onChanged:shaker.isEmpty?null:(v)async{
     for(final r in shaker){await mark(r,v);}
     changed();
    },
   )),
   const Padding(padding:EdgeInsets.all(12),child:Text('Compléments individuels')),
   for(final r in supplements)
    SwitchListTile(
     title:Text('${r['name']} • ${r['dose']}'),
     subtitle:Text('${r['brand']}\n${r['details']}'),
     isThreeLine:true,
     value:taken.contains(r['id']),
     onChanged:r['active']==0?null:(v)async{await mark(r,v);changed();},
     secondary:IconButton(icon:const Icon(Icons.edit_outlined),onPressed:()async{
      final dose=TextEditingController(text:fmt(r['dose']));
      final details=TextEditingController(text:fmt(r['details']));
      await editForm(context,'Modifier le complément',[('Dose',dose),('Composition / notes',details)],()async{
       await Store.db.update('supplements',{'dose':dose.text,'details':details.text},where:'id=?',whereArgs:[r['id']]);
       changed();
      });
     }),
    ),
   const Padding(padding:EdgeInsets.all(12),child:Text('Psyllium : à cocher uniquement si pris. À utiliser avec suffisamment d’eau ; demander conseil en cas de trouble de déglutition ou de problème intestinal.')),
  ]);
 });
}
class More extends StatelessWidget{final VoidCallback reload;const More({super.key,required this.reload});@override Widget build(BuildContext context)=>ListView(children:[ListTile(title:const Text('Exporter les données JSON'),leading:const Icon(Icons.upload_file),onTap:Store.export),ListTile(title:const Text('Restaurer les données JSON'),subtitle:const Text('Remplace les données locales ; conserver une sauvegarde avant.'),leading:const Icon(Icons.download),onTap:() async{try{await Store.restore();reload();}catch(e){if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Restauration impossible : $e')));}}),ListTile(title:const Text('Activité et récupération'),onTap:() async{final kind=TextEditingController(),duration=TextEditingController(),intensity=TextEditingController(),notes=TextEditingController();await editForm(context,'Nouvelle activité',[('Type',kind),('Durée (minutes)',duration),('Intensité',intensity),('Fatigue, sommeil, douleurs, chaleur',notes)],() async{await Store.db.insert('activities',{'date':today(),'type':kind.text,'duration':int.tryParse(duration.text),'intensity':intensity.text,'notes':notes.text});reload();});}),ListTile(title:const Text('Objectifs nutrition et poids'),subtitle:const Text('Protéines, lipides, glucides et poids cible'),leading:const Icon(Icons.track_changes),onTap:()async{
 final rows=await Store.all('settings');
 final settings={for(final row in rows) row['key'] as String:row['value'] as String? ?? ''};
 final protein=TextEditingController(text:settings['protein_goal']??'140');
 final fat=TextEditingController(text:settings['fat_goal']??'75');
 final carbs=TextEditingController(text:settings['carb_goal']??'280');
 final weight=TextEditingController(text:settings['weight_goal']??'88');
 if(!context.mounted)return;
 await editForm(context,'Objectifs personnalisés',[('Protéines (g/jour)',protein),('Lipides (g/jour)',fat),('Glucides (g/jour)',carbs),('Poids cible (kg)',weight)],()async{
  final values={'protein_goal':protein.text,'fat_goal':fat.text,'carb_goal':carbs.text,'weight_goal':weight.text};
  if(values.values.any((v)=>double.tryParse(v.replaceAll(',','.'))==null))return;
  for(final entry in values.entries){
   await Store.db.insert('settings',{'key':entry.key,'value':entry.value.replaceAll(',','.')},conflictAlgorithm:ConflictAlgorithm.replace);
  }
  reload();
 });
}),ListTile(title:const Text('Budget de points quotidien'),subtitle:const Text('48 points de départ, budget modifiable'),leading:const Icon(Icons.toll_outlined),onTap:() async{
 final existing=await Store.db.query('settings',where:'key=?',whereArgs:['points_goal']);
 final controller=TextEditingController(text:existing.isEmpty?'48':(existing.first['value'] as String? ?? '48'));
 if(!context.mounted)return;
 await editForm(context,'Budget de points',[('Points par jour (5 à 100)',controller)],() async{
 final value=int.tryParse(controller.text);
 if(value==null||value<5||value>100)return;
 await Store.db.insert('settings',{'key':'points_goal','value':'$value'},conflictAlgorithm:ConflictAlgorithm.replace);
 reload();
 });
}),ListTile(title:const Text('Objectif quotidien en calories'),subtitle:const Text('Définir un objectif personnel, sans calcul automatique'),leading:const Icon(Icons.flag_outlined),onTap:() async{
 final existing=await Store.db.query('settings',where:'key=?',whereArgs:['calorie_goal']);
 final controller=TextEditingController(text:existing.isEmpty?'2350':(existing.first['value'] as String? ?? '2350'));
 if(!context.mounted)return;
 await editForm(context,'Objectif calorique',[('kcal par jour',controller)],() async{
 final value=int.tryParse(controller.text);
 if(value==null||value<500||value>10000)return;
 await Store.db.insert('settings',{'key':'calorie_goal','value':'$value'},conflictAlgorithm:ConflictAlgorithm.replace);
 reload();
 });
}),const ListTile(title:Text('Analyse IA des photos'),subtitle:Text('À venir : aucune photo n’est transmise à un serveur.'))]);}
