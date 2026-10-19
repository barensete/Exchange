import 'dart:convert';

import 'package:fasoresto/donnees/depot.dart';
import 'package:fasoresto/io/sauvegarde.dart';
import 'package:fasoresto/modele/modeles.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Faux dossier d'assets contenant seulement les fichiers donnés.
class _Assets extends CachingAssetBundle {
  _Assets(this.fichiers);
  final Map<String, List<int>> fichiers;

  @override
  Future<ByteData> load(String key) async {
    final octets = fichiers[key];
    if (octets == null) throw Exception('absent : $key');
    return ByteData.sublistView(Uint8List.fromList(octets));
  }
}

void main() {
  test('sans données de départ : rien', () async {
    expect(await Depot.donneesDeDepart(_Assets({})), isNull);
  });

  test('depart.json est chargé', () async {
    final d = Donnees(journees: [Journee(date: DateTime(2026, 9, 1), matin: 1000)]);
    final assets = _Assets({'assets/donnees/depart.json': utf8.encode(Sauvegarde.exporter(d))});
    final depart = await Depot.donneesDeDepart(assets);
    expect(depart!.journees.single.matin, 1000);
  });

  test('un fichier abîmé est ignoré', () async {
    final assets = _Assets({
      'assets/donnees/depart.xlsx': [1, 2, 3],
    });
    expect(await Depot.donneesDeDepart(assets), isNull);
  });
}
