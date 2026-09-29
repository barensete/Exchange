package com.fasoresto.caisse

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import com.fasoresto.caisse.ui.FasoRestoUi
import com.fasoresto.caisse.ui.theme.FasoRestoTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            FasoRestoTheme {
                FasoRestoUi()
            }
        }
    }
}
