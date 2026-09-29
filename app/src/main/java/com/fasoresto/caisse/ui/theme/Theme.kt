package com.fasoresto.caisse.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

// Couleurs du drapeau burkinabè.
val Vert = Color(0xFF009E49)
val Rouge = Color(0xFFEF2B2D)
val Jaune = Color(0xFFFCD116)
val Orange = Color(0xFFE67E22)

private val Clair = lightColorScheme(
    primary = Vert,
    onPrimary = Color.White,
    primaryContainer = Color(0xFFC8F2D6),
    onPrimaryContainer = Color(0xFF00210C),
    secondary = Color(0xFF8A6D00),
    secondaryContainer = Color(0xFFFFF1B8),
    error = Rouge,
)

private val Sombre = darkColorScheme(
    primary = Color(0xFF6FDC95),
    onPrimary = Color(0xFF003918),
    primaryContainer = Color(0xFF005226),
    onPrimaryContainer = Color(0xFFC8F2D6),
    secondary = Jaune,
    error = Color(0xFFFF8A80),
)

@Composable
fun FasoRestoTheme(content: @Composable () -> Unit) {
    MaterialTheme(colorScheme = if (isSystemInDarkTheme()) Sombre else Clair, content = content)
}
