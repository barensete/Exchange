package com.fasoresto.core.io

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

/**
 * Format de sauvegarde (JSON). C'est aussi le format produit par
 * `outils/excel_vers_json.py` pour reprendre l'historique du classeur Excel.
 * Les listes utilisent les libellés du classeur (« Caisse », « Achats alimentaires »…).
 */
object Sauvegarde {
    const val VERSION = 1

    fun exporter(d: Donnees): String = Json.ecrire(
        mapOf(
            "format" to "fasoresto",
            "version" to VERSION,
            "parametres" to mapOf(
                "loyerMensuel" to d.parametres.loyerMensuel,
                "salairesMensuels" to d.parametres.salairesMensuels,
            ),
            "journees" to d.journees.map {
                mapOf(
                    "date" to it.date.toString(), "matin" to it.matin, "midi" to it.midi,
                    "soir" to it.soir, "pate" to it.pate, "autre" to it.autre,
                    "argentCompte" to it.argentCompte, "fondDebut" to it.fondDebut,
                    "fondFin" to it.fondFin, "remarque" to it.remarque,
                )
            },
            "depenses" to d.depenses.map {
                mapOf(
                    "date" to it.date?.toString(), "article" to it.article, "quantite" to it.quantite,
                    "montant" to it.montant, "payeAvec" to it.payeAvec?.libelle,
                    "categorie" to it.categorie?.libelle, "fournisseur" to it.fournisseur,
                    "remarque" to it.remarque,
                )
            },
            "impayes" to d.impayes.map {
                mapOf(
                    "date" to it.date?.toString(), "service" to it.service?.libelle,
                    "montant" to it.montant, "client" to it.client, "remarque" to it.remarque,
                    "reglements" to it.reglements.map { r ->
                        mapOf("date" to r.date.toString(), "montant" to r.montant)
                    },
                )
            },
            "remboursements" to d.remboursements.map {
                mapOf(
                    "date" to it.date.toString(), "associe" to it.associe.libelle,
                    "montant" to it.montant, "payeAvec" to it.payeAvec.libelle,
                    "remarque" to it.remarque,
                )
            },
        ),
    )

    fun importer(texte: String): Donnees {
        val racine = Json.lire(texte) as? Map<*, *> ?: error("Le fichier n'est pas une sauvegarde FasoResto")
        require(racine["format"] == "fasoresto") { "Le fichier n'est pas une sauvegarde FasoResto" }
        val p = racine["parametres"] as? Map<*, *> ?: emptyMap<String, Any?>()
        val defaut = Parametres()
        return Donnees(
            parametres = Parametres(
                loyerMensuel = p.long("loyerMensuel") ?: defaut.loyerMensuel,
                salairesMensuels = p.long("salairesMensuels") ?: defaut.salairesMensuels,
            ),
            journees = racine.liste("journees").map {
                Journee(
                    date = it.date("date") ?: error("Journée sans date"),
                    matin = it.long("matin") ?: 0, midi = it.long("midi") ?: 0,
                    soir = it.long("soir") ?: 0, pate = it.long("pate") ?: 0,
                    autre = it.long("autre") ?: 0, argentCompte = it.long("argentCompte"),
                    fondDebut = it.long("fondDebut"), fondFin = it.long("fondFin"),
                    remarque = it.texte("remarque"),
                )
            },
            depenses = racine.liste("depenses").map {
                Depense(
                    date = it.date("date"), article = it.texte("article"), quantite = it.texte("quantite"),
                    montant = it.long("montant"),
                    payeAvec = SourcePaiement.depuisLibelle(it["payeAvec"] as? String),
                    categorie = Categorie.depuisLibelle(it["categorie"] as? String),
                    fournisseur = it.texte("fournisseur"), remarque = it.texte("remarque"),
                )
            },
            impayes = racine.liste("impayes").map {
                Impaye(
                    date = it.date("date"), service = Service.depuisLibelle(it["service"] as? String),
                    montant = it.long("montant"), client = it.texte("client"), remarque = it.texte("remarque"),
                    reglements = it.liste("reglements").map { r ->
                        Reglement(date = r.date("date") ?: error("Règlement sans date"), montant = r.long("montant") ?: 0)
                    },
                )
            },
            remboursements = racine.liste("remboursements").map {
                Remboursement(
                    date = it.date("date") ?: error("Remboursement sans date"),
                    associe = Associe.depuisLibelle(it["associe"] as? String) ?: error("Associé inconnu : ${it["associe"]}"),
                    montant = it.long("montant") ?: 0,
                    payeAvec = SourcePaiement.depuisLibelle(it["payeAvec"] as? String) ?: SourcePaiement.TRESORERIE,
                    remarque = it.texte("remarque"),
                )
            },
        )
    }

    private fun Map<*, *>.liste(cle: String): List<Map<*, *>> =
        (this[cle] as? List<*>)?.filterIsInstance<Map<*, *>>() ?: emptyList()

    private fun Map<*, *>.long(cle: String): Long? = when (val v = this[cle]) {
        is Long -> v
        is Double -> Math.round(v)
        is String -> v.filter { it.isDigit() || it == '-' }.toLongOrNull()
        else -> null
    }

    private fun Map<*, *>.texte(cle: String): String = (this[cle] as? String) ?: this[cle]?.toString().orEmpty()

    private fun Map<*, *>.date(cle: String): LocalDate? = (this[cle] as? String)?.let { LocalDate.parse(it.take(10)) }
}
