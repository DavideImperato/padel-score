package com.padel.scorebot

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.google.android.gms.wearable.MessageClient
import com.google.android.gms.wearable.PutDataMapRequest
import com.google.android.gms.wearable.Wearable
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

/**
 * Il motore partita vive in Flutter sul telefono. Questo bridge inoltra solo
 * comandi provenienti dai nodi Wear abbinati; non applica punti in Kotlin.
 * I comandi vengono elaborati solo mentre l'engine Flutter e' attivo.
 */
class WearPhoneBridge(
    private val context: Context,
    messenger: BinaryMessenger,
) : MessageClient.OnMessageReceivedListener {
    private val channel = MethodChannel(messenger, "padel_score_board/wear_os")
    private val wearableMessages = Wearable.getMessageClient(context)
    private val wearableData = Wearable.getDataClient(context)
    private val mainHandler = Handler(Looper.getMainLooper())
    @Volatile private var latestMatchPayload: String? = null
    private var closed = false

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "publishMatch" -> {
                    val payload = call.arguments as? String
                    if (payload.isNullOrBlank()) {
                        result.error("INVALID_STATE", "Stato Wear OS vuoto", null)
                    } else {
                        latestMatchPayload = payload
                        val request = PutDataMapRequest.create("/psb/match")
                        request.dataMap.putString("payload", payload)
                        request.dataMap.putLong("updatedAt", System.currentTimeMillis())
                        wearableData.putDataItem(request.asPutDataRequest().setUrgent())
                            .addOnFailureListener { Log.w("PSB-Wear", "Invio stato non riuscito", it) }
                        result.success(null)
                    }
                }
                else -> result.notImplemented()
            }
        }
        wearableMessages.addListener(this)
            .addOnFailureListener { Log.w("PSB-Wear", "Listener messaggi non attivo", it) }
    }

    override fun onMessageReceived(event: com.google.android.gms.wearable.MessageEvent) {
        if (closed) return
        if (event.path == "/psb/ping") {
            wearableMessages.sendMessage(event.sourceNodeId, "/psb/pong", event.data)
                .addOnFailureListener { Log.w("PSB-Wear", "Ping non riuscito", it) }
            return
        }
        if (event.path == "/psb/request_snapshot") {
            latestMatchPayload?.let { payload ->
                wearableMessages.sendMessage(event.sourceNodeId, "/psb/snapshot",
                    payload.toByteArray(Charsets.UTF_8))
                    .addOnFailureListener { Log.w("PSB-Wear", "Snapshot non recapitato", it) }
            }
            return
        }
        if (event.path != "/psb/command") return
        val nodeId = event.sourceNodeId
        val raw = try { String(event.data, Charsets.UTF_8) } catch (_: Exception) { return }
        if (raw.length > 2048) return
        val commandId = try { JSONObject(raw).optString("commandId") } catch (_: Exception) { "" }
        mainHandler.post {
            if (closed) return@post
            channel.invokeMethod("watchCommand", raw, object : MethodChannel.Result {
                override fun success(value: Any?) {
                    val response = value as? String
                        ?: "{\"ok\":false,\"code\":\"invalid_response\"}"
                    sendAck(nodeId, commandId, response)
                }
                override fun error(code: String, message: String?, details: Any?) {
                    sendAck(nodeId, commandId, JSONObject().put("ok", false)
                        .put("code", "flutter_error").toString())
                }
                override fun notImplemented() {
                    sendAck(nodeId, commandId, JSONObject().put("ok", false)
                        .put("code", "not_implemented").toString())
                }
            })
        }
    }

    private fun sendAck(nodeId: String, commandId: String, response: String) {
        val ack = try { JSONObject(response) } catch (_: Exception) { JSONObject() }
        ack.put("commandId", commandId)
        wearableMessages.sendMessage(nodeId, "/psb/ack", ack.toString().toByteArray(Charsets.UTF_8))
            .addOnFailureListener { Log.w("PSB-Wear", "Conferma non recapitata", it) }
    }

    fun dispose() {
        closed = true
        channel.setMethodCallHandler(null)
        wearableMessages.removeListener(this)
    }
}
