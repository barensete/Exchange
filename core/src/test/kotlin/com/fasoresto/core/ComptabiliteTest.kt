package com.fasoresto.core

import com.fasoresto.core.calcul.Comptabilite
import com.fasoresto.core.calcul.enFcfa
import com.fasoresto.core.calcul.lireMontant
import com.fasoresto.core.io.Sauvegarde
import com.fasoresto.core.modele.Associe
import com.fasoresto.core.modele.Categorie
import com.fasoresto.core.modele.Depense
import com.fasoresto.core.modele.Donnees
import com.fasoresto.core.modele.Impaye
import com.fasoresto.core.modele.Journee
import com.fasoresto.core.modele.Parametres
import com.fasoresto.core.modele.Reglement
import com.fasoresto.core.modele.Remboursement
import com.fasoresto.core.modele.Service
import com.fasoresto.core.modele.SourcePaiement
import java.time.LocalDate
import java.time.YearMonth
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull

class ComptabiliteTest {
    private val j1 = LocalDate.of(2026, 9, 7) // lundi
    private val j2 = LocalDate.of(2026, 9, 8)

    private fun dep(date: LocalDate?, montant: Long?, source: SourcePaiement?, cat: Categorie? = Categorie.ACHATS_ALIMENTAIRES, article: String = "Pain") =
        Depense(date = date, article = article, montant = montant, payeAvec = source, categorie = cat)

    private val donnees = Donnees(
        journees = listOf(
            Journee(j1, matin = 48_000, midi = 9_000, soir = 31_050, pate = 9_500, argentCompte = 90_000),
            Journee(j2, matin = 32_500, midi = 15_500, soir = 41_500, pate = 5_800),
        ),
        depenses = listOf(
            dep(j1, 4_000, SourcePaiement.CAISSE),
            dep(j1, 2_000, SourcePaiement.CAISSE, article = "Viande sans os"),
            dep(j1, 50_000, SourcePaiement.TRESORERIE, Categorie.MATERIEL),
            dep(j2, 30_000, SourcePaiement.BARKA, article = "Foie"),
            dep(j2, 10_000, SourcePaiement.FODIE),
            dep(j2, 6_000, SourcePaiement.PARTAGE),
            dep(j2, 20_000, SourcePaiement.TRESORERIE, Categorie.PERSONNEL, article = "Versement salaire"),
            dep(null, 1_000, null, null), // ligne incomplète
        ),
        impayes = listOf(
            Impaye(date = j1, service = Service.MIDI, montant = 2_000),
            Impaye(date = j1, service = Service.PATE, montant = 3_000, reglements = listOf(Reglement(date = j2, montant = 2_500))),
            Impaye(date = j1, service = Service.AUTRE, montant = 500),
        ),
        remboursements = listOf(
            Remboursement(date = j2, associe = Associe.BARKA, montant = 10_000, payeAvec = SourcePaiement.TRESORERIE),
        ),
        parametres = Parametres(loyerMensuel = 120_000, salairesMensuels = 150_000),
    )

    private val compta = Comptabilite(donnees)

    @Test
    fun `colonnes calculees de la journee`() {
        val jour = compta.journees().first()
        assertEquals(97_550, jour.journee.totalAvantSorties)
        assertEquals(6_000, jour.sortieDeCaisse)
        assertEquals(91_550, jour.resteEnCaisse)
        assertEquals(-1_550, jour.ecart)
        // « Autre » ne compte pas dans les impayés du jour, comme dans le classeur.
        assertEquals(5_000, jour.impayesDuJour)
        assertEquals(102_550, jour.recettePlusImpayes)
        assertNull(compta.journees()[1].ecart)
    }

    @Test
    fun resume() {
        val r = compta.resume()
        assertEquals(97_550 + 95_300, r.totalRecette)
        assertEquals(2_000 + 500 + 500, r.impayesARecevoir)
        assertEquals(123_000, r.totalDepenses)
        assertEquals(6_000, r.depensesParSource[SourcePaiement.CAISSE])
        assertEquals(70_000, r.depensesParSource[SourcePaiement.TRESORERIE])
        assertEquals(20_000, r.detteParAssocie[Associe.BARKA])
        assertEquals(10_000, r.detteParAssocie[Associe.FODIE])
        assertEquals(6_000, r.dettePartagee)
        assertEquals(36_000, r.totalDettes)
        assertEquals(192_850 - 6_000 - 70_000 - 10_000, r.argentDisponible)
        assertEquals(-1_550, r.ecartCumule)
        assertEquals(1, r.joursCaisseComptee)
        assertEquals(1, r.depensesACorriger)
    }

    @Test
    fun `bilans jour semaine mois`() {
        val jour = compta.bilanJour(j2)
        assertEquals(66_000, jour.depenses)
        assertEquals(46_000, jour.depensesArgentPersonnel)
        assertEquals(30_000, jour.achatsViande)

        val semaine = compta.bilansParSemaine().single()
        assertEquals(j1, semaine.debut)
        assertEquals(32_000, semaine.achatsViande)

        val mois = compta.bilansParMois().single()
        assertEquals(YearMonth.of(2026, 9), mois.mois)
        assertEquals(50_000, mois.depensesMateriel)
        // 192 850 − (122 000 − 20 000) − 120 000 − 150 000
        assertEquals(-179_150, mois.resultatApresCharges)
        assertEquals(-129_150, mois.resultatHorsMateriel)
    }

    @Test
    fun `sauvegarde aller retour`() {
        val relu = Sauvegarde.importer(Sauvegarde.exporter(donnees))
        assertEquals(donnees, relu)
    }

    @Test
    fun `libelles du classeur`() {
        assertEquals(Categorie.PETITES_DEPENSES, Categorie.depuisLibelle("Petites dépenses / non identifiée"))
        assertEquals(Categorie.ENTRETIEN, Categorie.depuisLibelle("Produit d'entretiens"))
        assertEquals(SourcePaiement.FODIE, SourcePaiement.depuisLibelle("fodié"))
    }

    @Test
    fun montants() {
        assertEquals(18_000, lireMontant("18000F"))
        assertEquals(12_500, lireMontant("12 500"))
        assertNull(lireMontant(""))
        assertEquals("12 500 F", 12_500L.enFcfa())
        assertEquals("−1 550 F", (-1_550L).enFcfa())
    }
}

class ExportTest {
    @Test
    fun `csv avec separateur point-virgule`() {
        val d = Donnees(
            depenses = listOf(
                Depense(date = LocalDate.of(2026, 9, 1), article = "Sel; fin", montant = 500, payeAvec = SourcePaiement.CAISSE, categorie = Categorie.ACHATS_ALIMENTAIRES),
            ),
        )
        val lignes = com.fasoresto.core.io.Export.depensesCsv(d).removePrefix("﻿").trimEnd().lines()
        assertEquals("Date;Article;Quantité;Montant (F);Payé avec;Catégorie;Fournisseur;Remarque", lignes[0])
        assertEquals("2026-09-01;\"Sel; fin\";;500;Caisse;Achats alimentaires;;", lignes[1])
    }
}
