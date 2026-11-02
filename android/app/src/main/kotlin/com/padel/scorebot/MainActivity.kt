package com.padel.scorebot

import android.content.Context
import android.media.AudioManager
import android.view.KeyEvent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlin.math.roundToInt

/** I tasti volume diventano impulsi SOLO durante il match e con telecomando ON. */
class MainActivity : FlutterActivity() {
    private var captureVolume = false
    private var remoteChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val channel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "padel_score_board/android_remote_buttons"
        )
        remoteChannel = channel
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "setEnabled" -> {
                    captureVolume = call.argument<Boolean>("enabled") == true
                    result.success(captureVolume)
                }
                "setMusicVolume" -> {
                    try {
                        val fraction = call.argument<Double>("fraction")
                        if (fraction == null || fraction.isNaN() || fraction < 0.0 || fraction > 1.0) {
                            result.error("INVALID_VOLUME", "Volume non valido", null)
                        } else {
                            val audio = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                            val maxVolume = audio.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
                            val level = (maxVolume * fraction).roundToInt().coerceIn(0, maxVolume)
                            audio.setStreamVolume(AudioManager.STREAM_MUSIC, level, AudioManager.FLAG_SHOW_UI)
                            result.success(true)
                        }
                    } catch (error: Exception) {
                        result.error("AUDIO_UNAVAILABLE", error.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        val isVolumeKey = event.keyCode == KeyEvent.KEYCODE_VOLUME_UP ||
            event.keyCode == KeyEvent.KEYCODE_VOLUME_DOWN
        if (captureVolume && isVolumeKey) {
            // Un solo impulso per pressione fisica: scarta repeat e KeyUp.
            if (event.action == KeyEvent.ACTION_DOWN && event.repeatCount == 0) {
                remoteChannel?.invokeMethod("pulse", null)
            }
            return true
        }
        return super.dispatchKeyEvent(event)
    }

    override fun onPause() {
        captureVolume = false
        super.onPause()
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        captureVolume = false
        remoteChannel?.setMethodCallHandler(null)
        remoteChannel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
