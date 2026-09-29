package com.fasoresto.caisse.donnees

import android.content.Context
import androidx.room.Dao
import androidx.room.Database
import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.Index
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.PrimaryKey
import androidx.room.Query
import androidx.room.Room
import androidx.room.RoomDatabase
import androidx.room.TypeConverter
import androidx.room.TypeConverters
import androidx.room.Upsert
import kotlinx.coroutines.flow.Flow
import java.time.LocalDate

@Entity(tableName = "journee")
data class JourneeEntite(
    @PrimaryKey val date: LocalDate,
    val matin: Long,
    val midi: Long,
    val soir: Long,
    val pate: Long,
    val autre: Long,
    val argentCompte: Long?,
    val fondDebut: Long?,
    val fondFin: Long?,
    val remarque: String,
)

@Entity(tableName = "depense", indices = [Index("date")])
data class DepenseEntite(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val date: LocalDate?,
    val article: String,
    val quantite: String,
    val montant: Long?,
    /** Nom de l'enum [com.fasoresto.core.modele.SourcePaiement]. */
    val payeAvec: String?,
    /** Nom de l'enum [com.fasoresto.core.modele.Categorie]. */
    val categorie: String?,
    val fournisseur: String,
    val remarque: String,
)

@Entity(tableName = "impaye", indices = [Index("date")])
data class ImpayeEntite(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val date: LocalDate?,
    val service: String?,
    val montant: Long?,
    val client: String,
    val remarque: String,
)

@Entity(
    tableName = "reglement",
    foreignKeys = [ForeignKey(ImpayeEntite::class, ["id"], ["impayeId"], onDelete = ForeignKey.CASCADE)],
    indices = [Index("impayeId")],
)
data class ReglementEntite(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val impayeId: Long,
    val date: LocalDate,
    val montant: Long,
)

@Entity(tableName = "remboursement")
data class RemboursementEntite(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val date: LocalDate,
    val associe: String,
    val montant: Long,
    val payeAvec: String,
    val remarque: String,
)

/** Une seule ligne (id = 1). */
@Entity(tableName = "parametres")
data class ParametresEntite(
    @PrimaryKey val id: Int = 1,
    val loyerMensuel: Long,
    val salairesMensuels: Long,
)

class Convertisseurs {
    @TypeConverter fun versTexte(d: LocalDate?): String? = d?.toString()
    @TypeConverter fun versDate(s: String?): LocalDate? = s?.let(LocalDate::parse)
}

@Dao
interface FasoDao {
    @Query("SELECT * FROM journee ORDER BY date") fun journees(): Flow<List<JourneeEntite>>
    @Query("SELECT * FROM depense ORDER BY date, id") fun depenses(): Flow<List<DepenseEntite>>
    @Query("SELECT * FROM impaye ORDER BY date, id") fun impayes(): Flow<List<ImpayeEntite>>
    @Query("SELECT * FROM reglement ORDER BY date, id") fun reglements(): Flow<List<ReglementEntite>>
    @Query("SELECT * FROM remboursement ORDER BY date, id") fun remboursements(): Flow<List<RemboursementEntite>>
    @Query("SELECT * FROM parametres WHERE id = 1") fun parametres(): Flow<ParametresEntite?>

    @Upsert suspend fun enregistrerJournee(j: JourneeEntite)
    @Upsert suspend fun enregistrerDepense(d: DepenseEntite): Long
    @Upsert suspend fun enregistrerImpaye(i: ImpayeEntite): Long
    @Upsert suspend fun enregistrerRemboursement(r: RemboursementEntite): Long
    @Upsert suspend fun enregistrerParametres(p: ParametresEntite)
    @Insert(onConflict = OnConflictStrategy.REPLACE) suspend fun ajouterReglement(r: ReglementEntite): Long

    @Query("DELETE FROM journee WHERE date = :date") suspend fun supprimerJournee(date: LocalDate)
    @Query("DELETE FROM depense WHERE id = :id") suspend fun supprimerDepense(id: Long)
    @Query("DELETE FROM impaye WHERE id = :id") suspend fun supprimerImpaye(id: Long)
    @Query("DELETE FROM reglement WHERE id = :id") suspend fun supprimerReglement(id: Long)
    @Query("DELETE FROM remboursement WHERE id = :id") suspend fun supprimerRemboursement(id: Long)

    @Query("DELETE FROM reglement") suspend fun viderReglements()
    @Query("DELETE FROM impaye") suspend fun viderImpayes()
    @Query("DELETE FROM depense") suspend fun viderDepenses()
    @Query("DELETE FROM journee") suspend fun viderJournees()
    @Query("DELETE FROM remboursement") suspend fun viderRemboursements()
}

@Database(
    entities = [
        JourneeEntite::class, DepenseEntite::class, ImpayeEntite::class,
        ReglementEntite::class, RemboursementEntite::class, ParametresEntite::class,
    ],
    version = 1,
)
@TypeConverters(Convertisseurs::class)
abstract class BaseDeDonnees : RoomDatabase() {
    abstract fun dao(): FasoDao

    companion object {
        fun ouvrir(context: Context): BaseDeDonnees =
            Room.databaseBuilder(context, BaseDeDonnees::class.java, "fasoresto.db").build()
    }
}
