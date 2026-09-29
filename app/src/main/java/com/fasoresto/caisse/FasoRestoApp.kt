package com.fasoresto.caisse

import android.app.Application
import com.fasoresto.caisse.donnees.BaseDeDonnees
import com.fasoresto.caisse.donnees.Depot

class FasoRestoApp : Application() {
    val depot: Depot by lazy { Depot(BaseDeDonnees.ouvrir(this)) }
}
