import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../donnees/depot.dart';
import 'composants.dart';
import 'ecrans/accueil.dart';
import 'ecrans/caisse.dart';
import 'ecrans/depenses.dart';
import 'ecrans/impayes.dart';
import 'ecrans/plus.dart';

class FasoRestoApp extends StatelessWidget {
  const FasoRestoApp({super.key, required this.depot});

  final Depot depot;

  @override
  Widget build(BuildContext context) => DepotScope(
    depot: depot,
    child: MaterialApp(
      title: 'FasoResto',
      debugShowCheckedModeBanner: false,
      // Calendrier, boutons système… en français.
      locale: const Locale('fr'),
      supportedLocales: const [Locale('fr')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: vert)),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: vert, brightness: Brightness.dark),
      ),
      home: const Accueil(),
    ),
  );
}

/// Les cinq onglets du bas de l'écran.
class Accueil extends StatefulWidget {
  const Accueil({super.key});

  @override
  State<Accueil> createState() => _AccueilState();
}

class _AccueilState extends State<Accueil> {
  int _onglet = 0;

  static const _ecrans = [EcranAccueil(), EcranCaisse(), EcranDepenses(), EcranImpayes(), EcranPlus()];

  @override
  Widget build(BuildContext context) => PopScope(
    // Le bouton retour ramène d'abord au Résumé avant de quitter l'application.
    canPop: _onglet == 0,
    onPopInvokedWithResult: (aQuitte, _) {
      if (!aQuitte) setState(() => _onglet = 0);
    },
    child: Scaffold(
      body: SafeArea(child: _ecrans[_onglet]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _onglet,
        onDestinationSelected: (i) => setState(() => _onglet = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'Résumé'),
          NavigationDestination(icon: Icon(Icons.point_of_sale), label: 'Caisse'),
          NavigationDestination(icon: Icon(Icons.receipt_long), label: 'Dépenses'),
          NavigationDestination(icon: Icon(Icons.person_search), label: 'Impayés'),
          NavigationDestination(icon: Icon(Icons.more_horiz), label: 'Plus'),
        ],
      ),
    ),
  );
}
