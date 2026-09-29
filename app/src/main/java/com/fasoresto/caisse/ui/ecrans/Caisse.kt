package com.fasoresto.caisse.ui.ecrans

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Card
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.fasoresto.caisse.ui.BoutonSupprimer
import com.fasoresto.caisse.ui.ChampDate
import com.fasoresto.caisse.ui.ChampMontant
import com.fasoresto.caisse.ui.ChampTexte
import com.fasoresto.caisse.ui.ConfirmerSuppression
import com.fasoresto.caisse.ui.Ecran
import com.fasoresto.caisse.ui.EcranAvecBarre
import com.fasoresto.caisse.ui.EcranOnglet
import com.fasoresto.caisse.ui.Etat
import com.fasoresto.caisse.ui.FasoViewModel
import com.fasoresto.caisse.ui.Formulaire
import com.fasoresto.caisse.ui.LigneMontant
import com.fasoresto.caisse.ui.Navigation
import com.fasoresto.caisse.ui.Section
import com.fasoresto.caisse.ui.Vide
import com.fasoresto.core.calcul.Comptabilite
import com.fasoresto.core.calcul.enFcfa
import com.fasoresto.core.calcul.enTexte
import com.fasoresto.core.modele.Journee
import com.fasoresto.core.modele.SourcePaiement
import java.time.LocalDate

/** Onglet « Recettes » : une carte par journée, la plus récente en haut. */
@Composable
fun EcranCaisse(etat: Etat, nav: Navigation, modifier: Modifier) {
    val jours = etat.compta.journees().reversed()
    EcranOnglet("Caisse du jour", modifier, ajouter = { nav.ouvrir(Ecran.EditionJournee(null)) }) {
        if (jours.isEmpty()) item { Vide("Aucune journée saisie. Appuyez sur « Ajouter ».") }
        items(jours.size) { i ->
            val j = jours[i]
            Card(Modifier.fillMaxWidth().clickable { nav.ouvrir(Ecran.EditionJournee(j.journee.date)) }) {
                Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    Row {
                        Text(
                            j.journee.date.enTexte(), Modifier.weight(1f),
                            style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold,
                        )
                        Text(j.journee.totalAvantSorties.enFcfa(), style = MaterialTheme.typography.titleMedium)
                    }
                    Text(
                        "Sortie ${j.sortieDeCaisse.enFcfa()} · Reste ${j.resteEnCaisse.enFcfa()}" +
                            (if (j.impayesDuJour > 0) " · Crédit ${j.impayesDuJour.enFcfa()}" else ""),
                        style = MaterialTheme.typography.bodyMedium,
                    )
                    j.ecart?.let {
                        Text(
                            if (it == 0L) "Caisse juste ✓" else "Écart ${it.enFcfa()}",
                            color = couleurEcart(it),
                            style = MaterialTheme.typography.bodyMedium,
                        )
                    }
                }
            }
        }
    }
}

/** Saisie d'une journée : services, argent compté, fond de caisse. Tout le reste se calcule. */
@Composable
fun EcranEditionJournee(etat: Etat, vm: FasoViewModel, nav: Navigation, date: LocalDate?, modifier: Modifier) {
    val existante = date?.let { d -> etat.donnees.journees.firstOrNull { it.date == d } }
    var j by remember(existante, date) { mutableStateOf(existante ?: Journee(date ?: LocalDate.now())) }
    var confirmer by remember { mutableStateOf(false) }
    // Calcul en direct avec les dépenses et impayés déjà enregistrés pour cette date.
    val calcul = Comptabilite(etat.donnees).journee(j)
    val dejaPrise = existante == null && etat.donnees.journees.any { it.date == j.date }

    EcranAvecBarre(
        "Caisse du ${j.date.enTexte()}", nav, modifier,
        actions = { if (existante != null) BoutonSupprimer { confirmer = true } },
    ) { marges ->
        Formulaire(marges, peutEnregistrer = !dejaPrise, enregistrer = { vm.enregistrer(j); nav.retour() }) {
            if (existante == null) {
                ChampDate("Date", j.date, { j = j.copy(date = it) })
                if (dejaPrise) Text("Cette date est déjà saisie : ouvrez-la depuis la liste.", color = MaterialTheme.colorScheme.error)
            }
            Text("Recette AVANT sorties, par service", style = MaterialTheme.typography.titleSmall)
            ChampMontant("Matin", j.matin.takeIf { it != 0L }, { j = j.copy(matin = it ?: 0) })
            ChampMontant("Midi", j.midi.takeIf { it != 0L }, { j = j.copy(midi = it ?: 0) })
            ChampMontant("Soir", j.soir.takeIf { it != 0L }, { j = j.copy(soir = it ?: 0) })
            ChampMontant("Pâté", j.pate.takeIf { it != 0L }, { j = j.copy(pate = it ?: 0) })
            ChampMontant("Non détaillée / autre", j.autre.takeIf { it != 0L }, { j = j.copy(autre = it ?: 0) })

            Section("Calcul automatique") {
                LigneMontant("Total avant sorties", j.totalAvantSorties, fort = true)
                LigneMontant("Sortie de caisse", calcul.sortieDeCaisse, detail = "Achats du jour payés avec « Caisse »")
                LigneMontant("Reste en caisse", calcul.resteEnCaisse, fort = true)
                LigneMontant("Impayés du jour (à crédit)", calcul.impayesDuJour)
                LigneMontant("Recette + impayés", calcul.recettePlusImpayes)
                HorizontalDivider()
                val achats = etat.donnees.depenses.filter { it.date == j.date && it.payeAvec == SourcePaiement.CAISSE }
                achats.forEach { LigneMontant("• ${it.article}", it.montant) }
                OutlinedButton(
                    onClick = {
                        // Enregistre la journée d'abord pour ne pas perdre la saisie en cours.
                        vm.enregistrer(j)
                        nav.retour()
                        nav.ouvrir(Ecran.EditionJournee(j.date))
                        nav.ouvrir(Ecran.EditionDepense(null, j.date, SourcePaiement.CAISSE))
                    },
                    enabled = !dejaPrise,
                    modifier = Modifier.fillMaxWidth(),
                ) { Text("Ajouter un achat payé par la caisse") }
            }

            Text("Fin de journée", style = MaterialTheme.typography.titleSmall)
            ChampMontant("Argent compté (fin de journée)", j.argentCompte, { j = j.copy(argentCompte = it) })
            calcul.ecart?.let {
                LigneMontant("Écart (compté − reste)", it, fort = true, couleur = couleurEcart(it))
            }
            ChampMontant("Fond de caisse début", j.fondDebut, { j = j.copy(fondDebut = it) })
            ChampMontant("Fond de caisse fin", j.fondFin, { j = j.copy(fondFin = it) })
            ChampTexte("Remarque", j.remarque, { j = j.copy(remarque = it) }, lignes = 3)
        }
    }

    if (confirmer && existante != null) {
        ConfirmerSuppression(
            "La journée du ${existante.date.enTexte()}",
            onConfirmer = { vm.supprimer(existante); confirmer = false; nav.retour() },
            onAnnuler = { confirmer = false },
        )
    }
}
