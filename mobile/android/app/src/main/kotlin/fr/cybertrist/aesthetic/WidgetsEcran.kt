package fr.cybertrist.aesthetic

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.BitmapFactory
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Un widget de l'écran d'accueil : une image dessinée par l'appli (mêmes composants que ses
 * écrans), une par jour pour les sept jours à venir. Le widget montre celle d'aujourd'hui ; un
 * appui ouvre l'appli à la page prévue pour ce jour.
 *
 * Clés partagées avec `lib/features/ecran_accueil` : `<cle>_<aaaammjj>` (chemin de l'image) et
 * `<cle>_lien_<aaaammjj>` (page à ouvrir).
 */
abstract class WidgetImage(private val cle: String) : HomeWidgetProvider() {

  override fun onUpdate(
      context: Context,
      appWidgetManager: AppWidgetManager,
      appWidgetIds: IntArray,
      widgetData: SharedPreferences,
  ) {
    val jour = SimpleDateFormat("yyyyMMdd", Locale.US).format(Date())
    val chemin = widgetData.getString("${cle}_$jour", null) ?: derniere(widgetData)
    val page = widgetData.getString("${cle}_lien_$jour", null) ?: "/"
    val image = chemin?.let { runCatching { BitmapFactory.decodeFile(it) }.getOrNull() }
    val lien =
        Uri.parse("aesthetics://ouvrir")
            .buildUpon()
            .appendQueryParameter("chemin", page)
            .appendQueryParameter("widget", cle)
            .build()
    for (id in appWidgetIds) {
      val vues = RemoteViews(context.packageName, R.layout.widget_image)
      if (image != null) {
        vues.setImageViewBitmap(R.id.widget_image, image)
        vues.setViewVisibility(R.id.widget_image, View.VISIBLE)
        vues.setViewVisibility(R.id.widget_attente, View.GONE)
      } else {
        // Pas encore d'image : l'appli n'a pas été ouverte depuis la pose du widget.
        vues.setViewVisibility(R.id.widget_image, View.GONE)
        vues.setViewVisibility(R.id.widget_attente, View.VISIBLE)
      }
      vues.setOnClickPendingIntent(
          R.id.widget_racine,
          HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, lien),
      )
      appWidgetManager.updateAppWidget(id, vues)
    }
  }

  /** La dernière image connue, quand celle d'aujourd'hui manque (appli pas rouverte depuis une semaine). */
  private fun derniere(donnees: SharedPreferences): String? {
    val cles =
        donnees.all.keys.filter { it.startsWith("${cle}_") && it.length == cle.length + 9 && it.last().isDigit() }
    val aujourdhui = "${cle}_" + SimpleDateFormat("yyyyMMdd", Locale.US).format(Date())
    // De préférence le jour passé le plus proche ; sinon le premier jour à venir.
    val choisie = cles.filter { it <= aujourdhui }.maxOrNull() ?: cles.minOrNull()
    return choisie?.let { donnees.getString(it, null) }
  }
}

class WidgetLancer : WidgetImage("lancer")

class WidgetSemaine : WidgetImage("semaine")

class WidgetSerie : WidgetImage("serie")

class WidgetRecuperation : WidgetImage("recup")

class WidgetMois : WidgetImage("mois")

/**
 * Un widget animé : douze images dessinées par l'appli, qui défilent en boucle (le personnage
 * fait l'exercice du dernier record).
 *
 * Clés : `<cle>_a<k>` (chemin de l'image k), `<cle>_n` (nombre d'images), `<cle>_lien` (page).
 */
abstract class WidgetAnime(private val cle: String) : HomeWidgetProvider() {

  private val trames =
      intArrayOf(
          R.id.widget_t0, R.id.widget_t1, R.id.widget_t2, R.id.widget_t3,
          R.id.widget_t4, R.id.widget_t5, R.id.widget_t6, R.id.widget_t7,
          R.id.widget_t8, R.id.widget_t9, R.id.widget_t10, R.id.widget_t11,
      )

  override fun onUpdate(
      context: Context,
      appWidgetManager: AppWidgetManager,
      appWidgetIds: IntArray,
      widgetData: SharedPreferences,
  ) {
    val n = widgetData.all["${cle}_n"].let { (it as? Number)?.toInt() ?: 0 }
    val page = widgetData.getString("${cle}_lien", null) ?: "/progres/records"
    val images =
        (0 until n).mapNotNull { k ->
          widgetData.getString("${cle}_a$k", null)?.let {
            runCatching { BitmapFactory.decodeFile(it) }.getOrNull()
          }
        }
    val lien =
        Uri.parse("aesthetics://ouvrir")
            .buildUpon()
            .appendQueryParameter("chemin", page)
            .appendQueryParameter("widget", cle)
            .build()
    for (id in appWidgetIds) {
      val vues = RemoteViews(context.packageName, R.layout.widget_anime)
      if (images.isEmpty()) {
        vues.setViewVisibility(R.id.widget_film, View.GONE)
        vues.setViewVisibility(R.id.widget_attente, View.VISIBLE)
      } else {
        vues.setViewVisibility(R.id.widget_film, View.VISIBLE)
        vues.setViewVisibility(R.id.widget_attente, View.GONE)
        // Moins d'images que de cases (exercice sans animation) : la même image partout.
        for ((i, vue) in trames.withIndex()) {
          vues.setImageViewBitmap(vue, images[i % images.size])
        }
      }
      vues.setOnClickPendingIntent(
          R.id.widget_racine,
          HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, lien),
      )
      appWidgetManager.updateAppWidget(id, vues)
    }
  }
}

class WidgetRecord : WidgetAnime("record")

class WidgetRecordLarge : WidgetAnime("recordl")
