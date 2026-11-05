package fr.index.app

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.provider.DocumentsContract
import android.provider.DocumentsContract.Document
import android.system.Os
import android.util.AtomicFile
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.io.FileNotFoundException
import java.security.MessageDigest
import java.util.UUID
import java.util.concurrent.ExecutorService

/** Adaptateur SAF, exécuté hors du thread UI. Aucun URI externe converti en path. */
class AndroidDocuments(private val activity: Activity, private val worker: ExecutorService) {
    private val resolver get() = activity.contentResolver
    private var picker: MethodChannel.Result? = null
    private var exporter: MethodChannel.Result? = null
    private var exportPath: String? = null
    private val ledger by lazy { AtomicFile(File(activity.filesDir, "index-publications.json")) }
    private fun readLedger(): MutableList<JSONObject> = try {
        val raw = JSONArray(ledger.openRead().bufferedReader().use { it.readText() })
        (0 until raw.length()).map { raw.getJSONObject(it) }.toMutableList()
    } catch (_: FileNotFoundException) { mutableListOf() }
    private fun writeLedger(items: List<JSONObject>) {
        val out = ledger.startWrite()
        try { out.write(JSONArray(items).toString().toByteArray(Charsets.UTF_8)); ledger.finishWrite(out) }
        catch (e: Exception) { ledger.failWrite(out); throw e }
    }
    private fun update(entry: JSONObject, remove: Boolean = false) {
        val all = readLedger().filter { it.getString("id") != entry.getString("id") }.toMutableList()
        if (!remove) all.add(entry)
        writeLedger(all)
    }
    private fun uri(raw: String): Uri = Uri.parse(raw).also {
        require(it.scheme == "content") { "URI SAF requise." }
        require(it.authority != IndeXDocumentsProvider.AUTHORITY) {
            "L’ancien dossier MP3 privé est retiré. Choisissez un dossier MP3 local dans Fichiers."
        }
    }
    private fun privateFile(path: String): File {
        val file = File(path)
        require(file.canonicalPath == file.absolutePath && file.path.startsWith(activity.filesDir.canonicalPath + "/")) { "Fichier hors du stockage privé." }
        return file
    }
    private fun hash(input: java.io.InputStream): String {
        val digest = MessageDigest.getInstance("SHA-256")
        input.use { source -> val buffer = ByteArray(65536); var total = 0L; while (true) { val n = source.read(buffer); if (n < 0) break; total += n; require(total <= 512L*1024*1024) { "Document trop volumineux pour le contrôle." }; digest.update(buffer,0,n) } }
        return digest.digest().joinToString("") { "%02x".format(it) }
    }
    private fun fingerprint(raw: String): Map<String, Any>? {
        val document = uri(raw)
        require(document.authority == IndeXDocumentsProvider.AUTHORITY) { "Réconciliation limitée au fournisseur IndeX." }
        val file = IndeXDocumentsProvider.file(activity, DocumentsContract.getDocumentId(document))
        if (!file.exists()) return null
        require(file.isFile)
        val before = Os.stat(file.path)
        val digest = hash(file.inputStream())
        val after = Os.stat(file.path)
        require(before.st_size == after.st_size && before.st_mtime == after.st_mtime && before.st_ino == after.st_ino) { "Fichier modifié pendant sa vérification." }
        return mapOf("bytes" to file.length(), "modified" to file.lastModified().toString(), "digest" to digest, "identity" to "${after.st_dev}:${after.st_ino}")
    }
    private fun sameDocument(left: String?, right: Uri): Boolean = try {
        val value = uri(left ?: "")
        value.authority == right.authority && DocumentsContract.getDocumentId(value) == DocumentsContract.getDocumentId(right)
    } catch (_: Exception) { false }
    private fun documentName(document: Uri): String = resolver.query(document, arrayOf(Document.COLUMN_DISPLAY_NAME), null,null,null)?.use {
        check(it.moveToFirst()) { "Document introuvable." }; it.getString(0)
    } ?: error("Document inaccessible.")
    private fun children(tree: Uri): List<Pair<Uri,String>> {
        val parent = DocumentsContract.getTreeDocumentId(tree)
        val query = DocumentsContract.buildChildDocumentsUriUsingTree(tree,parent)
        return resolver.query(query,arrayOf(Document.COLUMN_DOCUMENT_ID,Document.COLUMN_DISPLAY_NAME),null,null,null)?.use {
            val result = mutableListOf<Pair<Uri,String>>()
            while (it.moveToNext()) result.add(DocumentsContract.buildDocumentUriUsingTree(tree,it.getString(0)) to it.getString(1))
            result
        } ?: error("Dossier inaccessible.")
    }
    private fun renameInfo(reference: String, name: String): Map<String, Any> {
        val before = uri(reference)
        if (before.authority != IndeXDocumentsProvider.AUTHORITY) return mapOf("supported" to false, "reason" to "Ce fournisseur ne garantit pas le renommage sans écrasement. Le renommage est disponible uniquement sur Windows.")
        IndeXDocumentsProvider.checkedName(name)
        require(name.endsWith(".mp3",true))
        return synchronized(IndeXDocumentsProvider.lock) {
            val file = IndeXDocumentsProvider.file(activity, DocumentsContract.getDocumentId(before))
            val target = File(file.parentFile,name)
            val after = DocumentsContract.buildDocumentUriUsingTree(before, IndeXDocumentsProvider.id(activity,target))
            mapOf("supported" to true, "collision" to IndeXDocumentsProvider.collision(file.parentFile!!,name), "after" to after.toString()) + (fingerprint(reference) ?: error("Source absente."))
        }
    }
    private fun rename(args: Map<*,*>): String = synchronized(IndeXDocumentsProvider.lock) {
        val reference = args["reference"] as String
        val before = uri(reference)
        require(before.authority == IndeXDocumentsProvider.AUTHORITY)
        val current = fingerprint(reference) ?: error("Source absente.")
        require(current["digest"] == args["digest"] && (current["bytes"] as Number).toLong() == (args["bytes"] as Number).toLong() && current["modified"] == args["modified"]) { "Source modifiée depuis l’aperçu." }
        val after = IndeXDocumentsProvider.rename(activity, IndeXDocumentsProvider.file(activity,DocumentsContract.getDocumentId(before)),args["name"] as String)
        val target = DocumentsContract.buildDocumentUriUsingTree(before,IndeXDocumentsProvider.id(activity,after)).toString()
        require(fingerprint(target)?.get("digest") == args["digest"]) { "Empreinte changée : réconciliation requise." }
        target
    }
    private fun publishPrivate(args: Map<*,*>) {
        val partial = privateFile(args["partial"] as String)
        val target = privateFile(args["target"] as String)
        require(partial.isFile && target.parentFile!!.isDirectory)
        IndeXDocumentsProvider.movePrivate(activity, partial, target)
    }
    private fun checkDestination(tree: Uri, name: String) {
        IndeXDocumentsProvider.checkedName(name)
        require(name.endsWith(".mp3",true))
        require(tree.authority in setOf("com.android.externalstorage.documents","com.android.providers.downloads.documents")) { "Publication MP3 limitée aux fournisseurs locaux Android. Choisissez un dossier local." }
        if (tree.authority != IndeXDocumentsProvider.AUTHORITY) {
            require(activity.checkUriPermission(tree,android.os.Process.myPid(),android.os.Process.myUid(),Intent.FLAG_GRANT_WRITE_URI_PERMISSION) == android.content.pm.PackageManager.PERMISSION_GRANTED) { "Autorisation d’écriture manquante : resélectionnez ce dossier dans Fichiers et associations." }
        }
        require(children(tree).none { IndeXDocumentsProvider.key(it.second) == IndeXDocumentsProvider.key(name) }) { "Un fichier de ce nom existe déjà. Aucun écrasement." }
    }
    private fun publishDocument(args: Map<*,*>): Map<String,String> {
        val source = privateFile(args["source"] as String)
        val tree = uri(args["tree"] as String)
        val name = args["name"] as String
        checkDestination(tree,name)
        val digest = hash(source.inputStream())
        val entry = JSONObject(mapOf("id" to UUID.randomUUID().toString(), "tree" to tree.toString(), "name" to name, "digest" to digest, "uri" to "", "episode_id" to (args["episode_id"] as String), "profile_id" to (args["profile_id"] as String), "previous" to (args["previous"] as String), "excluded_before" to JSONArray(args["excluded_before"] as List<*>)))
        // Durable avant toute création : une interruption ne doit pas faire scanner un fichier partiel.
        update(entry)
        var started = false
        try {
            require(children(tree).none { IndeXDocumentsProvider.key(it.second) == IndeXDocumentsProvider.key(name) }) { "Un fichier de ce nom existe déjà. Aucun écrasement." }
            val target: Uri
            if (tree.authority == IndeXDocumentsProvider.AUTHORITY) {
                synchronized(IndeXDocumentsProvider.lock) {
                    val parent = IndeXDocumentsProvider.file(activity,DocumentsContract.getTreeDocumentId(tree))
                    require(!IndeXDocumentsProvider.collision(parent,name)) { "Cible existante : aucun écrasement." }
                    val file = IndeXDocumentsProvider.file(activity,IndeXDocumentsProvider.id(activity,File(parent,name)))
                    target = DocumentsContract.buildDocumentUriUsingTree(tree,IndeXDocumentsProvider.id(activity,file))
                    // Conserver l’identité de la cible AVANT la tentative de déplacement.
                    entry.put("uri",target.toString()); update(entry)
                    started = true
                    IndeXDocumentsProvider.movePrivate(activity, source, file)
                }
            } else {
                val parent = DocumentsContract.buildDocumentUriUsingTree(tree,DocumentsContract.getTreeDocumentId(tree))
                started = true
                target = DocumentsContract.createDocument(resolver,parent,"audio/mpeg",name) ?: error("Création refusée par le fournisseur.")
            }
            entry.put("uri",target.toString()); update(entry)
            require(documentName(target) == name) { "Le fournisseur a modifié le nom ; aucune association. Supprimez le document incomplet depuis Fichiers Android." }
            if (tree.authority != IndeXDocumentsProvider.AUTHORITY) {
                resolver.openOutputStream(target,"w")?.use { out -> source.inputStream().use { it.copyTo(out) }; out.flush() } ?: error("Écriture refusée.")
            }
            require(hash(resolver.openInputStream(target) ?: error("Lecture de contrôle refusée.")) == digest) { "Copie incomplète ou modifiée." }
            entry.put("verified",true); update(entry)
            return mapOf("reference" to target.toString(),"id" to entry.getString("id"))
        } catch (e: Exception) {
            if (!started) update(entry,remove=true)
            throw IllegalStateException("Publication refusée ou incomplète. Aucun fichier existant remplacé. Relancez le scan pour le diagnostic : ${e.message}",e)
        }
    }
    /** Réconcilie seulement une copie complète ; ne supprime jamais un document ambigu. */
    fun filterScan(files: MutableList<Map<String,String>>, errors: MutableList<String>, scope: Uri) {
        val remaining = mutableListOf<JSONObject>()
        for (entry in readLedger()) {
            try {
                val parentTree = uri(entry.getString("tree"))
                if (scope.authority != parentTree.authority) { remaining.add(entry); continue }
                val currentId = DocumentsContract.getTreeDocumentId(scope)
                val pendingId = DocumentsContract.getTreeDocumentId(parentTree)
                if (currentId != pendingId && !DocumentsContract.isChildDocument(resolver,
                    DocumentsContract.buildDocumentUriUsingTree(scope,currentId),
                    DocumentsContract.buildDocumentUriUsingTree(scope,pendingId))) { remaining.add(entry); continue }
                val raw = entry.optString("uri")
                val found = if (raw.isNotEmpty()) listOf(uri(raw) to entry.getString("name")) else children(uri(entry.getString("tree"))).filter { IndeXDocumentsProvider.key(it.second) == IndeXDocumentsProvider.key(entry.getString("name")) }
                if (found.isEmpty()) continue
                var complete = found.size == 1 && !entry.optBoolean("blocked")
                var removed = 0
                for ((document,_) in found) {
                    try {
                        val input = resolver.openInputStream(document) ?: error("Document inaccessible.")
                        if (hash(input) != entry.getString("digest") || documentName(document) != entry.getString("name")) complete = false
                    } catch (_: FileNotFoundException) {
                        // Une erreur de lecture seule ne prouve pas une suppression.
                        if (children(parentTree).none { sameDocument(it.first.toString(),document) || IndeXDocumentsProvider.key(it.second) == IndeXDocumentsProvider.key(entry.getString("name")) }) removed++
                        else complete = false
                    }
                }
                if (removed == found.size) continue
                if (removed > 0) complete = false
                entry.put("checkedScope",scope.toString()); entry.put("verified",complete)
                if (complete) { entry.put("uri",found.single().first.toString()); remaining.add(entry); continue }
                for ((document,_) in found) files.removeAll { sameDocument(it["reference"],document) }
                errors.add("Publication non validée, conservée hors associations : ${entry.getString("name")}. Vérifiez ce fichier dans Fichiers Android. Supprimez seulement une copie réellement incomplète, jamais un original préexistant, puis rescanez.")
                remaining.add(entry)
            } catch (e: Exception) {
                entry.put("verified",false); entry.put("checkedScope",scope.toString())
                if (entry.optString("uri").isNotEmpty()) files.removeAll { sameDocument(it["reference"],uri(entry.getString("uri"))) }
                errors.add("Publication à réconcilier, accès indisponible : ${entry.optString("name")} (${e.message})")
                remaining.add(entry)
            }
        }
        writeLedger(remaining)
    }
    fun handle(call: MethodCall, result: MethodChannel.Result): Boolean {
        when (call.method) {
            "pickJson" -> {
                check(picker == null) { "Sélecteur déjà ouvert." }; picker = result
                activity.startActivityForResult(Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                    type = "application/json"; addCategory(Intent.CATEGORY_OPENABLE)
                    putExtra(Intent.EXTRA_MIME_TYPES,arrayOf("application/json","text/json","text/plain","application/octet-stream"))
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                },713); return true
            }
            "exportJson" -> {
                check(exporter == null) { "Export déjà ouvert." }
                val source = privateFile(call.argument<String>("path")!!)
                require(source.extension == "json" && source.length() <= 5*1024*1024)
                exporter = result; exportPath = source.path
                activity.startActivityForResult(Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                    type = "application/json"; addCategory(Intent.CATEGORY_OPENABLE); putExtra(Intent.EXTRA_TITLE,source.name)
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
                },714); return true
            }
            "readDocument", "publishPrivate", "publishDocument", "checkDestination", "publicationState", "ackPublication", "quarantinePublication", "renameInfo", "renameDocument", "fingerprint" -> {
                worker.execute {
                    try {
                        val args = call.arguments as Map<*,*>
                        val value: Any? = when(call.method) {
                            "readDocument" -> {
                                val document = uri(args["reference"] as String)
                                require(documentName(document).endsWith(".json",true)) { "Fichier JSON requis." }
                                (resolver.openInputStream(document) ?: error("Fichier inaccessible.")).use { input ->
                                    val out = java.io.ByteArrayOutputStream(); val buffer = ByteArray(65536)
                                    while (true) { val n=input.read(buffer); if(n<0) break; require(out.size()+n<=5*1024*1024) { "JSON supérieur à 5 Mio." }; out.write(buffer,0,n) }
                                    out.toByteArray()
                                }
                            }
                            "publicationState" -> {
                                val warnings = mutableListOf<String>()
                                filterScan(mutableListOf(),warnings,uri(args["tree"] as String))
                                mapOf("errors" to warnings, "pending" to readLedger().map { record ->
                                    val excluded = record.optJSONArray("excluded_before") ?: JSONArray()
                                    mapOf("id" to record.getString("id"), "uri" to record.optString("uri"), "tree" to record.getString("tree"), "name" to record.getString("name"),
                                        "episode_id" to record.optString("episode_id"), "profile_id" to record.optString("profile_id"), "previous" to record.optString("previous"),
                                        "excluded_before" to (0 until excluded.length()).map { excluded.getString(it) },
                                        "verified" to (record.optBoolean("verified") && !record.optBoolean("blocked") && record.optString("checkedScope") == args["tree"]))
                                })
                            }
                            "ackPublication", "quarantinePublication" -> {
                                val record = readLedger().firstOrNull { it.getString("id") == args["id"] }
                                if (record != null) {
                                    if (call.method == "ackPublication") { require(record.optBoolean("verified") && record.optString("uri") == args["reference"]); update(record,remove=true) }
                                    else { record.put("blocked",true); record.put("verified",false); update(record) }
                                }
                                null
                            }
                            "checkDestination" -> { checkDestination(uri(args["tree"] as String),args["name"] as String); null }
                            "publishPrivate" -> { publishPrivate(args); null }
                            "publishDocument" -> publishDocument(args)
                            "renameInfo" -> renameInfo(args["reference"] as String,args["name"] as String)
                            "renameDocument" -> rename(args)
                            else -> fingerprint(args["reference"] as String)
                        }
                        activity.runOnUiThread { result.success(value) }
                    } catch(e: Exception) { activity.runOnUiThread { result.error("android_documents",e.toString(),null) } }
                }; return true
            }
            else -> return false
        }
    }
    fun onActivityResult(code: Int, status: Int, data: Intent?): Boolean {
        if (code == 713) { val pending=picker; picker=null; pending?.success(if(status==Activity.RESULT_OK) data?.data?.toString() else null); return true }
        if (code != 714) return false
        val pending=exporter; exporter=null; val path=exportPath; exportPath=null
        val document=data?.data
        if(status!=Activity.RESULT_OK || document==null) { pending?.success(null); return true }
        worker.execute {
            try {
                val source=privateFile(path!!)
                // ACTION_CREATE_DOCUMENT crée un nouveau document, jamais un remplacement silencieux.
                resolver.openOutputStream(document,"w")?.use { out -> source.inputStream().use { it.copyTo(out) }; out.flush() } ?: error("Destination inaccessible.")
                require(hash(resolver.openInputStream(document) ?: error("Contrôle de copie refusé.")) == hash(source.inputStream())) { "Export incomplet." }
                activity.runOnUiThread { pending?.success(document.toString()) }
            } catch(e: Exception) { activity.runOnUiThread { pending?.error("export_json",e.toString(),null) } }
        }
        return true
    }
}
