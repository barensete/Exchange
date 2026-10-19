import 'package:fasoresto/donnees/depot.dart';
import 'package:fasoresto/modele/modeles.dart';
import 'package:fasoresto/ui/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('les onglets s\'affichent et la caisse du jour se saisit', (tester) async {
    final depot = Depot.enMemoire();
    await tester.pumpWidget(FasoRestoApp(depot: depot));
    expect(find.text('FasoResto'), findsOneWidget);
    expect(find.text('Saisir la caisse du jour'), findsOneWidget);

    await tester.tap(find.text('Saisir la caisse du jour'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Matin'), '12500');
    await tester.pump();
    expect(find.text('12 500 F'), findsWidgets);
    await tester.tap(find.byTooltip('Enregistrer'));
    await tester.pumpAndSettle();

    expect(depot.donnees.journees.single.matin, 12500);
    expect(find.text('Modifier la caisse du jour'), findsOneWidget);

    for (final icone in [Icons.point_of_sale, Icons.receipt_long, Icons.person_search, Icons.more_horiz, Icons.home]) {
      await tester.tap(find.byIcon(icone));
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('ajout d\'une dépense', (tester) async {
    final depot = Depot.enMemoire();
    await tester.pumpWidget(FasoRestoApp(depot: depot));
    await tester.tap(find.byIcon(Icons.receipt_long));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ajouter'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Article'), 'Pain');
    await tester.enterText(find.widgetWithText(TextField, 'Montant'), '4000');
    await tester.tap(find.widgetWithText(ChoiceChip, 'Caisse'));
    await tester.pump();
    await tester.tap(find.byTooltip('Enregistrer'));
    await tester.pumpAndSettle();
    final d = depot.donnees.depenses.single;
    expect(d.montant, 4000);
    expect(d.payeAvec, SourcePaiement.caisse);
    expect(d.id, greaterThan(0));
  });

  testWidgets('avec des données : graphique, bilans du mois et recherche', (tester) async {
    final jours = [for (var i = 1; i <= 20; i++) Journee(date: DateTime(2026, 9, i), matin: 1000 * i, soir: 500)];
    final depot = Depot.enMemoire(
      Donnees(
        journees: jours,
        depenses: [
          Depense(
            id: 1,
            date: DateTime(2026, 9, 2),
            article: 'Pain',
            montant: 4000,
            payeAvec: SourcePaiement.caisse,
            categorie: Categorie.achatsAlimentaires,
          ),
          Depense(
            id: 2,
            date: DateTime(2026, 7, 26),
            article: 'Oignons sac 25kg',
            montant: 15000,
            payeAvec: SourcePaiement.tresorerie,
            categorie: Categorie.achatsAlimentaires,
          ),
        ],
      ),
    );
    await tester.pumpWidget(FasoRestoApp(depot: depot));
    expect(find.text('Recette des 14 dernières journées'), findsOneWidget);
    expect(find.textContaining('Meilleure journée : 20/09/2026'), findsOneWidget);
    await tester.scrollUntilVisible(find.textContaining('date suspecte'), 300);
    expect(find.textContaining('1 dépense(s) avec une date suspecte'), findsOneWidget);

    // Recherche dans les dépenses.
    await tester.tap(find.byIcon(Icons.receipt_long));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'oign');
    await tester.pump();
    expect(find.text('Oignons sac 25kg'), findsOneWidget);
    expect(find.text('Pain'), findsNothing);

    // Bilans du mois avec détail par service et par catégorie.
    await tester.tap(find.byIcon(Icons.more_horiz));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bilans'));
    await tester.pumpAndSettle();
    expect(find.text('Septembre 2026'), findsOneWidget);
    await tester.dragUntilVisible(
      find.text('Dépenses par catégorie').first,
      find.byType(ListView).first,
      const Offset(0, -300),
    );
    expect(find.text('Recette par service'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
