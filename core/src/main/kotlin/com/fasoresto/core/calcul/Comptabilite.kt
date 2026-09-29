package com.fasoresto.core.calcul

import com.fasoresto.core.modele.Associe
import com.fasoresto.core.modele.Categorie
import com.fasoresto.core.modele.Depense
import com.fasoresto.core.modele.Donnees
import com.fasoresto.core.modele.Fcfa
import com.fasoresto.core.modele.Impaye
import com.fasoresto.core.modele.Journee
import com.fasoresto.core.modele.Service
import com.fasoresto.core.modele.SourcePaiement
import java.time.DayOfWeek
import java.time.LocalDate
import java.time.YearMonth
import java.time.temporal.TemporalAdjusters

/** Colonnes calculées d'une ligne de l'onglet Recettes. */
data class JourneeCalculee(
    val journee: Journee,
    val sortieDeCaisse: Fcfa,
    val resteEnCaisse: Fcfa,
    /** Argent compté − reste en caisse ; null si la caisse n'a pas été comptée. */
    val ecart: Fcfa?,
    val impayesDuJour: Fcfa,
) {
    val recettePlusImpayes: Fcfa get() = journee.totalAvantSorties + impayesDuJour
}

/** Onglet Résumé. */
data class Resume(
    val totalRecette: Fcfa,
    val impayesARecevoir: Fcfa,
    val totalDepenses: Fcfa,
    val depensesParSource: Map<SourcePaiement, Fcfa>,
    val detteParAssocie: Map<Associe, Fcfa>,
    val dettePartagee: Fcfa,
    val argentDisponible: Fcfa,
    val ecartCumule: Fcfa,
    val joursCaisseComptee: Int,
    val depensesACorriger: Int,
    val impayesACorriger: Int,
) {
    val totalDettes: Fcfa get() = detteParAssocie.values.sum() + dettePartagee
}

/** Onglet Par jour. */
data class BilanJour(
    val date: LocalDate,
    val recette: Fcfa,
    val depenses: Fcfa,
    val depensesArgentPersonnel: Fcfa,
    val achatsViande: Fcfa,
) {
    val resultat: Fcfa get() = recette - depenses
    val partViande: Double? get() = if (recette == 0L) null else achatsViande.toDouble() / recette
}

/** Tableau des semaines (lundi → dimanche). */
data class BilanSemaine(
    val debut: LocalDate,
    val recette: Fcfa,
    val depenses: Fcfa,
    val achatsViande: Fcfa,
) {
    val fin: LocalDate get() = debut.plusDays(6)
    val resultat: Fcfa get() = recette - depenses
    val partViande: Double? get() = if (recette == 0L) null else achatsViande.toDouble() / recette
}

/** Tableau des mois avec loyer et salaires. */
data class BilanMois(
    val mois: YearMonth,
    val recette: Fcfa,
    val depenses: Fcfa,
    val depensesMateriel: Fcfa,
    val versementsSalaires: Fcfa,
    val loyer: Fcfa,
    val salaires: Fcfa,
) {
    /** Recette − (dépenses sans les versements de salaire déjà saisis) − loyer − salaires. */
    val resultatApresCharges: Fcfa get() = recette - (depenses - versementsSalaires) - loyer - salaires
    val resultatHorsMateriel: Fcfa get() = resultatApresCharges + depensesMateriel
}

/**
 * Reproduit fidèlement les formules du classeur « Comptabilité Faso Resto ».
 * Aucune dépendance Android : testable sur n'importe quelle JVM.
 */
class Comptabilite(private val d: Donnees) {

    private val depensesValides = d.depenses.filter { it.montant != null }

    private fun depensesDu(date: LocalDate) = depensesValides.filter { it.date == date }

    private fun Iterable<Depense>.somme(): Fcfa = sumOf { it.montant ?: 0 }

    fun journee(j: Journee): JourneeCalculee {
        val sortie = depensesDu(j.date).filter { it.payeAvec == SourcePaiement.CAISSE }.somme()
        val reste = j.totalAvantSorties - sortie
        val impayes = d.impayes
            .filter { it.date == j.date && it.service != Service.AUTRE }
            .sumOf { it.montant ?: 0 }
        return JourneeCalculee(
            journee = j,
            sortieDeCaisse = sortie,
            resteEnCaisse = reste,
            ecart = j.argentCompte?.let { it - reste },
            impayesDuJour = impayes,
        )
    }

    fun journees(): List<JourneeCalculee> = d.journees.sortedBy { it.date }.map(::journee)

    fun resume(): Resume {
        val parSource = SourcePaiement.entries.associateWith { s ->
            depensesValides.filter { it.payeAvec == s }.somme()
        }
        val rembourse = Associe.entries.associateWith { a ->
            d.remboursements.filter { it.associe == a }.sumOf { it.montant }
        }
        val totalRecette = d.journees.sumOf { it.totalAvantSorties }
        val calculees = journees()
        return Resume(
            totalRecette = totalRecette,
            impayesARecevoir = d.impayes.sumOf { it.resteDu },
            totalDepenses = depensesValides.somme(),
            depensesParSource = parSource,
            detteParAssocie = Associe.entries.associateWith { a ->
                parSource.getValue(a.source) - rembourse.getValue(a)
            },
            dettePartagee = parSource.getValue(SourcePaiement.PARTAGE),
            argentDisponible = totalRecette -
                parSource.getValue(SourcePaiement.CAISSE) -
                parSource.getValue(SourcePaiement.TRESORERIE) -
                d.remboursements.sumOf { it.montant },
            ecartCumule = calculees.sumOf { it.ecart ?: 0 },
            joursCaisseComptee = d.journees.count { it.argentCompte != null },
            depensesACorriger = d.depenses.count { it.estIncomplete },
            impayesACorriger = d.impayes.count(Impaye::estIncomplet),
        )
    }

    fun bilanJour(date: LocalDate): BilanJour {
        val deps = depensesDu(date)
        return BilanJour(
            date = date,
            recette = d.journees.filter { it.date == date }.sumOf { it.totalAvantSorties },
            depenses = deps.somme(),
            depensesArgentPersonnel = deps.filter { it.payeAvec?.estPersonnel != false }.somme(),
            achatsViande = deps.filter { it.estViande }.somme(),
        )
    }

    /** Un bilan pour chaque date qui a une recette ou une dépense, du plus récent au plus ancien. */
    fun bilansParJour(): List<BilanJour> =
        (d.journees.map { it.date } + depensesValides.mapNotNull { it.date })
            .distinct().sortedDescending().map(::bilanJour)

    fun bilansParSemaine(): List<BilanSemaine> =
        toutesLesDates().map { it.with(TemporalAdjusters.previousOrSame(DayOfWeek.MONDAY)) }
            .distinct().sortedDescending().map { lundi ->
                val dims = lundi.plusDays(6)
                val deps = depensesValides.filter { it.date != null && it.date in lundi..dims }
                BilanSemaine(
                    debut = lundi,
                    recette = d.journees.filter { it.date in lundi..dims }.sumOf { it.totalAvantSorties },
                    depenses = deps.somme(),
                    achatsViande = deps.filter { it.estViande }.somme(),
                )
            }

    fun bilansParMois(): List<BilanMois> =
        toutesLesDates().map(YearMonth::from).distinct().sortedDescending().map { mois ->
            val deps = depensesValides.filter { it.date != null && YearMonth.from(it.date) == mois }
            val recette = d.journees.filter { YearMonth.from(it.date) == mois }.sumOf { it.totalAvantSorties }
            // Comme dans le classeur : loyer et salaires seulement pour les mois qui ont des recettes.
            val actif = recette != 0L
            BilanMois(
                mois = mois,
                recette = recette,
                depenses = deps.somme(),
                depensesMateriel = deps.filter { it.categorie == Categorie.MATERIEL }.somme(),
                versementsSalaires = deps.filter { it.categorie == Categorie.PERSONNEL }.somme(),
                loyer = if (actif) d.parametres.loyerMensuel else 0,
                salaires = if (actif) d.parametres.salairesMensuels else 0,
            )
        }

    private fun toutesLesDates(): List<LocalDate> =
        d.journees.map { it.date } + depensesValides.mapNotNull { it.date }
}
