package fr.index.app

import android.content.Context
import io.flutter.embedding.engine.FlutterEngine

/** Un seul moteur/isolate/profil, conservé lors de la destruction de l'Activity. */
object IndexEngine {
    private var engine: FlutterEngine? = null
    var closing = false
    fun get(context: Context): FlutterEngine = engine ?: FlutterEngine(context.applicationContext).also {
        engine = it
        closing = false
    }
    fun close() {
        AndroidAudioBridge.dispose()
        engine?.destroy()
        engine = null
        closing = false
    }
}
