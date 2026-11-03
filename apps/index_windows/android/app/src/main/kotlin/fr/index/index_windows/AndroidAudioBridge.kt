package fr.index.index_windows

import android.content.Context
import android.content.Intent
import android.os.Build
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/** Canal de durée de vie moteur : aucune référence forte à l'Activity. */
object AndroidAudioBridge {
    private var channel: MethodChannel? = null
    val ready: Boolean get() = channel != null
    private var service: IndexPlaybackService? = null
    private val pending = mutableListOf<Pair<MethodCall, MethodChannel.Result>>()
    fun install(context: Context, engine: FlutterEngine) {
        if (channel != null) return
        val app = context.applicationContext
        channel = MethodChannel(engine.dartExecutor.binaryMessenger, "index/audio").also { channel ->
            channel.setMethodCallHandler { call, result ->
                try {
                    val current = service
                    when {
                        call.method == "diagnostics" -> result.success(current?.diagnostics() ?: mapOf("running" to false))
                        call.method == "metadata" -> { current?.metadata(call.arguments as Map<*, *>); result.success(null) }
                        current != null -> current.command(call, result)
                        call.method == "release" || call.method == "pause" || call.method == "checkpointed" -> result.success(null)
                        call.method == "open" -> {
                            pending.add(call to result)
                            try {
                                val intent = Intent(app, IndexPlaybackService::class.java)
                                if (Build.VERSION.SDK_INT >= 26) app.startForegroundService(intent) else app.startService(intent)
                            } catch (e: Exception) { pending.removeAll { it.second == result }; throw e }
                        }
                        else -> result.error("audio_native", "Aucune piste chargée.", null)
                    }
                } catch (e: Exception) { result.error("audio_native", e.toString(), null) }
            }
        }
    }
    fun attach(value: IndexPlaybackService) {
        service = value
        val work = pending.toList(); pending.clear()
        work.forEach { (call, result) -> value.command(call, result) }
    }
    fun detach(value: IndexPlaybackService) { if (service === value) service = null }
    fun emit(action: String, value: Long? = null, complete: (Boolean) -> Unit = {}) {
        val target = channel
        if (target == null) { complete(false); return }
        target.invokeMethod("control", mapOf("action" to action, "value" to value), object : MethodChannel.Result {
            override fun success(result: Any?) { complete(true) }
            override fun error(code: String, message: String?, details: Any?) { complete(false) }
            override fun notImplemented() { complete(false) }
        })
    }
    fun dispose() {
        service?.onEngineClosed(); service = null
        channel?.setMethodCallHandler(null); channel = null
        pending.forEach { it.second.error("audio_closed", "Application fermée.", null) }; pending.clear()
    }
}
