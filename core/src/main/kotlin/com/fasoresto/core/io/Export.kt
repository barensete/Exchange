package com.fasoresto.core.io

import com.fasoresto.core.calcul.Comptabilite
import com.fasoresto.core.modele.Donnees

/**
 * Export CSV lisible par Excel en français : séparateur « ; » et BOM UTF-8
 * pour que les accents s'affichent correctement.
 */
object Export {
    private const val BOM = "﻿"

    private fun cellule(v: Any?): String {
        val s = v?.toString().orEmpty()
        return if (s.any { it == ';' || it == '"' || it == '\n' }) "\"" + s.replace("\"", "\"\"") + "\"" else s
    }

    private fun csv(entete: List<String>, lignes: List<List<Any?>>): String =
        BOM + (listOf(entete) + lignes).joinToString("\r\n") { l -> l.joinToString(";", transform = ::cellule) } + "\r\n"

    fun depensesCsv(d: Donnees): String = csv(
        listOf("Date", "Article", "Quantité", "Montant (F)", "Payé avec", "Catégorie", "Fournisseur", "Remarque"),
        d.depenses.sortedWith(compareBy({ it.date }, { it.id })).map {
            listOf(it.date, it.article, it.quantite, it.montant, it.payeAvec?.libelle, it.categorie?.libelle, it.fournisseur, it.remarque)
        },
    )

    fun recettesCsv(d: Donnees): String = csv(
        listOf(
            "Date", "Matin", "Midi", "Soir", "Pâté", "Autre", "Total avant sorties", "Sortie de caisse",
            "Reste en caisse", "Argent compté", "Écart", "Impayés du jour", "Remarque",
        ),
        Comptabilite(d).journees().map {
            val j = it.journee
            listOf(
                j.date, j.matin, j.midi, j.soir, j.pate, j.autre, j.totalAvantSorties, it.sortieDeCaisse,
                it.resteEnCaisse, j.argentCompte, it.ecart, it.impayesDuJour, j.remarque,
            )
        },
    )
}
