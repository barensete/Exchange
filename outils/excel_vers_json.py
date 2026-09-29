#!/usr/bin/env python3
"""Convertit le classeur « Comptabilité Faso Resto » (.xlsx) en sauvegarde JSON
importable dans l'application (menu Plus → Importer une sauvegarde).

Usage :
    pip install openpyxl
    python3 outils/excel_vers_json.py Comptabilite_faso_resto.xlsx fasoresto.json

Seuls les onglets de saisie sont lus (Recettes, Dépenses, Impayés,
Remboursements, et les deux cases bleues loyer / salaires de « Semaines & mois ») :
tout le reste est recalculé par l'application.
"""
import datetime as dt
import json
import sys
import warnings

import openpyxl

PREMIERE_LIGNE = 5  # les données commencent à la ligne 5 dans chaque onglet


def date_iso(v):
    if isinstance(v, dt.datetime):
        return v.date().isoformat()
    if isinstance(v, dt.date):
        return v.isoformat()
    return None


def montant(v):
    if v is None or v == "":
        return None
    if isinstance(v, (int, float)):
        return round(v)
    chiffres = "".join(c for c in str(v) if c.isdigit() or c == "-")
    return int(chiffres) if chiffres else None


def texte(v):
    return "" if v is None else str(v).strip()


def lignes(ws, nb_colonnes):
    for ligne in ws.iter_rows(min_row=PREMIERE_LIGNE, max_col=nb_colonnes, values_only=True):
        if any(c not in (None, "") and not (isinstance(c, str) and c.startswith("=")) for c in ligne):
            yield ligne


def convertir(chemin):
    warnings.simplefilter("ignore")
    wb = openpyxl.load_workbook(chemin)

    journees = []
    for a, matin, midi, soir, pate, autre, _g, _h, _i, compte, _k, fond_d, fond_f, _n, _o, rq in lignes(wb["Recettes"], 16):
        if date_iso(a) is None:
            continue
        journees.append({
            "date": date_iso(a),
            "matin": montant(matin) or 0, "midi": montant(midi) or 0, "soir": montant(soir) or 0,
            "pate": montant(pate) or 0, "autre": montant(autre) or 0,
            "argentCompte": montant(compte), "fondDebut": montant(fond_d), "fondFin": montant(fond_f),
            "remarque": texte(rq),
        })

    depenses = []
    for a, article, qte, mt, paye, cat, fourn, rq in lignes(wb["Dépenses"], 8):
        depenses.append({
            "date": date_iso(a), "article": texte(article), "quantite": texte(qte),
            "montant": montant(mt), "payeAvec": texte(paye) or None, "categorie": texte(cat) or None,
            "fournisseur": texte(fourn), "remarque": texte(rq),
        })

    impayes = []
    for a, service, mt, statut, rq in lignes(wb["Impayés"], 5):
        m = montant(mt)
        paye = texte(statut).lower() == "payé"
        impayes.append({
            "date": date_iso(a), "service": texte(service) or None, "montant": m,
            "client": "", "remarque": texte(rq),
            # Le classeur ne garde pas la date du règlement : on reprend la date de l'impayé.
            "reglements": [{"date": date_iso(a), "montant": m}] if paye and m and date_iso(a) else [],
        })

    remboursements = []
    for a, qui, mt, paye, rq in lignes(wb["Remboursements"], 5):
        if date_iso(a) is None:
            continue
        remboursements.append({
            "date": date_iso(a), "associe": texte(qui), "montant": montant(mt) or 0,
            "payeAvec": texte(paye) or "Trésorerie", "remarque": texte(rq),
        })

    sm = wb["Semaines & mois"]
    return {
        "format": "fasoresto",
        "version": 1,
        "parametres": {
            "loyerMensuel": montant(sm["B4"].value) or 0,
            "salairesMensuels": montant(sm["B5"].value) or 0,
        },
        "journees": journees,
        "depenses": depenses,
        "impayes": impayes,
        "remboursements": remboursements,
    }


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    donnees = convertir(sys.argv[1])
    with open(sys.argv[2], "w", encoding="utf-8") as f:
        json.dump(donnees, f, ensure_ascii=False, indent=1)
    print(
        f"{len(donnees['journees'])} journées, {len(donnees['depenses'])} dépenses, "
        f"{len(donnees['impayes'])} impayés, {len(donnees['remboursements'])} remboursements → {sys.argv[2]}"
    )
