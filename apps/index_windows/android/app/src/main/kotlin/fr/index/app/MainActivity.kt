package fr.index.app

import android.app.Activity
import android.content.Intent
import android.content.Context
import android.net.Uri
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
    private val worker = Executors.newSingleThreadExecutor()
    private val documents by lazy { AndroidDocuments(this, worker) }
    override fun provideFlutterEngine(context: Context): FlutterEngine = IndexEngine.get(context)
    override fun shouldDestroyEngineWithHost() = false
    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        AndroidAudioBridge.install(applicationContext, engine)
        MethodChannel(engine.dartExecutor.binaryMessenger, "index/android").setMethodCallHandler { call, result ->
            try {
                if (documents.handle(call, result)) return@setMethodCallHandler
                when (call.method) {
                    "openGithub" -> {
                        startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("https://github.com/Yavuplogu/IndeX")))
                        result.success(null)
                    }
                    "backgroundTask" -> { moveTaskToBack(true); result.success(null) }
                    "closeApplication" -> { IndexEngine.closing = true; result.success(null); stopService(Intent(this, IndexPlaybackService::class.java)); finishAndRemoveTask() }
                    "privateDirectory" -> result.success(File(filesDir, "user").apply { mkdirs() }.absolutePath)
                    "pickTree" -> {
                        if (picker != null) { result.error("picker_busy", "Sélection déjà ouverte.", null) }
                        else {
                            picker = result
                            startActivityForResult(Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
                                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION or Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION or Intent.FLAG_GRANT_PREFIX_URI_PERMISSION)
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
                            try { documents.filterScan(files, errors, uri) } catch (e: Exception) { errors.add("Journal des téléchargements illisible : ${e.message}"); files.clear() }
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
    }
    @Deprecated("Legacy activity callback required by FlutterActivity")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (documents.onActivityResult(requestCode, resultCode, data)) return
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
                else { contentResolver.takePersistableUriPermission(uri, data!!.flags and (Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION)); pending?.success(uri.toString()) }
            } catch (e: Exception) { pending?.error("permission", e.toString(), null) }
        }
    }
    override fun onDestroy() {
        worker.shutdown()
        super.onDestroy()
        if (IndexEngine.closing) IndexEngine.close()
    }
}
