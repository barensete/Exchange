package com.fasoresto.core.modele

import java.time.LocalDate

/** Montants en francs CFA, toujours entiers. */
typealias Fcfa = Long

/** D'où vient l'argent d'une dépense (colonne « Payé avec » du classeur). */
enum class SourcePaiement(val libelle: String, val estPersonnel: Boolean) {
    CAISSE("Caisse", false),
    TRESORERIE("Trésorerie", false),
    BARKA("Barka", true),
    FODIE("Fodié", true),
    PARTAGE("Partagé", true);

    companion object {
        fun depuisLibelle(texte: String?): SourcePaiement? =
            entries.firstOrNull { it.libelle.equals(texte?.trim(), ignoreCase = true) }
    }
}

enum class Categorie(val libelle: String) {
    ACHATS_ALIMENTAIRES("Achats alimentaires"),
    EMBALLAGES("Emballages / consommables"),
    GAZ_CHARBON("Gaz & charbon"),
    MATERIEL("Matériel & équipement"),
    TRANSPORT("Transport / livraison"),
    CHARGES_DIVERSES("Charges diverses"),
    PERSONNEL("Personnel / Salaires"),
    PETITES_DEPENSES("Petites dépenses / non identifiées"),
    ENTRETIEN("Produit d'entretien");

    companion object {
        fun depuisLibelle(texte: String?): Categorie? {
            val t = texte?.trim()?.lowercase() ?: return null
            // Tolère les variantes du classeur (« non identifiée », « Produit d'entretiens »).
            return entries.firstOrNull { it.libelle.lowercase() == t }
                ?: entries.firstOrNull { t.startsWith(it.libelle.lowercase().dropLast(1)) }
        }
    }
}

enum class Service(val libelle: String) {
    MATIN("Matin"), MIDI("Midi"), SOIR("Soir"), PATE("Pâté"), AUTRE("Autre");

    companion object {
        fun depuisLibelle(texte: String?): Service? =
            entries.firstOrNull { it.libelle.equals(texte?.trim(), ignoreCase = true) }
    }
}

/** Associés qui avancent de l'argent personnel et se font rembourser. */
enum class Associe(val libelle: String, val source: SourcePaiement) {
    BARKA("Barka", SourcePaiement.BARKA),
    FODIE("Fodié", SourcePaiement.FODIE);

    companion object {
        fun depuisLibelle(texte: String?): Associe? =
            entries.firstOrNull { it.libelle.equals(texte?.trim(), ignoreCase = true) }
    }
}

/** Une ligne de l'onglet Recettes : la caisse d'une journée. */
data class Journee(
    val date: LocalDate,
    val matin: Fcfa = 0,
    val midi: Fcfa = 0,
    val soir: Fcfa = 0,
    val pate: Fcfa = 0,
    val autre: Fcfa = 0,
    /** Argent réellement compté le soir ; null si la caisse n'a pas été comptée. */
    val argentCompte: Fcfa? = null,
    val fondDebut: Fcfa? = null,
    val fondFin: Fcfa? = null,
    val remarque: String = "",
) {
    val totalAvantSorties: Fcfa get() = matin + midi + soir + pate + autre
}

data class Depense(
    val id: Long = 0,
    val date: LocalDate?,
    val article: String,
    val quantite: String = "",
    val montant: Fcfa?,
    val payeAvec: SourcePaiement?,
    val categorie: Categorie?,
    val fournisseur: String = "",
    val remarque: String = "",
) {
    /** Ligne orange du classeur : date, montant, « Payé avec » ou catégorie manquants. */
    val estIncomplete: Boolean
        get() = date == null || montant == null || payeAvec == null || categorie == null

    val estViande: Boolean
        get() = article.trim().let { it.startsWith("Viande", true) || it.startsWith("Foie", true) }
}

/** Vente à crédit. Le reste dû se calcule à partir des règlements. */
data class Impaye(
    val id: Long = 0,
    val date: LocalDate?,
    val service: Service?,
    val montant: Fcfa?,
    val client: String = "",
    val remarque: String = "",
    val reglements: List<Reglement> = emptyList(),
) {
    val montantRegle: Fcfa get() = reglements.sumOf { it.montant }
    val resteDu: Fcfa get() = ((montant ?: 0) - montantRegle).coerceAtLeast(0)
    val estSolde: Boolean get() = montant != null && resteDu == 0L
    val estIncomplet: Boolean get() = date == null || montant == null || service == null
}

data class Reglement(val id: Long = 0, val date: LocalDate, val montant: Fcfa)

/** Argent rendu par l'entreprise à un associé. */
data class Remboursement(
    val id: Long = 0,
    val date: LocalDate,
    val associe: Associe,
    val montant: Fcfa,
    val payeAvec: SourcePaiement,
    val remarque: String = "",
)

data class Parametres(
    val loyerMensuel: Fcfa = 120_000,
    val salairesMensuels: Fcfa = 150_000,
)

/** Toutes les données du restaurant, telles qu'elles sont exportées / importées. */
data class Donnees(
    val journees: List<Journee> = emptyList(),
    val depenses: List<Depense> = emptyList(),
    val impayes: List<Impaye> = emptyList(),
    val remboursements: List<Remboursement> = emptyList(),
    val parametres: Parametres = Parametres(),
)
