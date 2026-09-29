package com.fasoresto.core.calcul

import com.fasoresto.core.modele.Fcfa
import java.time.LocalDate
import java.time.format.DateTimeFormatter

private val FORMAT_DATE: DateTimeFormatter = DateTimeFormatter.ofPattern("dd/MM/yyyy")

/** 12500 → « 12 500 F » (espace insécable fine comme séparateur de milliers). */
fun Fcfa.enFcfa(): String {
    val signe = if (this < 0) "−" else ""
    val chiffres = kotlin.math.abs(this).toString().reversed().chunked(3).joinToString(" ").reversed()
    return "$signe$chiffres F"
}

fun LocalDate.enTexte(): String = format(FORMAT_DATE)

/** Lit un montant tapé par l'utilisateur : « 12 500 », « 12500F », « 12.500 ». */
fun lireMontant(texte: String): Fcfa? =
    texte.filter { it.isDigit() || it == '-' }.takeIf { it.isNotEmpty() && it != "-" }?.toLongOrNull()
