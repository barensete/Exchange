package com.fasoresto.caisse.ui

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.MoreHoriz
import androidx.compose.material.icons.filled.PointOfSale
import androidx.compose.material.icons.automirrored.filled.ReceiptLong
import androidx.compose.material.icons.filled.PersonSearch
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.fasoresto.caisse.ui.ecrans.EcranAccueil
import com.fasoresto.caisse.ui.ecrans.EcranBilans
import com.fasoresto.caisse.ui.ecrans.EcranCaisse
import com.fasoresto.caisse.ui.ecrans.EcranDepenses
import com.fasoresto.caisse.ui.ecrans.EcranEditionDepense
import com.fasoresto.caisse.ui.ecrans.EcranEditionImpaye
import com.fasoresto.caisse.ui.ecrans.EcranEditionJournee
import com.fasoresto.caisse.ui.ecrans.EcranEditionRemboursement
import com.fasoresto.caisse.ui.ecrans.EcranImpayes
import com.fasoresto.caisse.ui.ecrans.EcranParametres
import com.fasoresto.caisse.ui.ecrans.EcranPlus
import com.fasoresto.caisse.ui.ecrans.EcranRemboursements
import com.fasoresto.core.modele.SourcePaiement
import java.time.LocalDate

enum class Onglet(val titre: String, val icone: ImageVector) {
    ACCUEIL("Résumé", Icons.Filled.Home),
    CAISSE("Caisse", Icons.Filled.PointOfSale),
    DEPENSES("Dépenses", Icons.AutoMirrored.Filled.ReceiptLong),
    IMPAYES("Impayés", Icons.Filled.PersonSearch),
    PLUS("Plus", Icons.Filled.MoreHoriz),
}

/** Écrans ouverts par-dessus les onglets. */
sealed interface Ecran {
    data class EditionJournee(val date: LocalDate?) : Ecran
    data class EditionDepense(val id: Long?, val date: LocalDate? = null, val source: SourcePaiement? = null) : Ecran
    data class EditionImpaye(val id: Long?) : Ecran
    data object Remboursements : Ecran
    data class EditionRemboursement(val id: Long?) : Ecran
    data object Bilans : Ecran
    data object Parametres : Ecran
}

/** Actions de navigation passées aux écrans. */
class Navigation(val ouvrir: (Ecran) -> Unit, val retour: () -> Unit, val onglet: (Onglet) -> Unit)

@Composable
fun FasoRestoUi(vm: FasoViewModel = viewModel()) {
    val etat by vm.etat.collectAsStateWithLifecycle()
    val message by vm.message.collectAsStateWithLifecycle()
    var onglet by remember { mutableStateOf(Onglet.ACCUEIL) }
    var pile by remember { mutableStateOf(listOf<Ecran>()) }
    val snackbar = remember { SnackbarHostState() }

    LaunchedEffect(message) {
        message?.let {
            snackbar.showSnackbar(it)
            vm.messageLu()
        }
    }

    val nav = Navigation(
        ouvrir = { pile = pile + it },
        retour = { pile = pile.dropLast(1) },
        onglet = { pile = emptyList(); onglet = it },
    )
    BackHandler(enabled = pile.isNotEmpty()) { nav.retour() }
    BackHandler(enabled = pile.isEmpty() && onglet != Onglet.ACCUEIL) { onglet = Onglet.ACCUEIL }

    val ecran = pile.lastOrNull()
    if (ecran != null) {
        // Chaque écran secondaire a son propre Scaffold avec barre de retour.
        val m = Modifier
        when (ecran) {
            is Ecran.EditionJournee -> EcranEditionJournee(etat, vm, nav, ecran.date, m)
            is Ecran.EditionDepense -> EcranEditionDepense(etat, vm, nav, ecran, m)
            is Ecran.EditionImpaye -> EcranEditionImpaye(etat, vm, nav, ecran.id, m)
            Ecran.Remboursements -> EcranRemboursements(etat, nav, m)
            is Ecran.EditionRemboursement -> EcranEditionRemboursement(etat, vm, nav, ecran.id, m)
            Ecran.Bilans -> EcranBilans(etat, nav, m)
            Ecran.Parametres -> EcranParametres(etat, vm, nav, m)
        }
        return
    }

    Scaffold(
        snackbarHost = { SnackbarHost(snackbar) },
        bottomBar = {
            NavigationBar {
                Onglet.entries.forEach { o ->
                    NavigationBarItem(
                        selected = o == onglet,
                        onClick = { onglet = o },
                        icon = { Icon(o.icone, null) },
                        label = { Text(o.titre) },
                    )
                }
            }
        },
    ) { marges ->
        val m = Modifier.padding(marges)
        when (onglet) {
            Onglet.ACCUEIL -> EcranAccueil(etat, nav, m)
            Onglet.CAISSE -> EcranCaisse(etat, nav, m)
            Onglet.DEPENSES -> EcranDepenses(etat, nav, m)
            Onglet.IMPAYES -> EcranImpayes(etat, nav, m)
            Onglet.PLUS -> EcranPlus(vm, nav, m)
        }
    }
}
