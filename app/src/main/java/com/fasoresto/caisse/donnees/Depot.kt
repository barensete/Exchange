package com.fasoresto.caisse.donnees

import androidx.room.withTransaction
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
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.combine

/** Seul point d'accès aux données : convertit entre Room et les modèles de `:core`. */
class Depot(private val db: BaseDeDonnees) {
    private val dao = db.dao()

    val donnees: Flow<Donnees> = combine(
        dao.journees(), dao.depenses(), dao.impayes(), dao.reglements(),
        combine(dao.remboursements(), dao.parametres(), ::Pair),
    ) { journees, depenses, impayes, reglements, (remboursements, parametres) ->
        val parImpaye = reglements.groupBy { it.impayeId }
        Donnees(
            journees = journees.map { it.versModele() },
            depenses = depenses.map { it.versModele() },
            impayes = impayes.map { it.versModele(parImpaye[it.id].orEmpty()) },
            remboursements = remboursements.map { it.versModele() },
            parametres = parametres?.let { Parametres(it.loyerMensuel, it.salairesMensuels) } ?: Parametres(),
        )
    }

    suspend fun enregistrer(j: Journee) = dao.enregistrerJournee(j.versEntite())
    suspend fun supprimer(j: Journee) = dao.supprimerJournee(j.date)

    suspend fun enregistrer(d: Depense) = dao.enregistrerDepense(d.versEntite())
    suspend fun supprimer(d: Depense) = dao.supprimerDepense(d.id)

    suspend fun enregistrer(i: Impaye) = dao.enregistrerImpaye(i.versEntite())
    suspend fun supprimer(i: Impaye) = dao.supprimerImpaye(i.id)
    suspend fun ajouterReglement(impaye: Impaye, r: Reglement) =
        dao.ajouterReglement(ReglementEntite(impayeId = impaye.id, date = r.date, montant = r.montant))
    suspend fun supprimer(r: Reglement) = dao.supprimerReglement(r.id)

    suspend fun enregistrer(r: Remboursement) = dao.enregistrerRemboursement(r.versEntite())
    suspend fun supprimer(r: Remboursement) = dao.supprimerRemboursement(r.id)

    suspend fun enregistrer(p: Parametres) = dao.enregistrerParametres(ParametresEntite(1, p.loyerMensuel, p.salairesMensuels))

    /** Remplace toutes les données (import d'une sauvegarde ou du classeur Excel converti). */
    suspend fun remplacerTout(d: Donnees) = db.withTransaction {
        dao.viderReglements()
        dao.viderImpayes()
        dao.viderDepenses()
        dao.viderJournees()
        dao.viderRemboursements()
        enregistrer(d.parametres)
        d.journees.forEach { enregistrer(it) }
        d.depenses.forEach { enregistrer(it.copy(id = 0)) }
        d.remboursements.forEach { enregistrer(it.copy(id = 0)) }
        d.impayes.forEach { i ->
            val id = dao.enregistrerImpaye(i.copy(id = 0).versEntite())
            i.reglements.forEach { r -> dao.ajouterReglement(ReglementEntite(impayeId = id, date = r.date, montant = r.montant)) }
        }
    }
}

private inline fun <reified E : Enum<E>> enumOuNull(nom: String?): E? =
    nom?.let { n -> enumValues<E>().firstOrNull { it.name == n } }

private fun JourneeEntite.versModele() =
    Journee(date, matin, midi, soir, pate, autre, argentCompte, fondDebut, fondFin, remarque)

private fun Journee.versEntite() =
    JourneeEntite(date, matin, midi, soir, pate, autre, argentCompte, fondDebut, fondFin, remarque)

private fun DepenseEntite.versModele() = Depense(
    id, date, article, quantite, montant,
    enumOuNull<SourcePaiement>(payeAvec), enumOuNull<Categorie>(categorie), fournisseur, remarque,
)

private fun Depense.versEntite() = DepenseEntite(
    id, date, article, quantite, montant, payeAvec?.name, categorie?.name, fournisseur, remarque,
)

private fun ImpayeEntite.versModele(reglements: List<ReglementEntite>) = Impaye(
    id, date, enumOuNull<Service>(service), montant, client, remarque,
    reglements.map { Reglement(it.id, it.date, it.montant) },
)

private fun Impaye.versEntite() = ImpayeEntite(id, date, service?.name, montant, client, remarque)

private fun RemboursementEntite.versModele() = Remboursement(
    id, date, enumOuNull<Associe>(associe) ?: Associe.BARKA, montant,
    enumOuNull<SourcePaiement>(payeAvec) ?: SourcePaiement.TRESORERIE, remarque,
)

private fun Remboursement.versEntite() =
    RemboursementEntite(id, date, associe.name, montant, payeAvec.name, remarque)
