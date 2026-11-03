package fr.index.index_windows;

import java.io.File;
import java.io.IOException;

/**
 * Déplacement sans écrasement dans un espace de noms PRIVÉ à l'application.
 * Tous ses écrivains (worker et DocumentsProvider dans le même processus)
 * doivent partager lock. Ce protocole ne s'applique jamais à un fournisseur SAF
 * externe ou à un dossier accessible directement à d'autres applications.
 */
public final class PrivateFileMoves {
    private PrivateFileMoves() {}
    public interface Operations {
        boolean existsNoFollow(File target) throws IOException;
        void rename(File source, File target) throws IOException;
        void syncDirectory(File directory) throws IOException;
    }
    private static void checkPrivate(File root, File file) throws IOException {
        String path = file.getAbsolutePath();
        if (!path.equals(file.getCanonicalPath()) || !path.startsWith(root.getPath() + File.separator)) {
            throw new IOException("Chemin lié ou hors du stockage privé de l’application.");
        }
    }
    public static void move(File privateRoot, File source, File target, Object lock, Operations operations) throws IOException {
        synchronized (lock) {
            File root = privateRoot.getCanonicalFile();
            checkPrivate(root, source);
            checkPrivate(root, target);
            if (!source.isFile() || !target.getParentFile().isDirectory()) {
                throw new IOException("Source ou dossier de destination inaccessible.");
            }
            if (operations.existsNoFollow(target)) {
                throw new IOException("La cible existe déjà : aucun écrasement.");
            }
            // Aucun autre écrivain autorisé ne peut créer cette cible sous lock.
            // rename est atomique et n’a pas besoin du droit SELinux de créer un lien dur.
            operations.rename(source, target);
            operations.syncDirectory(target.getParentFile());
            if (!source.getParentFile().equals(target.getParentFile())) {
                operations.syncDirectory(source.getParentFile());
            }
        }
    }
}
