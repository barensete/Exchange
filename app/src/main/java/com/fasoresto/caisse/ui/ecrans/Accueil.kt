package com.fasoresto.caisse.ui.ecrans

import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.material3.Button
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import com.fasoresto.caisse.ui.Ecran
import com.fasoresto.caisse.ui.EcranOnglet
import com.fasoresto.caisse.ui.Etat
import com.fasoresto.caisse.ui.LigneMontant
import com.fasoresto.caisse.ui.Navigation
import com.fasoresto.caisse.ui.Onglet
import com.fasoresto.caisse.ui.Section
import com.fasoresto.caisse.ui.theme.Orange
import com.fasoresto.core.calcul.enFcfa
import com.fasoresto.core.modele.Associe
import com.fasoresto.core.modele.SourcePaiement
import java.time.LocalDate

/** Équivalent de l'onglet « Résumé » du classeur, plus la caisse du jour. */
@Composable
fun EcranAccueil(etat: Etat, nav: Navigation, modifier: Modifier) {
    val r = etat.compta.resume()
    val aujourdhui = LocalDate.now()
    val jour = etat.donnees.journees.firstOrNull { it.date == aujourdhui }?.let(etat.compta::journee)

    EcranOnglet("FasoResto", modifier) {
        item {
            Section("Aujourd'hui") {
                if (jour == null) {
                    Text("La caisse du jour n'est pas encore saisie.")
                } else {
                    LigneMontant("Recette (avant sorties)", jour.journee.totalAvantSorties)
                    LigneMontant("Sortie de caisse", jour.sortieDeCaisse)
                    LigneMontant("Reste en caisse", jour.resteEnCaisse, fort = true)
                    jour.ecart?.let { LigneMontant("Écart (compté − reste)", it, couleur = couleurEcart(it)) }
                }
                Button(onClick = { nav.ouvrir(Ecran.EditionJournee(aujourdhui)) }, modifier = Modifier.fillMaxWidth()) {
                    Text(if (jour == null) "Saisir la caisse du jour" else "Modifier la caisse du jour")
                }
            }
        }
        item {
            Section("Recettes") {
                LigneMontant("Total recette (avant sorties)", r.totalRecette, fort = true)
                LigneMontant("Impayés clients à recevoir", r.impayesARecevoir, detail = "Vendu à crédit, pas encore reçu")
            }
        }
        item {
            Section("Dépenses") {
                LigneMontant("Total dépenses", r.totalDepenses, fort = true)
                SourcePaiement.entries.forEach { s ->
                    LigneMontant(
                        when (s) {
                            SourcePaiement.CAISSE -> "   payées par la Caisse"
                            SourcePaiement.TRESORERIE -> "   payées par la Trésorerie"
                            SourcePaiement.PARTAGE -> "   avancées à deux (Partagé)"
                            else -> "   avancées par ${s.libelle}"
                        },
                        r.depensesParSource[s],
                    )
                }
            }
        }
        item {
            Section("Dettes de l'entreprise") {
                Associe.entries.forEach { a ->
                    LigneMontant("Dette envers ${a.libelle}", r.detteParAssocie[a], detail = "Avancé − remboursé")
                }
                LigneMontant("Dette partagée (Barka + Fodié)", r.dettePartagee)
                HorizontalDivider()
                LigneMontant("Total des dettes", r.totalDettes, fort = true)
            }
        }
        item {
            Section("Argent disponible") {
                LigneMontant("Argent réellement disponible", r.argentDisponible, fort = true)
                Text(
                    "Recette − dépenses Caisse − dépenses Trésorerie − remboursements versés. " +
                        "Les avances personnelles sont des dettes, non retranchées ici.",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }
        item {
            Section("Contrôles") {
                LigneMontant("Écart de caisse cumulé", r.ecartCumule, couleur = couleurEcart(r.ecartCumule))
                Text("Jours de caisse comptée : ${r.joursCaisseComptee} / ${etat.donnees.journees.size}")
                if (r.depensesACorriger > 0) {
                    Text("${r.depensesACorriger} dépense(s) incomplète(s) à corriger", color = Orange)
                }
                if (r.impayesACorriger > 0) {
                    Text("${r.impayesACorriger} impayé(s) incomplet(s) à corriger", color = Orange)
                }
                Button(onClick = { nav.onglet(Onglet.PLUS); nav.ouvrir(Ecran.Bilans) }, modifier = Modifier.fillMaxWidth()) {
                    Text("Voir les bilans (jour, semaine, mois)")
                }
            }
        }
        item {
            Text(
                "Dernière journée saisie : " +
                    (etat.donnees.journees.maxByOrNull { it.date }?.let { "${it.date} — ${it.totalAvantSorties.enFcfa()}" } ?: "aucune"),
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}

@Composable
fun couleurEcart(ecart: Long) =
    if (ecart == 0L) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.error
