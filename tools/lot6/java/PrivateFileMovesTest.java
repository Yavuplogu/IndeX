package fr.index.app;

import java.io.*;
import java.nio.file.*;
import java.util.concurrent.*;
import java.util.concurrent.atomic.AtomicInteger;

public final class PrivateFileMovesTest {
    private static final Object lock = new Object();
    private static void check(boolean value) {
        if (!value) throw new AssertionError();
    }
    private static class Operations implements PrivateFileMoves.Operations {
        boolean failRename, failSync;
        private void held() { check(Thread.holdsLock(lock)); }
        public boolean existsNoFollow(File target) { held(); return Files.exists(target.toPath(), LinkOption.NOFOLLOW_LINKS); }
        public void rename(File source, File target) throws IOException {
            held();
            if (failRename) throw new IOException("rename failed");
            // Imite le remplacement possible de Os.rename : le protocole doit le prévenir.
            Files.move(source.toPath(), target.toPath(), StandardCopyOption.REPLACE_EXISTING);
        }
        public void syncDirectory(File directory) throws IOException {
            held(); if (failSync) throw new IOException("fsync failed");
        }
    }
    private static void move(Path root, Path source, Path target, Operations operations) throws IOException {
        PrivateFileMoves.move(root.toFile(), source.toFile(), target.toFile(), lock, operations);
    }
    private static void refused(Path root, Path source, Path target) throws IOException {
        try { move(root, source, target, new Operations()); throw new AssertionError("Écrasement autorisé"); }
        catch (IOException expected) { check(Files.exists(source)); }
    }
    public static void main(String[] args) throws Exception {
        Path root = Files.createTempDirectory("index-private-moves-").toRealPath();
        try {
            Path source = Files.writeString(root.resolve("source"), "JSON complet");
            Path target = root.resolve("export.json");
            move(root, source, target, new Operations());
            check(!Files.exists(source) && Files.readString(target).equals("JSON complet"));
            Files.writeString(source, "autre JSON");
            refused(root, source, target);
            check(Files.readString(target).equals("JSON complet"));
            Path empty = Files.createFile(root.resolve("empty"));
            refused(root, source, empty); check(Files.size(empty) == 0);
            Path folder = Files.createDirectory(root.resolve("folder"));
            refused(root, source, folder);
            Path symlink = Files.createSymbolicLink(root.resolve("link"), target);
            refused(root, source, symlink);
            refused(root, symlink, root.resolve("new"));
            check(Files.readString(target).equals("JSON complet"));
            Path dangling = Files.createSymbolicLink(root.resolve("dangling"), root.resolve("missing"));
            refused(root, source, dangling); check(Files.isSymbolicLink(dangling));
            Path outside = Files.createTempFile("index-outside-", ".json").toRealPath();
            try {
                refused(root, source, outside);
                refused(root, outside, root.resolve("outside-copy"));
                check(Files.size(outside) == 0);
            } finally { Files.delete(outside); }
            Operations failed = new Operations(); failed.failRename = true;
            try { move(root, source, root.resolve("failed"), failed); throw new AssertionError(); }
            catch (IOException expected) { check(Files.exists(source) && !Files.exists(root.resolve("failed"))); }
            failed.failRename = false; failed.failSync = true;
            Path committed = root.resolve("committed");
            try { move(root, source, committed, failed); throw new AssertionError(); }
            catch (IOException expected) { check(!Files.exists(source) && Files.readString(committed).equals("autre JSON")); }
            Path a = Files.writeString(root.resolve("a"), "a"), b = Files.writeString(root.resolve("b"), "b");
            Path shared = root.resolve("shared");
            AtomicInteger successes = new AtomicInteger(), refusals = new AtomicInteger();
            CountDownLatch start = new CountDownLatch(1);
            ExecutorService executor = Executors.newFixedThreadPool(2);
            try {
                Future<?>[] futures = new Future<?>[2]; int i = 0;
                for (Path candidate : new Path[]{a, b}) {
                    futures[i++] = executor.submit(() -> {
                        try { start.await(); move(root, candidate, shared, new Operations()); successes.incrementAndGet(); }
                        catch (IOException expected) { refusals.incrementAndGet(); }
                        catch (InterruptedException error) { throw new RuntimeException(error); }
                    });
                }
                start.countDown();
                for (Future<?> future : futures) future.get(10, TimeUnit.SECONDS);
            } finally { executor.shutdownNow(); }
            check(successes.get() == 1 && refusals.get() == 1);
            String winner = Files.readString(shared);
            check(!Files.exists(root.resolve(winner)));
            Path loser = root.resolve(winner.equals("a") ? "b" : "a");
            check(Files.readString(loser).equals(loser.getFileName().toString()));
            System.out.println("OK : publication privée, collisions, liens, confinement, concurrence et interruptions.");
        } finally {
            try (var paths = Files.walk(root)) {
                for (Path path : paths.sorted(java.util.Comparator.reverseOrder()).toList()) Files.delete(path);
            }
        }
    }
}
