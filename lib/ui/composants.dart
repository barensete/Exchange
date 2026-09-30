import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../calcul/format.dart';

const vert = Color(0xFF009E49);
const rouge = Color(0xFFEF2B2D);
const jaune = Color(0xFFFCD116);
const orange = Color(0xFFE67E22);

/// Carte avec un titre et des lignes.
class Section extends StatelessWidget {
  const Section({super.key, required this.titre, required this.enfants});

  final String titre;
  final List<Widget> enfants;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(titre, style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.primary)),
            const SizedBox(height: 8),
            ...enfants.expand((e) => [e, const SizedBox(height: 6)]),
          ],
        ),
      ),
    );
  }
}

/// Une ligne « libellé ……… montant ».
class LigneMontant extends StatelessWidget {
  const LigneMontant(this.libelle, this.montant, {super.key, this.fort = false, this.couleur, this.detail});

  final String libelle;
  final int? montant;
  final bool fort;
  final Color? couleur;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final poids = fort ? FontWeight.bold : FontWeight.normal;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(libelle, style: TextStyle(fontWeight: poids)),
            ),
            Text(
              enFcfa(montant),
              style: TextStyle(fontWeight: fort ? FontWeight.bold : FontWeight.w500, color: couleur),
            ),
          ],
        ),
        if (detail != null)
          Text(detail!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ],
    );
  }
}

Color couleurEcart(BuildContext context, int ecart) =>
    ecart == 0 ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.error;

Color couleurResultat(BuildContext context, int v) =>
    v >= 0 ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.error;

/// Champ de saisie d'un montant (clavier numérique). Vide → null.
class ChampMontant extends StatefulWidget {
  const ChampMontant({
    super.key,
    required this.libelle,
    required this.valeur,
    required this.onChange,
    this.obligatoire = false,
  });

  final String libelle;
  final int? valeur;
  final ValueChanged<int?> onChange;
  final bool obligatoire;

  @override
  State<ChampMontant> createState() => _ChampMontantState();
}

class _ChampMontantState extends State<ChampMontant> {
  late final _controleur = TextEditingController(text: widget.valeur?.toString() ?? '');

  @override
  void dispose() {
    _controleur.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: _controleur,
    keyboardType: TextInputType.number,
    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
    decoration: InputDecoration(
      labelText: widget.libelle,
      suffixText: 'F',
      border: const OutlineInputBorder(),
      errorText: widget.obligatoire && _controleur.text.isEmpty ? 'Obligatoire' : null,
    ),
    onChanged: (t) => setState(() => widget.onChange(lireMontant(t))),
  );
}

class ChampTexte extends StatefulWidget {
  const ChampTexte({super.key, required this.libelle, required this.valeur, required this.onChange, this.lignes = 1});

  final String libelle;
  final String valeur;
  final ValueChanged<String> onChange;
  final int lignes;

  @override
  State<ChampTexte> createState() => _ChampTexteState();
}

class _ChampTexteState extends State<ChampTexte> {
  late final _controleur = TextEditingController(text: widget.valeur);

  @override
  void dispose() {
    _controleur.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: _controleur,
    minLines: widget.lignes,
    maxLines: widget.lignes == 1 ? 1 : null,
    textCapitalization: TextCapitalization.sentences,
    decoration: InputDecoration(labelText: widget.libelle, border: const OutlineInputBorder()),
    onChanged: widget.onChange,
  );
}

/// Date choisie dans un calendrier.
class ChampDate extends StatelessWidget {
  const ChampDate({super.key, required this.libelle, required this.date, required this.onChange});

  final String libelle;
  final DateTime? date;
  final ValueChanged<DateTime> onChange;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () async {
      final choisie = await showDatePicker(
        context: context,
        initialDate: date ?? DateTime.now(),
        firstDate: DateTime(2020),
        lastDate: DateTime(2100),
      );
      if (choisie != null) onChange(choisie);
    },
    child: InputDecorator(
      decoration: InputDecoration(
        labelText: libelle,
        border: const OutlineInputBorder(),
        suffixIcon: const Icon(Icons.calendar_month),
        errorText: date == null ? 'Obligatoire' : null,
      ),
      child: Text(date == null ? '' : enTexte(date)),
    ),
  );
}

/// Choix unique parmi quelques options, sous forme de pastilles.
class ChoixPastilles<T> extends StatelessWidget {
  const ChoixPastilles({
    super.key,
    required this.libelle,
    required this.options,
    required this.choisi,
    required this.texte,
    required this.onChange,
  });

  final String libelle;
  final List<T> options;
  final T? choisi;
  final String Function(T) texte;
  final ValueChanged<T> onChange;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          libelle,
          style: theme.textTheme.labelLarge?.copyWith(
            color: choisi == null ? theme.colorScheme.error : theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final o in options)
              ChoiceChip(label: Text(texte(o)), selected: o == choisi, onSelected: (_) => onChange(o)),
          ],
        ),
      ],
    );
  }
}

/// Menu déroulant (liste fermée).
class Selecteur<T> extends StatelessWidget {
  const Selecteur({
    super.key,
    required this.libelle,
    required this.options,
    required this.choisi,
    required this.texte,
    required this.onChange,
  });

  final String libelle;
  final List<T> options;
  final T? choisi;
  final String Function(T) texte;
  final ValueChanged<T> onChange;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<T>(
    initialValue: choisi,
    isExpanded: true,
    decoration: InputDecoration(
      labelText: libelle,
      border: const OutlineInputBorder(),
      errorText: choisi == null ? 'Obligatoire' : null,
    ),
    items: [for (final o in options) DropdownMenuItem(value: o, child: Text(texte(o)))],
    onChanged: (v) {
      if (v != null) onChange(v);
    },
  );
}

/// Texte libre avec suggestions (articles, fournisseurs déjà utilisés).
class ChampSuggestions extends StatelessWidget {
  const ChampSuggestions({
    super.key,
    required this.libelle,
    required this.valeur,
    required this.suggestions,
    required this.onChange,
  });

  final String libelle;
  final String valeur;
  final List<String> suggestions;
  final ValueChanged<String> onChange;

  @override
  Widget build(BuildContext context) => Autocomplete<String>(
    initialValue: TextEditingValue(text: valeur),
    optionsBuilder: (v) {
      final t = v.text.trim().toLowerCase();
      if (t.isEmpty) return const Iterable<String>.empty();
      return suggestions.where((s) => s.toLowerCase().contains(t) && s != v.text).take(8);
    },
    onSelected: onChange,
    fieldViewBuilder: (context, controleur, focus, valider) => TextField(
      controller: controleur,
      focusNode: focus,
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(labelText: libelle, border: const OutlineInputBorder()),
      onChanged: onChange,
      onSubmitted: (_) => valider(),
    ),
  );
}

Future<bool> confirmerSuppression(BuildContext context, String quoi) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer ?'),
        content: Text('$quoi sera supprimé définitivement.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Supprimer', style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    ) ??
    false;

/// Écran de saisie : barre de titre, champs défilants et bouton Enregistrer.
class Formulaire extends StatelessWidget {
  const Formulaire({
    super.key,
    required this.titre,
    required this.champs,
    required this.peutEnregistrer,
    required this.enregistrer,
    this.supprimer,
  });

  final String titre;
  final List<Widget> champs;
  final bool peutEnregistrer;
  final VoidCallback enregistrer;
  final VoidCallback? supprimer;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(titre),
      actions: [
        if (supprimer != null) IconButton(onPressed: supprimer, icon: const Icon(Icons.delete), tooltip: 'Supprimer'),
        // Toujours visible, même quand le bouton du bas est hors de l'écran.
        IconButton(
          onPressed: peutEnregistrer ? enregistrer : null,
          icon: const Icon(Icons.check),
          tooltip: 'Enregistrer',
        ),
      ],
    ),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ...champs.expand((c) => [c, const SizedBox(height: 12)]),
          FilledButton(onPressed: peutEnregistrer ? enregistrer : null, child: const Text('Enregistrer')),
        ],
      ),
    ),
  );
}

class Vide extends StatelessWidget {
  const Vide(this.texte, {super.key});
  final String texte;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(32),
    child: Text(texte, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
  );
}

/// Titre d'un onglet.
class TitreOnglet extends StatelessWidget {
  const TitreOnglet(this.texte, {super.key});
  final String texte;

  @override
  Widget build(BuildContext context) =>
      Text(texte, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold));
}

void message(BuildContext context, String texte) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texte)));
