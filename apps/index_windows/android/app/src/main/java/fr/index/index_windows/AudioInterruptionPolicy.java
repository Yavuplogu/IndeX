package fr.index.index_windows;

/** Réservation de reprise limitée à la piste et à l'interruption qui l'ont créée. */
public final class AudioInterruptionPolicy {
    public static final long NONE = -1;
    private long serial;
    private long token = NONE;
    private long source = NONE;
    private boolean waitingForGain;

    public long transientLoss(boolean wasPlaying, long currentSource) {
        if (token != NONE && source != currentSource) cancel();
        if (token != NONE && waitingForGain) return token; // Notifications imbriquées.
        if (!wasPlaying && token == NONE) return NONE;
        // Une deuxième perte après GAIN invalide la reprise déjà en file d'attente.
        token = ++serial;
        source = currentSource;
        waitingForGain = true;
        return token;
    }
    public long gain(long currentSource) {
        if (source != currentSource) { cancel(); return NONE; }
        if (token == NONE || !waitingForGain) return NONE;
        waitingForGain = false;
        return token;
    }
    public boolean owns(long candidate, long currentSource) {
        return token != NONE && token == candidate && source == currentSource;
    }
    public boolean canResume(long candidate, long currentSource) {
        return owns(candidate, currentSource) && !waitingForGain;
    }
    public boolean retainFocus() { return token != NONE; }
    public void resumed(long candidate, long currentSource) {
        if (canResume(candidate, currentSource)) cancel();
    }
    public void cancel() { token = NONE; source = NONE; waitingForGain = false; }
}
