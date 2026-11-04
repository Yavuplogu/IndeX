package fr.index.index_windows;

public final class AudioInterruptionPolicyTest {
    private static void check(boolean condition) { if (!condition) throw new AssertionError(); }
    public static void main(String[] args) {
        AudioInterruptionPolicy p = new AudioInterruptionPolicy();
        // Lecture en cours : garder le focus, attendre GAIN et ne reprendre qu'une fois.
        long token = p.transientLoss(true, 10);
        check(token > 0 && p.retainFocus() && !p.canResume(token, 10));
        check(p.gain(10) == token && p.canResume(token, 10));
        check(p.gain(10) == AudioInterruptionPolicy.NONE);
        p.resumed(token, 10);
        check(!p.retainFocus() && !p.canResume(token, 10));
        // Une piste déjà en pause ne doit jamais repartir sur une notification.
        check(p.transientLoss(false, 10) == AudioInterruptionPolicy.NONE);
        check(p.gain(10) == AudioInterruptionPolicy.NONE);
        // Notifications/appel imbriqués pendant la pause : conserver l'intention initiale.
        token = p.transientLoss(true, 10);
        check(p.transientLoss(false, 10) == token);
        check(p.gain(10) == token && p.owns(token, 10));
        // GAIN avant l'acquittement de pause reste valide, mais une nouvelle perte l'invalide.
        long newer = p.transientLoss(false, 10);
        check(newer != token && newer > 0 && !p.canResume(token, 10));
        check(!p.canResume(newer, 10));
        check(p.gain(10) == newer && p.canResume(newer, 10));
        // Pause/arrêt/casque/perte permanente : annulation, y compris après GAIN mis en file.
        p.cancel();
        check(!p.canResume(newer, 10) && !p.retainFocus());
        check(p.gain(10) == AudioInterruptionPolicy.NONE);
        // Une autre piste ne doit pas recevoir la reprise de l'ancienne.
        token = p.transientLoss(true, 10);
        check(p.gain(11) == AudioInterruptionPolicy.NONE && !p.retainFocus());
        check(!p.canResume(token, 11));
        token = p.transientLoss(true, 11);
        check(p.transientLoss(false, 12) == AudioInterruptionPolicy.NONE);
        check(!p.retainFocus() && !p.owns(token, 12));
        // Les jetons ne sont pas réutilisés après annulation ou réouverture.
        newer = p.transientLoss(true, 12);
        check(newer > token && !p.owns(token, 12));
        check(p.gain(12) == newer && !p.canResume(newer, 13));
        p.resumed(token, 12);
        check(p.canResume(newer, 12));
        System.out.println("OK : reprise conditionnelle, pause préalable, interruptions imbriquées, GAIN précoce, annulations et piste différente.");
    }
}
