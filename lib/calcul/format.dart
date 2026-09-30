/// 12500 → « 12 500 F » (espace fine insécable entre les milliers).
String enFcfa(int? montant) {
  if (montant == null) return '—';
  final chiffres = montant.abs().toString();
  final groupes = <String>[];
  for (var fin = chiffres.length; fin > 0; fin -= 3) {
    groupes.insert(0, chiffres.substring(fin - 3 < 0 ? 0 : fin - 3, fin));
  }
  return '${montant < 0 ? '−' : ''}${groupes.join(' ')} F';
}

/// 2026-09-07 → « 07/09/2026 ».
String enTexte(DateTime? d) =>
    d == null ? 'Sans date' : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

/// Lit un montant tapé par l'utilisateur : « 12 500 », « 12500F ». Vide → null.
int? lireMontant(String texte) {
  final chiffres = texte.replaceAll(RegExp(r'[^0-9-]'), '');
  return chiffres.isEmpty || chiffres == '-' ? null : int.tryParse(chiffres);
}

const _mois = [
  'janvier',
  'février',
  'mars',
  'avril',
  'mai',
  'juin',
  'juillet',
  'août',
  'septembre',
  'octobre',
  'novembre',
  'décembre',
];

/// « Septembre 2026 ».
String nomMois(DateTime d) {
  final m = _mois[d.month - 1];
  return '${m[0].toUpperCase()}${m.substring(1)} ${d.year}';
}

String enPourcent(double? v) => v == null ? '—' : '${(v * 100).toStringAsFixed(1).replaceAll('.', ',')} %';
