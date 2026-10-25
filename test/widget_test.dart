import 'package:flutter_test/flutter_test.dart';
import 'package:suivi_nutrition_corps/main.dart';
void main(){test('Historique initial contient 14 mesures',(){expect(seedMeasurements.length,14);expect(seedMeasurements.first.$3,isNull);expect(seedMeasurements[6].$4,1);});test('C1000 est inactif',(){expect(seedSupplements.last['active'],0);});}
