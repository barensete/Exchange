package com.fasoresto.caisse.ui

import android.app.Application
import android.net.Uri
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.fasoresto.caisse.FasoRestoApp
import com.fasoresto.core.calcul.Comptabilite
import com.fasoresto.core.io.Export
import com.fasoresto.core.io.Sauvegarde
import com.fasoresto.core.modele.Depense
import com.fasoresto.core.modele.Donnees
import com.fasoresto.core.modele.Impaye
import com.fasoresto.core.modele.Journee
import com.fasoresto.core.modele.Parametres
import com.fasoresto.core.modele.Reglement
import com.fasoresto.core.modele.Remboursement
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/** État affiché : les données brutes et leur comptabilité calculée. */
data class Etat(val donnees: Donnees = Donnees(), val compta: Comptabilite = Comptabilite(Donnees()), val charge: Boolean = false)

class FasoViewModel(app: Application) : AndroidViewModel(app) {
    private val depot = (app as FasoRestoApp).depot

    val etat: StateFlow<Etat> = depot.donnees
        .map { Etat(it, Comptabilite(it), charge = true) }
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), Etat())

    private val _message = MutableStateFlow<String?>(null)
    /** Message court à afficher (snackbar) après une action. */
    val message: StateFlow<String?> = _message.asStateFlow()
    fun messageLu() { _message.value = null }

    private fun lancer(bloc: suspend () -> Unit) = viewModelScope.launch {
        try {
            bloc()
        } catch (e: Exception) {
            _message.value = "Erreur : ${e.message}"
        }
    }

    fun enregistrer(j: Journee) = lancer { depot.enregistrer(j) }
    fun supprimer(j: Journee) = lancer { depot.supprimer(j) }
    fun enregistrer(d: Depense) = lancer { depot.enregistrer(d) }
    fun supprimer(d: Depense) = lancer { depot.supprimer(d) }
    fun enregistrer(i: Impaye) = lancer { depot.enregistrer(i) }
    fun supprimer(i: Impaye) = lancer { depot.supprimer(i) }
    fun ajouterReglement(i: Impaye, r: Reglement) = lancer { depot.ajouterReglement(i, r) }
    fun supprimer(r: Reglement) = lancer { depot.supprimer(r) }
    fun enregistrer(r: Remboursement) = lancer { depot.enregistrer(r) }
    fun supprimer(r: Remboursement) = lancer { depot.supprimer(r) }
    fun enregistrer(p: Parametres) = lancer { depot.enregistrer(p) }

    private val resolver get() = getApplication<Application>().contentResolver

    private suspend fun ecrire(uri: Uri, texte: String) = withContext(Dispatchers.IO) {
        resolver.openOutputStream(uri, "wt")?.use { it.write(texte.toByteArray(Charsets.UTF_8)) }
            ?: error("Impossible d'écrire le fichier")
    }

    fun exporterSauvegarde(uri: Uri) = lancer {
        ecrire(uri, Sauvegarde.exporter(etat.value.donnees))
        _message.value = "Sauvegarde enregistrée"
    }

    fun exporterCsv(uri: Uri) = lancer {
        ecrire(uri, Export.depensesCsv(etat.value.donnees))
        _message.value = "Dépenses exportées"
    }

    fun importerSauvegarde(uri: Uri) = lancer {
        val texte = withContext(Dispatchers.IO) {
            resolver.openInputStream(uri)?.use { it.readBytes().toString(Charsets.UTF_8) }
                ?: error("Impossible de lire le fichier")
        }
        val d = Sauvegarde.importer(texte)
        depot.remplacerTout(d)
        _message.value = "${d.journees.size} journées et ${d.depenses.size} dépenses importées"
    }
}
