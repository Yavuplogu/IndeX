package fr.index.index_windows

import android.app.*
import android.content.*
import android.content.pm.ServiceInfo
import android.media.*
import android.media.session.MediaSession
import android.media.session.PlaybackState
import android.net.Uri
import android.os.*
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/** Propriétaire du lecteur et de la session système ; les règles d'écoute restent en Dart. */
class IndexPlaybackService : Service() {
    companion object {
        private const val CHANNEL = "index-listening"
        private const val NOTIFICATION = 6003
        private const val ACTION = "fr.index.index_windows.MEDIA_"
    }
    private val handler = Handler(Looper.getMainLooper())
    private var player: MediaPlayer? = null
    private lateinit var media: MediaSession
    private lateinit var wake: PowerManager.WakeLock
    private lateinit var audio: AudioManager
    private var focus: AudioFocusRequest? = null
    private var prepared = false
    private var ended = false
    private var foreground = false
    private var audioError: String? = null
    private var preparing: MethodChannel.Result? = null
    private var seeking: MethodChannel.Result? = null
    private var title = "IndeX"
    private var date = ""
    private var pulsePending = false
    private var pendingControls = 0
    private var destroyed = false
    private var engineClosed = false
    private var pauseEpoch = 0
    private var sourceRevision = 0L
    private val interruption = AudioInterruptionPolicy()
    private val noisy = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) { interrupt() }
    }
    private val focusListener = AudioManager.OnAudioFocusChangeListener { change ->
        handler.post {
            if (destroyed || engineClosed) return@post
            when (change) {
                AudioManager.AUDIOFOCUS_LOSS_TRANSIENT, AudioManager.AUDIOFOCUS_LOSS_TRANSIENT_CAN_DUCK -> {
                    // Pause des paroles pendant notification/appel, sans abandonner le focus reçu.
                    val token = interruption.transientLoss(prepared && audioError == null && player?.isPlaying == true, sourceRevision)
                    if (token != AudioInterruptionPolicy.NONE) control("focusPause", token, pauseFirst = true)
                }
                AudioManager.AUDIOFOCUS_GAIN -> {
                    val token = interruption.gain(sourceRevision)
                    if (token != AudioInterruptionPolicy.NONE) {
                        if (!wake.isHeld) wake.acquire()
                        control("focusResume", token)
                    }
                }
                AudioManager.AUDIOFOCUS_LOSS -> interrupt()
            }
        }
    }
    private val pulse = object : Runnable {
        override fun run() {
            if (prepared && audioError == null && (player?.isPlaying == true || ended) && !pulsePending) {
                pulsePending = true
                control("tick", complete = { pulsePending = false })
            }
            handler.postDelayed(this, 1000)
        }
    }
    override fun onCreate() {
        super.onCreate()
        audio = getSystemService(AUDIO_SERVICE) as AudioManager
        wake = (getSystemService(POWER_SERVICE) as PowerManager).newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "$packageName:lecture").apply { setReferenceCounted(false) }
        if (Build.VERSION.SDK_INT >= 26) {
            (getSystemService(NOTIFICATION_SERVICE) as NotificationManager).createNotificationChannel(
                NotificationChannel(CHANNEL, "Écoute IndeX", NotificationManager.IMPORTANCE_LOW).apply { setSound(null, null) }
            )
        }
        media = MediaSession(this, "IndeX").apply {
            setFlags(MediaSession.FLAG_HANDLES_MEDIA_BUTTONS or MediaSession.FLAG_HANDLES_TRANSPORT_CONTROLS)
            setCallback(object : MediaSession.Callback() {
                override fun onPlay() { control("play") }
                override fun onPause() { interrupt() }
                override fun onStop() { control("stop", pauseFirst = true) }
                override fun onSkipToNext() { control("next") }
                override fun onSkipToPrevious() { control("previous") }
                override fun onFastForward() { control("forward") }
                override fun onRewind() { control("rewind") }
                override fun onSeekTo(pos: Long) { control("seek", pos) }
            }, handler)
            setPlaybackToLocal(AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_MEDIA).setContentType(AudioAttributes.CONTENT_TYPE_SPEECH).build())
            setSessionActivity(contentIntent())
            isActive = true
        }
        val filter = IntentFilter(AudioManager.ACTION_AUDIO_BECOMING_NOISY)
        if (Build.VERSION.SDK_INT >= 33) registerReceiver(noisy, filter, RECEIVER_NOT_EXPORTED)
        else { @Suppress("DEPRECATION") registerReceiver(noisy, filter) }
        AndroidAudioBridge.attach(this)
    }
    override fun onBind(intent: Intent?) = null
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (engineClosed || !AndroidAudioBridge.ready) { stopSelf(); return START_NOT_STICKY }
        try {
            val action = intent?.action?.removePrefix(ACTION)
            if (action == null || action in listOf("play", "next", "previous")) ensureForeground()
            when (action) {
                "play", "next", "previous" -> control(action)
                "pause" -> interrupt()
                "stop" -> control("stop", pauseFirst = true)
            }
        } catch (e: Exception) { audioError = e.toString(); pauseNative() }
        // Pas de redémarrage/autoplay à partir d'un état supposé après kill du processus.
        return START_NOT_STICKY
    }
    fun diagnostics(): Map<String, Any> = mapOf(
        "running" to true, "prepared" to prepared, "foreground" to foreground,
        "wakeHeld" to wake.isHeld, "playing" to (prepared && audioError == null && player?.isPlaying == true),
        "title" to title, "date" to date, "error" to (audioError ?: "")
    )
    private fun contentIntent(): PendingIntent = PendingIntent.getActivity(this, 0,
        Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    private fun actionIntent(action: String): PendingIntent = PendingIntent.getService(this, action.hashCode(),
        Intent(this, IndexPlaybackService::class.java).setAction(ACTION + action), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    private fun notification(): Notification {
        val playing = prepared && audioError == null && player?.isPlaying == true
        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, CHANNEL) else Notification.Builder(this)
        return builder.setSmallIcon(R.drawable.ic_stat_index).setContentTitle(if (date.isEmpty()) title else "$title · $date")
            .setContentText("Rendez-vous avec X").setContentIntent(contentIntent()).setOnlyAlertOnce(true)
            .setVisibility(Notification.VISIBILITY_PUBLIC).setShowWhen(false).setOngoing(playing)
            .addAction(Notification.Action.Builder(android.R.drawable.ic_media_previous, "Épisode précédent", actionIntent("previous")).build())
            .addAction(Notification.Action.Builder(if (playing) android.R.drawable.ic_media_pause else android.R.drawable.ic_media_play,
                if (playing) "Pause" else "Lecture", actionIntent(if (playing) "pause" else "play")).build())
            .addAction(Notification.Action.Builder(android.R.drawable.ic_media_next, "Épisode suivant", actionIntent("next")).build())
            .addAction(Notification.Action.Builder(android.R.drawable.ic_menu_close_clear_cancel, "Arrêt", actionIntent("stop")).build())
            .setStyle(Notification.MediaStyle().setMediaSession(media.sessionToken).setShowActionsInCompactView(0, 1, 2)).build()
    }
    private fun ensureForeground() {
        val notice = notification()
        if (Build.VERSION.SDK_INT >= 29) startForeground(NOTIFICATION, notice, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK)
        else startForeground(NOTIFICATION, notice)
        foreground = true
    }
    private fun releaseWake() { if (wake.isHeld) wake.release() }
    private fun idle() {
        handler.removeCallbacks(pulse)
        if (!interruption.retainFocus()) {
            abandonFocus()
            if (foreground) { stopForeground(STOP_FOREGROUND_DETACH); foreground = false }
        }
        releaseWake()
        val manager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        if (media.isActive) manager.notify(NOTIFICATION, notification()) else manager.cancel(NOTIFICATION)
    }
    private fun publish() {
        val position = if (prepared && audioError == null) player?.currentPosition?.toLong() ?: 0L else 0L
        val playing = prepared && audioError == null && player?.isPlaying == true
        val state = when { audioError != null -> PlaybackState.STATE_ERROR; !prepared -> PlaybackState.STATE_BUFFERING; ended -> PlaybackState.STATE_STOPPED; playing -> PlaybackState.STATE_PLAYING; else -> PlaybackState.STATE_PAUSED }
        media.setPlaybackState(PlaybackState.Builder().setActions(
            PlaybackState.ACTION_PLAY or PlaybackState.ACTION_PAUSE or PlaybackState.ACTION_PLAY_PAUSE or PlaybackState.ACTION_STOP or
            PlaybackState.ACTION_SKIP_TO_NEXT or PlaybackState.ACTION_SKIP_TO_PREVIOUS or PlaybackState.ACTION_SEEK_TO or PlaybackState.ACTION_FAST_FORWARD or PlaybackState.ACTION_REWIND
        ).setState(state, position, if (playing) 1f else 0f, SystemClock.elapsedRealtime()).build())
        val manager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        if (media.isActive) manager.notify(NOTIFICATION, notification()) else manager.cancel(NOTIFICATION)
    }
    fun metadata(args: Map<*, *>) {
        if (engineClosed || destroyed) return
        title = args["title"] as? String ?: "IndeX"
        date = args["date"] as? String ?: ""
        media.setMetadata(MediaMetadata.Builder().putString(MediaMetadata.METADATA_KEY_TITLE, if (date.isEmpty()) title else "$title · $date")
            .putString(MediaMetadata.METADATA_KEY_ARTIST, "Rendez-vous avec X")
            .putString(MediaMetadata.METADATA_KEY_DISPLAY_TITLE, title)
            .putLong(MediaMetadata.METADATA_KEY_DURATION, if (prepared) player!!.duration.toLong() else 0).build())
        publish()
    }
    private fun control(action: String, value: Long? = null, pauseFirst: Boolean = false, complete: (Boolean) -> Unit = {}) {
        if (engineClosed || destroyed) { complete(false); return }
        if (action !in listOf("tick", "focusPause", "focusResume")) interruption.cancel()
        pendingControls++
        var completed = false
        val watchdog = Runnable {
            if (!completed && !destroyed) {
                completed = true; pendingControls--
                interruption.cancel()
                pauseNative()
                audioError = "Commande système non confirmée : lecture suspendue."
                idle(); publish()
                complete(false)
            }
        }
        handler.postDelayed(watchdog, 35000)
        if (pauseFirst) pauseNative(keepAwake = true)
        AndroidAudioBridge.emit(action, value) { ok ->
            if (destroyed || engineClosed || completed) return@emit
            completed = true; handler.removeCallbacks(watchdog)
            pendingControls--
            if (!ok) { interruption.cancel(); pauseNative() }
            if (pendingControls == 0 && (!prepared || audioError != null || player?.isPlaying != true)) idle()
            complete(ok)
        }
    }

    private fun interrupt() { interruption.cancel(); control("pause", pauseFirst = true) }
    private fun pauseNative(keepAwake: Boolean = false) {
        try { if (prepared && player?.isPlaying == true) player?.pause() }
        catch (_: Exception) { player?.release(); player = null; prepared = false }
        // Conserver le CPU jusqu'au checkpoint Dart, ou à défaut libérer après 5 s.
        if (!wake.isHeld) wake.acquire()
        val epoch = ++pauseEpoch
        if (!keepAwake) handler.postDelayed({
            if (!destroyed && epoch == pauseEpoch && pendingControls == 0 && (audioError != null || player?.isPlaying != true)) idle()
        }, 5000)
        publish()
    }
    private fun abandonFocus() {
        if (Build.VERSION.SDK_INT >= 26) focus?.let { audio.abandonAudioFocusRequest(it) }
        else { @Suppress("DEPRECATION") audio.abandonAudioFocus(focusListener) }
        focus = null
    }
    private fun cancelPending() {
        preparing?.error("audio_replaced", "Ouverture remplacée ou libérée.", null); preparing = null
        seeking?.error("audio_replaced", "Déplacement remplacé ou libéré.", null); seeking = null
    }
    private fun startPlayback(): Boolean {
        check(prepared && audioError == null) { audioError ?: "Audio non préparé." }
        // La réécoute passe par open en Dart ; un seek au terme ne doit pas repartir à zéro.
        if (ended) return false
        if (player?.isPlaying == true) return true
        pauseEpoch++
        ensureForeground() // Android 15 : FGS avant la demande de focus.
        val granted = if (Build.VERSION.SDK_INT >= 26) {
            focus = focus ?: AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN).setAudioAttributes(AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_MEDIA).setContentType(AudioAttributes.CONTENT_TYPE_SPEECH).build()).setWillPauseWhenDucked(true).setOnAudioFocusChangeListener(focusListener, handler).build()
            audio.requestAudioFocus(focus!!)
        } else { @Suppress("DEPRECATION") audio.requestAudioFocus(focusListener, AudioManager.STREAM_MUSIC, AudioManager.AUDIOFOCUS_GAIN) }
        check(granted == AudioManager.AUDIOFOCUS_REQUEST_GRANTED) { "Priorité audio refusée." }
        ended = false; player!!.start(); if (!wake.isHeld) wake.acquire()
        handler.removeCallbacks(pulse); handler.postDelayed(pulse, 1000)
        publish()
        return true
    }
    fun command(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "open" -> {
                    interruption.cancel()
                    pauseEpoch++; sourceRevision++
                    val uri = Uri.parse(call.arguments as String)
                    require(uri.scheme == "content") { "URI locale SAF requise." }
                    cancelPending(); player?.release(); player = null; prepared = false; ended = false; audioError = null
                    title = "IndeX"; date = ""; media.isActive = true
                    metadata(mapOf("title" to title, "date" to date))
                    ensureForeground()
                    if (!wake.isHeld) wake.acquire()
                    preparing = result
                    player = MediaPlayer()
                    player!!.apply {
                        setAudioAttributes(AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_MEDIA).setContentType(AudioAttributes.CONTENT_TYPE_SPEECH).build())
                        setWakeMode(this@IndexPlaybackService, PowerManager.PARTIAL_WAKE_LOCK)
                        setDataSource(this@IndexPlaybackService, uri)
                        setOnPreparedListener { ready ->
                            if (ready !== player) return@setOnPreparedListener
                            prepared = true
                            val pending = preparing; preparing = null
                            metadata(mapOf("title" to title, "date" to date))
                            pending?.success(null)
                        }
                        setOnCompletionListener { completed ->
                            if (completed !== player) return@setOnCompletionListener
                            interruption.cancel()
                            ended = true; publish()
                            val finished = player
                            val revision = sourceRevision
                            control("tick", complete = { ok ->
                                if (player === finished && ended && sourceRevision == revision) { if (!ok) audioError = "Suivi de fin non confirmé."; idle(); publish() }
                            })
                            handler.postDelayed({ if (player === finished && ended && sourceRevision == revision) idle() }, 5000)
                        }
                        setOnErrorListener { failed, what, extra ->
                            if (failed !== player) return@setOnErrorListener true
                            interruption.cancel()
                            audioError = "Audio indisponible ($what/$extra)."
                            preparing?.error("audio_prepare", audioError, null); preparing = null
                            seeking?.error("audio_seek", audioError, null); seeking = null
                            ended = false; pauseNative(); control("tick"); true
                        }
                        prepareAsync()
                    }
                    return
                }
                "play" -> { interruption.cancel(); startPlayback() }
                "pauseTransient" -> {
                    val token = (call.arguments as Number).toLong()
                    val valid = interruption.owns(token, sourceRevision)
                    if (valid) pauseNative()
                    result.success(valid); return
                }
                "resumeAfterInterruption" -> {
                    val token = (call.arguments as Number).toLong()
                    if (!interruption.canResume(token, sourceRevision)) { result.success(false); return }
                    val resumed = startPlayback()
                    interruption.resumed(token, sourceRevision)
                    if (!resumed) idle()
                    result.success(resumed); return
                }
                "checkpointed" -> { if (pendingControls == 0 && (!prepared || audioError != null || player?.isPlaying != true)) idle() }
                "pause" -> { interruption.cancel(); pauseNative() }
                "seek" -> {
                    interruption.cancel()
                    sourceRevision++
                    check(prepared && audioError == null) { audioError ?: "Audio non préparé." }
                    val value = (call.arguments as Number).toLong(); require(value in 0..Int.MAX_VALUE.toLong())
                    seeking?.error("audio_seek", "Déplacement remplacé.", null); seeking = result
                    player!!.setOnSeekCompleteListener { if (it !== player) return@setOnSeekCompleteListener; it.setOnSeekCompleteListener(null); val pending = seeking; seeking = null; publish(); pending?.success(null) }
                    if (Build.VERSION.SDK_INT >= 26) player!!.seekTo(value, MediaPlayer.SEEK_CLOSEST) else player!!.seekTo(value.toInt())
                    ended = false; return
                }
                "volume" -> { val value = (call.arguments as Number).toFloat().coerceIn(0f, 1f); player?.setVolume(value, value) }
                "snapshot" -> {
                    check(prepared && audioError == null) { audioError ?: "Audio non préparé." }
                    result.success(mapOf("position" to player!!.currentPosition, "duration" to player!!.duration, "playing" to player!!.isPlaying, "ended" to ended)); return
                }
                "release" -> {
                    interruption.cancel()
                    pauseEpoch++; sourceRevision++
                    destroyPlayer(); media.isActive = false
                    stopForeground(STOP_FOREGROUND_REMOVE); foreground = false
                    (getSystemService(NOTIFICATION_SERVICE) as NotificationManager).cancel(NOTIFICATION)
                    // Garder le service réutilisable jusqu'à onDestroy : pas de course stopSelf/open.
                }
                else -> { result.notImplemented(); return }
            }
            result.success(null)
        } catch (e: Exception) {
            interruption.cancel()
            audioError = e.toString()
            // Échec fermé : aucune lecture après une commande native refusée.
            try { pauseNative() } catch (_: Exception) { releaseWake() }
            if (preparing === result) preparing = null
            if (seeking === result) seeking = null
            result.error("audio_native", e.toString(), null)
        }
    }
    private fun destroyPlayer() {
        interruption.cancel()
        handler.removeCallbacks(pulse)
        cancelPending(); player?.release(); player = null; prepared = false; ended = false
        abandonFocus(); releaseWake()
    }
    fun onEngineClosed() {
        engineClosed = true
        handler.removeCallbacksAndMessages(null)
        destroyPlayer(); media.isActive = false
        stopForeground(STOP_FOREGROUND_REMOVE); foreground = false
        (getSystemService(NOTIFICATION_SERVICE) as NotificationManager).cancel(NOTIFICATION)
    }
    override fun onDestroy() {
        destroyed = true
        handler.removeCallbacksAndMessages(null)
        unregisterReceiver(noisy)
        destroyPlayer(); media.isActive = false; media.release()
        (getSystemService(NOTIFICATION_SERVICE) as NotificationManager).cancel(NOTIFICATION)
        AndroidAudioBridge.detach(this)
        if (!IndexEngine.closing && !engineClosed) AndroidAudioBridge.emit("backendLost")
        super.onDestroy()
    }
}
