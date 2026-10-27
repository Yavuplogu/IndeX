package fr.index.index_windows

import android.app.Activity
import android.content.Intent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.IntentFilter
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaPlayer
import android.net.Uri
import android.os.Build
import android.provider.DocumentsContract
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private var picker: MethodChannel.Result? = null
    private var exportResult: MethodChannel.Result? = null
    private var exportText: String? = null
    private var player: MediaPlayer? = null
    private var ended = false
    private var audioError: String? = null
    private var prepared = false
    private var focus: AudioFocusRequest? = null
    private val audioManager by lazy { getSystemService(AUDIO_SERVICE) as AudioManager }
    private val worker = Executors.newSingleThreadExecutor()
    private val noisy = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) { if (prepared && player?.isPlaying == true) player?.pause() }
    }
    private var noisyRegistered = false
    private val focusListener = AudioManager.OnAudioFocusChangeListener { change ->
        if (change < 0) {
            runOnUiThread { if (prepared && player?.isPlaying == true) player?.pause() }
        }
    }
    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        val filter = IntentFilter(AudioManager.ACTION_AUDIO_BECOMING_NOISY)
        if (Build.VERSION.SDK_INT >= 33) registerReceiver(noisy, filter, Context.RECEIVER_NOT_EXPORTED)
        else { @Suppress("DEPRECATION") registerReceiver(noisy, filter) }
        noisyRegistered = true
        MethodChannel(engine.dartExecutor.binaryMessenger, "index/android").setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "privateDirectory" -> result.success(File(filesDir, "user").apply { mkdirs() }.absolutePath)
                    "pickTree" -> {
                        if (picker != null) { result.error("picker_busy", "Sélection déjà ouverte.", null) }
                        else {
                            picker = result
                            startActivityForResult(Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
                                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION or Intent.FLAG_GRANT_PREFIX_URI_PERMISSION)
                            }, 711)
                        }
                    }
                    "exportText" -> {
                        check(exportResult == null) { "Export déjà ouvert." }
                        val args = call.arguments as Map<*, *>
                        exportText = args["text"] as String; exportResult = result
                        startActivityForResult(Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                            type = "text/plain"; addCategory(Intent.CATEGORY_OPENABLE)
                            putExtra(Intent.EXTRA_TITLE, args["name"] as String)
                        }, 712)
                    }
                    "scan" -> {
                        val args = call.arguments as Map<*, *>
                        val uri = Uri.parse(args["tree"] as String)
                        val recursive = args["recursive"] == true
                        worker.execute {
                            val files = mutableListOf<Map<String, String>>()
                            val errors = mutableListOf<String>()
                            val visited = mutableSetOf<String>()
                            fun visit(id: String, depth: Int) {
                                if (!visited.add(id)) return
                                if (depth > 64 || visited.size > 50000) { errors.add("Parcours excessif interrompu."); return }
                                try {
                                    val children = DocumentsContract.buildChildDocumentsUriUsingTree(uri, id)
                                    val cursor = contentResolver.query(children, arrayOf(DocumentsContract.Document.COLUMN_DOCUMENT_ID, DocumentsContract.Document.COLUMN_DISPLAY_NAME, DocumentsContract.Document.COLUMN_MIME_TYPE), null, null, null)
                                    if (cursor == null) { errors.add("Dossier inaccessible : $id"); return }
                                    cursor.use {
                                        while (it.moveToNext()) {
                                            val child = it.getString(0)
                                            val name = it.getString(1) ?: ""
                                            val type = it.getString(2)
                                            if (type == DocumentsContract.Document.MIME_TYPE_DIR) { if (recursive) visit(child, depth + 1) }
                                            else if (name.endsWith(".mp3", true)) files.add(mapOf("name" to name, "reference" to DocumentsContract.buildDocumentUriUsingTree(uri, child).toString()))
                                        }
                                    }
                                } catch (e: Exception) { errors.add("Accès refusé ou source indisponible : ${e.message}") }
                            }
                            try { visit(DocumentsContract.getTreeDocumentId(uri), 0) } catch (e: Exception) { errors.add(e.toString()) }
                            runOnUiThread { result.success(mapOf("files" to files, "complete" to errors.isEmpty(), "errors" to errors)) }
                        }
                    }
                    "showTree" -> {
                        val tree = Uri.parse(call.arguments as String)
                        val document = DocumentsContract.buildDocumentUriUsingTree(tree, DocumentsContract.getTreeDocumentId(tree))
                        startActivity(Intent(Intent.ACTION_VIEW).setDataAndType(document, DocumentsContract.Document.MIME_TYPE_DIR).addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION))
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) { result.error("android_storage", e.toString(), null) }
        }
        MethodChannel(engine.dartExecutor.binaryMessenger, "index/audio").setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "open" -> {
                        val uri = Uri.parse(call.arguments as String)
                        require(uri.scheme == "content") { "URI locale SAF requise." }
                        player?.release(); prepared = false; ended = false; audioError = null
                        var preparing = true
                        player = MediaPlayer().apply {
                            setAudioAttributes(AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_MEDIA).setContentType(AudioAttributes.CONTENT_TYPE_SPEECH).build())
                            setDataSource(this@MainActivity, uri)
                            setOnCompletionListener { ended = true }
                            // Préparation asynchrone : ne pas bloquer l'interface sur un fournisseur lent.
                            setOnPreparedListener { if (preparing) { preparing = false; prepared = true; result.success(null) } }
                            setOnErrorListener { _, what, extra ->
                                prepared = false
                                audioError = "Audio indisponible ($what/$extra)."
                                if (preparing) { preparing = false; result.error("audio_prepare", audioError, null) }
                                true
                            }
                            prepareAsync()
                        }
                        return@setMethodCallHandler
                    }
                    "play" -> {
                        val granted = if (Build.VERSION.SDK_INT >= 26) {
                            focus = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN).setAudioAttributes(AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_MEDIA).build()).setOnAudioFocusChangeListener(focusListener).build()
                            audioManager.requestAudioFocus(focus!!)
                        } else { @Suppress("DEPRECATION") audioManager.requestAudioFocus(focusListener, AudioManager.STREAM_MUSIC, AudioManager.AUDIOFOCUS_GAIN) }
                        check(granted == AudioManager.AUDIOFOCUS_REQUEST_GRANTED) { "Priorité audio refusée." }
                        ended = false; player!!.start()
                    }
                    "pause" -> { if (prepared && player?.isPlaying == true) player?.pause() }
                    "seek" -> {
                        val value = (call.arguments as Number).toLong(); require(value in 0..Int.MAX_VALUE.toLong())
                        player!!.setOnSeekCompleteListener { it.setOnSeekCompleteListener(null); result.success(null) }
                        if (Build.VERSION.SDK_INT >= 26) player!!.seekTo(value, MediaPlayer.SEEK_CLOSEST)
                        else { @Suppress("DEPRECATION") player!!.seekTo(value.toInt()) }
                        ended = false; return@setMethodCallHandler
                    }
                    "volume" -> { val value = (call.arguments as Number).toFloat().coerceIn(0f, 1f); player!!.setVolume(value, value) }
                    "snapshot" -> { check(prepared) { audioError ?: "Audio non préparé" }; check(audioError == null) { audioError ?: "Erreur audio" }; val p = player!!; result.success(mapOf("position" to p.currentPosition, "duration" to p.duration, "playing" to p.isPlaying, "ended" to ended)); return@setMethodCallHandler }
                    "release" -> { player?.release(); player = null; prepared = false; if (Build.VERSION.SDK_INT >= 26) focus?.let { audioManager.abandonAudioFocusRequest(it) } }
                    else -> { result.notImplemented(); return@setMethodCallHandler }
                }
                result.success(null)
            } catch (e: Exception) { result.error("audio_native", e.toString(), null) }
        }
    }
    @Deprecated("Legacy activity callback required by FlutterActivity")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == 712) {
            val pending = exportResult; exportResult = null
            val text = exportText; exportText = null
            try {
                val uri = data?.data
                if (resultCode != Activity.RESULT_OK || uri == null) pending?.success(null)
                else {
                    val out = contentResolver.openOutputStream(uri, "wt") ?: error("Destination inaccessible.")
                    out.bufferedWriter(Charsets.UTF_8).use { it.write(text ?: "") }
                    pending?.success(uri.toString())
                }
            } catch (e: Exception) { pending?.error("export", e.toString(), null) }
        }
        if (requestCode == 711) {
            val pending = picker; picker = null
            try {
                val uri = data?.data
                if (resultCode != Activity.RESULT_OK || uri == null) pending?.success(null)
                else { contentResolver.takePersistableUriPermission(uri, Intent.FLAG_GRANT_READ_URI_PERMISSION); pending?.success(uri.toString()) }
            } catch (e: Exception) { pending?.error("permission", e.toString(), null) }
        }
    }
    override fun onStop() { if (prepared && player?.isPlaying == true) player?.pause(); super.onStop() }
    override fun onDestroy() { if (noisyRegistered) unregisterReceiver(noisy); player?.release(); player = null; worker.shutdown(); super.onDestroy() }
}
