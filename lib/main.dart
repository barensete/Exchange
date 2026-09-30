import 'package:flutter/material.dart';

import 'donnees/depot.dart';
import 'ui/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final depot = await Depot.ouvrir();
  runApp(FasoRestoApp(depot: depot));
}
