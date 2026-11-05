package fr.index.app

import android.database.Cursor
import android.database.MatrixCursor
import android.os.CancellationSignal
import android.os.ParcelFileDescriptor
import android.provider.DocumentsContract.Document
import android.provider.DocumentsContract.Root
import android.provider.DocumentsProvider
import android.system.Os
import java.io.File
import java.io.FileNotFoundException
import java.text.Normalizer
import java.util.Locale

/** Seul le dossier MP3 géré est exposé : jamais le profil ni les sauvegardes. */
class IndeXDocumentsProvider : DocumentsProvider() {
    companion object {
        const val AUTHORITY = "fr.index.app.documents"
        val lock = Any()
        fun root(context: android.content.Context) = File(context.filesDir, "mp3").apply { mkdirs() }
        fun key(name: String) = Normalizer.normalize(name, Normalizer.Form.NFC).lowercase(Locale.ROOT)
        fun checkedName(name: String) {
            require(name.isNotBlank() && name.length <= 240 && name != "." && name != ".." &&
                name.none { it == '/' || it == '\\' || it.code < 32 }) { "Nom de document invalide." }
        }
        fun file(context: android.content.Context, id: String): File {
            require(id.startsWith("mp3:")) { "Identité de document invalide." }
            val relative = id.removePrefix("mp3:")
            require(!relative.startsWith('/') && relative.split('/').none { it == ".." || it == "." })
            val base = root(context).canonicalFile
            val value = if (relative.isEmpty()) base else File(base, relative)
            require(value.canonicalPath == value.absolutePath && (value == base || value.path.startsWith(base.path + "/"))) { "Chemin lié ou hors du dossier MP3." }
            return value
        }
        fun id(context: android.content.Context, file: File): String =
            "mp3:" + file.relativeTo(root(context).canonicalFile).invariantSeparatorsPath
        fun collision(parent: File, name: String): Boolean {
            val children = parent.listFiles() ?: error("Dossier inaccessible.")
            return children.any { key(it.name) == key(name) }
        }
        fun syncDirectory(directory: File) {
            val fd = Os.open(directory.path, android.system.OsConstants.O_RDONLY, 0)
            try { Os.fsync(fd) } finally { Os.close(fd) }
        }
        private val privateOperations = object : PrivateFileMoves.Operations {
            override fun existsNoFollow(target: File): Boolean = try {
                Os.lstat(target.path); true
            } catch (error: android.system.ErrnoException) {
                if (error.errno != android.system.OsConstants.ENOENT) throw error
                false
            }
            override fun rename(source: File, target: File) { Os.rename(source.path, target.path) }
            override fun syncDirectory(directory: File) { IndeXDocumentsProvider.syncDirectory(directory) }
        }
        fun movePrivate(context: android.content.Context, source: File, target: File) {
            PrivateFileMoves.move(context.filesDir, source, target, lock, privateOperations)
        }
        fun rename(context: android.content.Context, before: File, name: String): File = synchronized(lock) {
            checkedName(name)
            require(before.isFile && name.endsWith(".mp3", true))
            val after = file(context, id(context, File(before.parentFile, name)))
            if (before == after) return@synchronized before
            if (after.exists()) {
                val a = Os.stat(before.path); val b = Os.stat(after.path)
                // Compatibilité avec une ancienne opération interrompue utilisant un lien dur.
                require(a.st_dev == b.st_dev && a.st_ino == b.st_ino) { "Cible existante : aucun écrasement." }
                Os.remove(before.path)
                syncDirectory(before.parentFile!!)
            } else {
                require(!collision(before.parentFile!!, name)) { "Collision de casse ou Unicode." }
                movePrivate(context, before, after)
            }
            after
        }
    }
    override fun onCreate() = true
    override fun queryRoots(projection: Array<out String>?): Cursor {
        val cursor = MatrixCursor(projection ?: arrayOf(Root.COLUMN_ROOT_ID, Root.COLUMN_DOCUMENT_ID, Root.COLUMN_TITLE, Root.COLUMN_FLAGS, Root.COLUMN_MIME_TYPES, Root.COLUMN_ICON, Root.COLUMN_SUMMARY))
        val row = cursor.newRow()
        fun add(name: String, value: Any?) { if (cursor.getColumnIndex(name) >= 0) row.add(name, value) }
        add(Root.COLUMN_ROOT_ID, "mp3"); add(Root.COLUMN_DOCUMENT_ID, "mp3:")
        add(Root.COLUMN_SUMMARY, "Privé : supprimé à la désinstallation. Conservez vos originaux.")
        add(Root.COLUMN_TITLE, "IndeX · MP3"); add(Root.COLUMN_FLAGS, Root.FLAG_SUPPORTS_CREATE or Root.FLAG_LOCAL_ONLY)
        add(Root.COLUMN_MIME_TYPES, "audio/mpeg"); add(Root.COLUMN_ICON, R.drawable.index_icon)
        return cursor
    }
    private fun add(cursor: MatrixCursor, value: File) {
        if (!value.exists()) throw FileNotFoundException()
        file(context!!, id(context!!, value)) // refuse aussi les liens symboliques
        val row = cursor.newRow()
        fun cell(name: String, data: Any?) { if (cursor.getColumnIndex(name) >= 0) row.add(name, data) }
        cell(Document.COLUMN_DOCUMENT_ID, id(context!!, value))
        cell(Document.COLUMN_DISPLAY_NAME, if (value == root(context!!).canonicalFile) "MP3 IndeX" else value.name)
        cell(Document.COLUMN_MIME_TYPE, if (value.isDirectory) Document.MIME_TYPE_DIR else "audio/mpeg")
        cell(Document.COLUMN_SIZE, if (value.isFile) value.length() else 0)
        cell(Document.COLUMN_LAST_MODIFIED, value.lastModified())
        cell(Document.COLUMN_FLAGS, if (value.isDirectory) Document.FLAG_DIR_SUPPORTS_CREATE else Document.FLAG_SUPPORTS_WRITE or Document.FLAG_SUPPORTS_DELETE or Document.FLAG_SUPPORTS_RENAME)
    }
    private fun cursor(projection: Array<out String>?) = MatrixCursor(projection ?: arrayOf(Document.COLUMN_DOCUMENT_ID, Document.COLUMN_DISPLAY_NAME, Document.COLUMN_MIME_TYPE, Document.COLUMN_SIZE, Document.COLUMN_LAST_MODIFIED, Document.COLUMN_FLAGS))
    override fun queryDocument(documentId: String, projection: Array<out String>?): Cursor = cursor(projection).apply { add(this, file(context!!, documentId)) }
    override fun queryChildDocuments(parentDocumentId: String, projection: Array<out String>?, sortOrder: String?): Cursor = cursor(projection).apply {
        val parent = file(context!!, parentDocumentId)
        for (child in parent.listFiles() ?: throw FileNotFoundException()) add(this, child)
    }
    override fun isChildDocument(parentDocumentId: String, documentId: String): Boolean =
        file(context!!, documentId).path.startsWith(file(context!!, parentDocumentId).path + "/")
    override fun openDocument(documentId: String, mode: String, signal: CancellationSignal?): ParcelFileDescriptor = synchronized(lock) {
        val value = file(context!!, documentId)
        require(value.isFile)
        ParcelFileDescriptor.open(value, ParcelFileDescriptor.parseMode(mode))
    }
    override fun createDocument(parentDocumentId: String, mimeType: String, displayName: String): String = synchronized(lock) {
        checkedName(displayName)
        val parent = file(context!!, parentDocumentId)
        require(parent.isDirectory && !collision(parent, displayName)) { "Un document de même nom existe déjà." }
        val target = file(context!!, id(context!!, File(parent, displayName)))
        if (mimeType == Document.MIME_TYPE_DIR) check(target.mkdir())
        else { require(displayName.endsWith(".mp3", true)); check(target.createNewFile()) }
        id(context!!, target)
    }
    override fun renameDocument(documentId: String, displayName: String): String =
        id(context!!, rename(context!!, file(context!!, documentId), displayName))
    override fun deleteDocument(documentId: String) = synchronized(lock) {
        val value = file(context!!, documentId)
        require(value != root(context!!).canonicalFile)
        check(value.delete()) { "Document inaccessible ou dossier non vide." }
    }
}
