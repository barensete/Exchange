package com.fasoresto.caisse.ui

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyListScope
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material3.Button
import androidx.compose.material3.ExtendedFloatingActionButton
import androidx.compose.material3.Scaffold
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.CalendarMonth
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.DatePicker
import androidx.compose.material3.DatePickerDialog
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ExposedDropdownMenuBox
import androidx.compose.material3.ExposedDropdownMenuDefaults
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.MenuAnchorType
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.rememberDatePickerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import com.fasoresto.core.calcul.enFcfa
import com.fasoresto.core.calcul.enTexte
import com.fasoresto.core.calcul.lireMontant
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneOffset

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun BarreRetour(titre: String, retour: () -> Unit, actions: @Composable () -> Unit = {}) {
    TopAppBar(
        title = { Text(titre) },
        navigationIcon = {
            IconButton(onClick = retour) { Icon(Icons.AutoMirrored.Filled.ArrowBack, "Retour") }
        },
        actions = { actions() },
    )
}

@Composable
fun Section(titre: String, modifier: Modifier = Modifier, contenu: @Composable ColumnScope.() -> Unit) {
    Card(modifier.fillMaxWidth(), colors = CardDefaults.cardColors()) {
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Text(titre, style = MaterialTheme.typography.titleMedium, color = MaterialTheme.colorScheme.primary)
            contenu()
        }
    }
}

/** Une ligne « libellé ……… montant ». */
@Composable
fun LigneMontant(
    libelle: String,
    montant: Long?,
    fort: Boolean = false,
    couleur: Color = Color.Unspecified,
    detail: String? = null,
) {
    Column {
        Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            Text(
                libelle, Modifier.weight(1f),
                fontWeight = if (fort) FontWeight.Bold else FontWeight.Normal,
            )
            Text(
                montant?.enFcfa() ?: "—",
                fontWeight = if (fort) FontWeight.Bold else FontWeight.Medium,
                color = couleur,
            )
        }
        if (detail != null) {
            Text(detail, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
}

/** Champ de saisie d'un montant (clavier numérique). Vide → null. */
@Composable
fun ChampMontant(
    libelle: String,
    valeur: Long?,
    onChange: (Long?) -> Unit,
    modifier: Modifier = Modifier,
    obligatoire: Boolean = false,
) {
    var texte by remember(valeur) { mutableStateOf(valeur?.toString().orEmpty()) }
    OutlinedTextField(
        value = texte,
        onValueChange = { t ->
            texte = t.filter { it.isDigit() }
            onChange(lireMontant(texte))
        },
        label = { Text(libelle) },
        suffix = { Text("F") },
        singleLine = true,
        isError = obligatoire && texte.isEmpty(),
        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
        modifier = modifier.fillMaxWidth(),
    )
}

@Composable
fun ChampTexte(libelle: String, valeur: String, onChange: (String) -> Unit, modifier: Modifier = Modifier, lignes: Int = 1) {
    OutlinedTextField(
        value = valeur,
        onValueChange = onChange,
        label = { Text(libelle) },
        singleLine = lignes == 1,
        minLines = lignes,
        modifier = modifier.fillMaxWidth(),
    )
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ChampDate(libelle: String, date: LocalDate?, onChange: (LocalDate) -> Unit, modifier: Modifier = Modifier) {
    var ouvert by remember { mutableStateOf(false) }
    OutlinedTextField(
        value = date?.enTexte().orEmpty(),
        onValueChange = {},
        readOnly = true,
        label = { Text(libelle) },
        isError = date == null,
        trailingIcon = {
            IconButton(onClick = { ouvert = true }) { Icon(Icons.Filled.CalendarMonth, "Choisir la date") }
        },
        modifier = modifier.fillMaxWidth(),
    )
    if (ouvert) {
        val etat = rememberDatePickerState(
            initialSelectedDateMillis = (date ?: LocalDate.now()).atStartOfDay(ZoneOffset.UTC).toInstant().toEpochMilli(),
        )
        DatePickerDialog(
            onDismissRequest = { ouvert = false },
            confirmButton = {
                TextButton(onClick = {
                    etat.selectedDateMillis?.let {
                        onChange(Instant.ofEpochMilli(it).atZone(ZoneOffset.UTC).toLocalDate())
                    }
                    ouvert = false
                }) { Text("OK") }
            },
            dismissButton = { TextButton(onClick = { ouvert = false }) { Text("Annuler") } },
        ) {
            DatePicker(etat)
        }
    }
}

/** Choix unique parmi quelques options, sous forme de pastilles. */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun <T> ChoixPastilles(
    libelle: String,
    options: List<T>,
    choisi: T?,
    texte: (T) -> String,
    onChange: (T) -> Unit,
) {
    Column {
        Text(
            libelle, style = MaterialTheme.typography.labelLarge,
            color = if (choisi == null) MaterialTheme.colorScheme.error else MaterialTheme.colorScheme.onSurfaceVariant,
        )
        FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            options.forEach { o ->
                FilterChip(selected = o == choisi, onClick = { onChange(o) }, label = { Text(texte(o)) })
            }
        }
    }
}

/** Menu déroulant (liste fermée). */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun <T> Selecteur(
    libelle: String,
    options: List<T>,
    choisi: T?,
    texte: (T) -> String,
    onChange: (T) -> Unit,
) {
    var ouvert by remember { mutableStateOf(false) }
    ExposedDropdownMenuBox(expanded = ouvert, onExpandedChange = { ouvert = it }) {
        OutlinedTextField(
            value = choisi?.let(texte).orEmpty(),
            onValueChange = {},
            readOnly = true,
            label = { Text(libelle) },
            isError = choisi == null,
            trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(ouvert) },
            modifier = Modifier.menuAnchor(MenuAnchorType.PrimaryNotEditable).fillMaxWidth(),
        )
        ExposedDropdownMenu(expanded = ouvert, onDismissRequest = { ouvert = false }) {
            options.forEach { o ->
                DropdownMenuItem(text = { Text(texte(o)) }, onClick = { onChange(o); ouvert = false })
            }
        }
    }
}

/** Texte libre avec suggestions (articles, fournisseurs déjà utilisés). */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ChampSuggestions(libelle: String, valeur: String, suggestions: List<String>, onChange: (String) -> Unit) {
    var ouvert by remember { mutableStateOf(false) }
    val filtrees = remember(valeur, suggestions) {
        if (valeur.isBlank()) emptyList()
        else suggestions.filter { it.contains(valeur.trim(), ignoreCase = true) && it != valeur }.take(8)
    }
    ExposedDropdownMenuBox(expanded = ouvert && filtrees.isNotEmpty(), onExpandedChange = { ouvert = it }) {
        OutlinedTextField(
            value = valeur,
            onValueChange = { onChange(it); ouvert = true },
            label = { Text(libelle) },
            singleLine = true,
            modifier = Modifier.menuAnchor(MenuAnchorType.PrimaryEditable).fillMaxWidth(),
        )
        ExposedDropdownMenu(expanded = ouvert && filtrees.isNotEmpty(), onDismissRequest = { ouvert = false }) {
            filtrees.forEach { s ->
                DropdownMenuItem(text = { Text(s) }, onClick = { onChange(s); ouvert = false })
            }
        }
    }
}

@Composable
fun ConfirmerSuppression(quoi: String, onConfirmer: () -> Unit, onAnnuler: () -> Unit) {
    AlertDialog(
        onDismissRequest = onAnnuler,
        title = { Text("Supprimer ?") },
        text = { Text("$quoi sera supprimé définitivement.") },
        confirmButton = { TextButton(onClick = onConfirmer) { Text("Supprimer", color = MaterialTheme.colorScheme.error) } },
        dismissButton = { TextButton(onClick = onAnnuler) { Text("Annuler") } },
    )
}

@Composable
fun Vide(texte: String) {
    Text(
        texte, Modifier.fillMaxWidth().padding(32.dp),
        color = MaterialTheme.colorScheme.onSurfaceVariant,
        style = MaterialTheme.typography.bodyLarge,
    )
}

/** Écran secondaire : barre de retour en haut, bouton d'action flottant facultatif. */
@Composable
fun EcranAvecBarre(
    titre: String,
    nav: Navigation,
    modifier: Modifier = Modifier,
    actions: @Composable () -> Unit = {},
    boutonFlottant: @Composable () -> Unit = {},
    contenu: @Composable (PaddingValues) -> Unit,
) {
    Scaffold(
        modifier = modifier,
        topBar = { BarreRetour(titre, nav.retour, actions) },
        floatingActionButton = boutonFlottant,
    ) { contenu(it) }
}

/** Contenu d'un onglet : titre, liste défilante et bouton « + » facultatif. */
@Composable
fun EcranOnglet(
    titre: String,
    modifier: Modifier = Modifier,
    ajouter: (() -> Unit)? = null,
    contenu: LazyListScope.() -> Unit,
) {
    Box(modifier.fillMaxSize()) {
        LazyColumn(
            contentPadding = PaddingValues(start = 16.dp, end = 16.dp, top = 16.dp, bottom = 96.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            item { Text(titre, style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold) }
            contenu()
        }
        if (ajouter != null) {
            ExtendedFloatingActionButton(
                onClick = ajouter,
                icon = { Icon(Icons.Filled.Add, null) },
                text = { Text("Ajouter") },
                modifier = Modifier.align(Alignment.BottomEnd).padding(16.dp),
            )
        }
    }
}

/** Formulaire défilant avec bouton Enregistrer en bas. */
@Composable
fun Formulaire(
    marges: PaddingValues,
    peutEnregistrer: Boolean,
    enregistrer: () -> Unit,
    contenu: @Composable ColumnScope.() -> Unit,
) {
    Column(
        Modifier.padding(marges).fillMaxSize().imePadding().verticalScroll(rememberScrollState()).padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        contenu()
        Button(onClick = enregistrer, enabled = peutEnregistrer, modifier = Modifier.fillMaxWidth()) {
            Text("Enregistrer")
        }
    }
}

@Composable
fun BoutonSupprimer(onClick: () -> Unit) {
    IconButton(onClick = onClick) { Icon(Icons.Filled.Delete, "Supprimer") }
}
