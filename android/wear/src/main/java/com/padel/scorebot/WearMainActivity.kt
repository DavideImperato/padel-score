package com.padel.scorebot

import android.app.Activity
import android.app.AlertDialog
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.text.TextUtils
import android.view.GestureDetector
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.widget.ViewFlipper
import android.widget.Button
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import com.google.android.gms.wearable.DataClient
import com.google.android.gms.wearable.DataEvent
import com.google.android.gms.wearable.DataEventBuffer
import com.google.android.gms.wearable.DataItem
import com.google.android.gms.wearable.DataMapItem
import com.google.android.gms.wearable.MessageClient
import com.google.android.gms.wearable.MessageEvent
import com.google.android.gms.wearable.Wearable
import org.json.JSONObject
import java.util.ArrayDeque
import java.util.Locale
import java.util.UUID
import kotlin.math.abs

/**
 * Padel Score Board per Wear OS. Le quattro pagine replicano le funzioni della
 * WatchConnectionView di watchOS. Il telefono Flutter resta la sola fonte del
 * punteggio; qui non viene eseguita nessuna logica di scoring.
 *
 * Gli ID comando sono unici, la coda e' FIFO (max 5), non ci sono retry
 * automatici e in caso di ACK incerto i comandi vengono bloccati fino a una
 * risincronizzazione esplicita con snapshot aggiornato.
 */
class WearMainActivity : Activity(), DataClient.OnDataChangedListener,
    MessageClient.OnMessageReceivedListener {

    private val lime = Color.rgb(204, 255, 0)
    private val cyan = Color.rgb(0, 224, 255)
    private val ink = Color.rgb(10, 19, 38)
    private val muted = Color.rgb(170, 188, 203)
    private val tile = Color.rgb(28, 39, 58)
    private val red = Color.rgb(178, 60, 65)
    private val handler = Handler(Looper.getMainLooper())

    private data class QueuedCommand(val id: String, val matchId: String, val action: String)
    private val commandQueue = ArrayDeque<QueuedCommand>()
    private var activeCommand: QueuedCommand? = null
    private var timeoutRunnable: Runnable? = null
    private var requiresResync = false
    private var resyncAcknowledged = false
    private var uncertainBaseline = 0L

    private var matchState: JSONObject? = null
    private var lastSentAt = -1L
    private var receivedAt = 0L
    private var phoneReachable = false
    private var note = "Apri una partita sul telefono"
    private var currentPage = 0
    private var lastFinishedShown: String? = null
    private var pingId: String? = null
    private var lastNodeCheck = 0L

    private lateinit var pager: ViewFlipper
    private lateinit var pageNumber: TextView
    private lateinit var swipeDetector: GestureDetector
    private var clockLabel: TextView? = null

    private fun dp(value: Int) = (value * resources.displayMetrics.density).toInt()

    private fun shape(color: Int, radius: Int = 12): GradientDrawable =
        GradientDrawable().apply {
            setColor(color)
            cornerRadius = dp(radius).toFloat()
        }

    private fun text(value: String, size: Float = 11f, color: Int = Color.WHITE,
                     bold: Boolean = false): TextView = TextView(this).apply {
        text = value
        textSize = size
        setTextColor(color)
        gravity = Gravity.CENTER
        maxLines = 2
        ellipsize = TextUtils.TruncateAt.END
        includeFontPadding = false
        if (bold) setTypeface(null, Typeface.BOLD)
    }

    private fun button(value: String, bg: Int = tile, fg: Int = Color.WHITE,
                       height: Int = 36, enabled: Boolean = true,
                       onTap: () -> Unit): Button = Button(this).apply {
        text = value
        textSize = 11f
        isAllCaps = false
        setTextColor(fg)
        background = shape(bg)
        minHeight = dp(height)
        minimumHeight = dp(height)
        setPadding(dp(3), 0, dp(3), 0)
        isEnabled = enabled
        alpha = if (enabled) 1f else 0.40f
        setOnClickListener { onTap() }
    }

    private fun vertical(): LinearLayout = LinearLayout(this).apply {
        orientation = LinearLayout.VERTICAL
        gravity = Gravity.CENTER_HORIZONTAL
    }

    private fun horizontal(): LinearLayout = LinearLayout(this).apply {
        orientation = LinearLayout.HORIZONTAL
        gravity = Gravity.CENTER_VERTICAL
    }

    private fun line(parent: LinearLayout, label: String, color: Int = Color.WHITE,
                     size: Float = 11f, bold: Boolean = false) {
        parent.addView(text(label, size, color, bold), LinearLayout.LayoutParams(-1, -2).apply {
            setMargins(0, dp(3), 0, dp(3))
        })
    }

    private fun spacer(parent: LinearLayout, size: Int = 5) {
        parent.addView(View(this), LinearLayout.LayoutParams(1, dp(size)))
    }

    private fun stackedPage(build: (LinearLayout) -> Unit): ScrollView {
        val root = vertical().apply {
            // Inset per schermo rotondo: i controlli a sinistra/destra non
            // devono finire sotto il bordo, soprattutto nella zona superiore.
            setPadding(dp(18), dp(4), dp(18), dp(12))
        }
        build(root)
        return ScrollView(this).apply {
            isFillViewport = false
            isVerticalScrollBarEnabled = false
            addView(root)
            setBackgroundColor(ink)
        }
    }

    private fun addFullButton(parent: LinearLayout, label: String,
                              bg: Int = tile, fg: Int = Color.WHITE,
                              enabled: Boolean = true, onTap: () -> Unit) {
        parent.addView(button(label, bg, fg, 37, enabled, onTap),
            LinearLayout.LayoutParams(-1, dp(37)).apply {
                setMargins(0, dp(4), 0, dp(2))
            })
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.statusBarColor = ink
        window.navigationBarColor = ink
        window.decorView.setBackgroundColor(ink)
        swipeDetector = GestureDetector(this, object : GestureDetector.SimpleOnGestureListener() {
            override fun onDown(event: MotionEvent): Boolean = true
            override fun onFling(e1: MotionEvent?, e2: MotionEvent,
                                 velocityX: Float, velocityY: Float): Boolean {
                if (e1 == null) return false
                val dx = e2.x - e1.x
                val dy = e2.y - e1.y
                if (abs(dx) < dp(35) || abs(dx) < abs(dy) * 1.3f) return false
                if (dx < 0) changePage(1) else changePage(-1)
                return true
            }
        })

        val screen = vertical().apply { setBackgroundColor(ink) }
        val header = horizontal().apply {
            setPadding(dp(39), dp(7), dp(39), dp(1))
        }
        header.addView(button("‹", ink, muted, 27, true) { changePage(-1) },
            LinearLayout.LayoutParams(dp(29), dp(27)))
        pageNumber = text("● ○ ○ ○", 12f, lime, true)
        header.addView(pageNumber, LinearLayout.LayoutParams(0, dp(27), 1f))
        header.addView(button("›", ink, muted, 27, true) { changePage(1) },
            LinearLayout.LayoutParams(dp(29), dp(27)))
        screen.addView(header, LinearLayout.LayoutParams(-1, dp(35)))
        pager = ViewFlipper(this).apply { setBackgroundColor(ink) }
        screen.addView(pager, LinearLayout.LayoutParams(-1, 0, 1f))
        setContentView(screen)
        refreshUi()
    }

    override fun dispatchTouchEvent(event: MotionEvent): Boolean {
        if (::swipeDetector.isInitialized) swipeDetector.onTouchEvent(event)
        return super.dispatchTouchEvent(event)
    }

    private fun changePage(delta: Int) {
        currentPage = (currentPage + delta + 4) % 4
        if (::pager.isInitialized && pager.childCount == 4) pager.displayedChild = currentPage
        updatePageIndicator()
    }

    private fun updatePageIndicator() {
        if (!::pageNumber.isInitialized) return
        pageNumber.text = (0..3).joinToString(" ") { if (it == currentPage) "●" else "○" }
    }

    private fun stateString(key: String, default: String = "") =
        matchState?.optString(key, default) ?: default

    private fun stateBool(key: String): Boolean = matchState?.optBoolean(key, false) == true
    private fun stateInt(key: String): Int = matchState?.optInt(key, 0) ?: 0
    private fun status(): String = stateString("status", "idle")
    private fun pendingCount() = commandQueue.size + if (activeCommand == null) 0 else 1
    private fun canControl() = phoneReachable && !requiresResync && pendingCount() < 5
    private fun canScore() = canControl() && status() == "live"
    private fun canUndo() = canControl() && stateBool("canUndo") &&
        (status() == "live" || status() == "finished")

    private fun timerValue(): String {
        val base = stateInt("elapsedSeconds").coerceAtLeast(0)
        val running = stateBool("timerRunning") && status() == "live" && phoneReachable
        val extra = if (running && receivedAt > 0L) {
            ((SystemClock.elapsedRealtime() - receivedAt) / 1000L).coerceAtLeast(0L).toInt()
        } else 0
        val seconds = base + extra
        return if (seconds >= 3600) String.format(Locale.ITALY, "%02d:%02d:%02d",
            seconds / 3600, (seconds % 3600) / 60, seconds % 60)
        else String.format(Locale.ITALY, "%02d:%02d", seconds / 60, seconds % 60)
    }

    private fun ruleLabel(): String {
        if (stateBool("isMatchTieBreak")) return "MATCH TB"
        if (stateBool("isTieBreak")) return "TIE-BREAK"
        val rule = stateString("rules")
        return when {
            rule.contains("Star", true) -> "STAR"
            rule.contains("vantaggi", true) &&
                (rule.contains("d’oro", true) || rule.contains("d'oro", true)) -> "1 V.+ORO"
            rule.contains("d’oro", true) || rule.contains("d'oro", true) -> "ORO"
            else -> "VANT."
        }
    }

    private fun scoreTile(name: String, points: String, color: Int,
                          serving: Boolean, action: String): View {
        val content = vertical().apply {
            gravity = Gravity.CENTER
            setPadding(dp(3), dp(6), dp(3), dp(6))
            background = shape(tile, 11).apply {
                if (serving) setStroke(dp(1), color)
            }
            isEnabled = canScore()
            alpha = if (isEnabled) 1f else 0.46f
            isClickable = true
            contentDescription = "Punto $name, punteggio $points"
            setOnClickListener { queueCommand(action) }
        }
        content.addView(text(name.uppercase(Locale.ITALY).take(18), 10f, Color.WHITE, true))
        content.addView(text(points, 33f, color, true),
            LinearLayout.LayoutParams(-1, dp(43)))
        return content
    }

    private fun scorePage(): ScrollView = stackedPage { page ->
        line(page, "PADEL SCORE", lime, 13f, true)
        when (status()) {
            "idle" -> {
                line(page, if (phoneReachable) "Telefono collegato" else "Telefono non raggiungibile", muted, 10f)
                spacer(page, 9)
                line(page, "Pronto per giocare", Color.WHITE, 13f, true)
                addFullButton(page, "INIZIA MATCH", lime, Color.BLACK, canControl()) {
                    queueCommand("start_match")
                }
                addFullButton(page, "RISINCRONIZZA", enabled = phoneReachable) { requestSnapshot() }
            }
            "recovery" -> {
                line(page, "Riprendi prima la partita sul telefono", muted, 11f)
                addFullButton(page, "RISINCRONIZZA", enabled = phoneReachable) { requestSnapshot() }
            }
            else -> {
                // Undo resta in alto: non finisce sotto la cornice circolare.
                val quick = horizontal()
                val undo = button("↶ UNDO", tile, Color.WHITE, 33, canUndo()) {
                    queueCommand("undo")
                }
                quick.addView(undo, LinearLayout.LayoutParams(0, dp(33), 1.15f).apply {
                    rightMargin = dp(3)
                })
                val running = stateBool("timerRunning")
                quick.addView(button(if (running) "Ⅱ" else "▶", tile, Color.WHITE, 33,
                    canControl() && status() == "live") {
                    queueCommand(if (running) "pause_match" else "resume_match")
                }, LinearLayout.LayoutParams(0, dp(33), .65f).apply { rightMargin = dp(3) })
                quick.addView(button(ruleLabel(), tile, lime, 33,
                    canControl() && status() == "live") { chooseRules() },
                    LinearLayout.LayoutParams(0, dp(33), 1f))
                page.addView(quick, LinearLayout.LayoutParams(-1, dp(33)))
                spacer(page, 5)
                val stats = horizontal()
                val sets = text("SET ${stateInt("setsA")}-${stateInt("setsB")}", 10f)
                stats.addView(sets, LinearLayout.LayoutParams(0, -2, 1f))
                clockLabel = text(timerValue(), 10f, lime, true)
                stats.addView(clockLabel, LinearLayout.LayoutParams(0, -2, 1f))
                val games = text("GAME ${stateInt("gamesA")}-${stateInt("gamesB")}", 10f)
                stats.addView(games, LinearLayout.LayoutParams(0, -2, 1f))
                page.addView(stats)
                val serving = stateString("servingPlayer")
                val side = stateString("servingTeam")
                val serverColor = if (side == "B") cyan else lime
                line(page, if (status() == "finished") "PARTITA CONCLUSA" else
                    "Batte: ${serving.ifBlank { "–" }}", serverColor, 10f)
                val scores = horizontal()
                val a = scoreTile(stateString("teamA", "Squadra A"), stateString("pointsA", "0"),
                    lime, side == "A", "point_a")
                val b = scoreTile(stateString("teamB", "Squadra B"), stateString("pointsB", "0"),
                    cyan, side == "B", "point_b")
                val tileParams = { LinearLayout.LayoutParams(0, dp(75), 1f) }
                if (stateBool("sidesSwapped")) {
                    scores.addView(b, tileParams().apply { rightMargin = dp(3) })
                    scores.addView(a, tileParams())
                } else {
                    scores.addView(a, tileParams().apply { rightMargin = dp(3) })
                    scores.addView(b, tileParams())
                }
                page.addView(scores, LinearLayout.LayoutParams(-1, dp(75)))
                if (stateBool("isTieBreak")) {
                    line(page, if (stateBool("isMatchTieBreak")) "MATCH TIE-BREAK" else "TIE-BREAK", muted, 9f)
                }
                if (status() == "finished") {
                    addFullButton(page, "RISULTATO FINALE", lime, Color.BLACK) { showFinishedDialog() }
                }
                if (!phoneReachable) line(page, "Ultimo risultato ricevuto · offline", muted, 9f)
                if (requiresResync) line(page, "Verifica sul telefono e risincronizza", red, 9f)
            }
        }
    }

    private fun controlsPage(): ScrollView = stackedPage { page ->
        line(page, "CONTROLLI MATCH", lime, 13f, true)
        if (status() == "live") {
            addFullButton(page, "CAMBIA CAMPO", enabled = canControl()) {
                queueCommand("switch_sides")
            }
            addFullButton(page, "CAMBIA BATTITORE", enabled =
                canControl() && stateBool("canChangeServer")) { confirmServer() }
            if (!stateBool("canChangeRules")) {
                line(page, "Regola bloccata dopo il primo punto", muted, 9f)
            } else {
                addFullButton(page, "TIPO DI PUNTEGGIO", enabled = canControl()) { chooseRules() }
            }
            spacer(page)
            addFullButton(page, "SALVA E INTERROMPI", red, enabled = canControl()) { confirmEnd() }
        } else if (status() == "finished") {
            addFullButton(page, "SALVA RISULTATO", lime, Color.BLACK, canControl()) { confirmEnd() }
            addFullButton(page, "RISULTATO FINALE") { showFinishedDialog() }
        } else {
            line(page, "Avvia una partita per attivare i controlli", muted, 11f)
        }
        addFullButton(page, "RISINCRONIZZA", enabled = phoneReachable) { requestSnapshot() }
    }

    private fun detailsPage(): ScrollView = stackedPage { page ->
        line(page, "DETTAGLI PARTITA", lime, 13f, true)
        if (status() == "idle" || matchState == null) {
            line(page, "Avvia una partita sul telefono", muted)
            return@stackedPage
        }
        line(page, "${stateString("teamA")} vs ${stateString("teamB")}", Color.WHITE, 12f, true)
        val players = matchState?.optJSONArray("players")
        if (players != null) {
            for (i in 0 until players.length()) {
                line(page, "${i+1}. ${players.optString(i)}", muted, 10f)
            }
        }
        spacer(page, 5)
        line(page, stateString("rules"), lime, 11f)
        line(page, "${stateInt("bestOfSets")} set · " +
            (if (stateBool("shortSets")) "Mini-set" else "Set standard"), muted, 10f)
        if (stateBool("decidingMatchTieBreak")) {
            line(page, "Tie-break decisivo a ${stateInt("decidingTieBreakPoints")}", muted, 10f)
        }
        line(page, "Durata: ${timerValue()}", muted, 10f)
        val sets = matchState?.optJSONArray("sets")
        if (sets != null && sets.length() > 0) {
            spacer(page, 5)
            for (i in 0 until sets.length()) {
                val set = sets.optJSONObject(i) ?: continue
                val result = if (set.optBoolean("matchTieBreak"))
                    "MTB ${set.optInt("tieBreakA")}-${set.optInt("tieBreakB")}" else
                    "${set.optInt("gamesA")}-${set.optInt("gamesB")}"
                line(page, "Set ${i+1}: $result", Color.WHITE, 10f)
            }
        }
        val event = stateString("lastEvent")
        if (event.isNotBlank()) line(page, event, muted, 9f)
        if (status() == "finished") addFullButton(page, "STATISTICHE", enabled = true) {
            showStatsDialog()
        }
    }

    private fun connectionPage(): ScrollView = stackedPage { page ->
        line(page, "CONNESSIONE", lime, 13f, true)
        line(page, if (phoneReachable) "● Smartphone raggiungibile"
            else "○ Smartphone non raggiungibile",
            if (phoneReachable) lime else red, 11f)
        line(page, "Ultimo stato: ${if (lastSentAt > 0) "ricevuto" else "assente"}", muted, 10f)
        if (requiresResync) line(page,
            "Comando senza conferma. Controlla il punteggio sul telefono.", red, 10f)
        addFullButton(page, "VERIFICA COLLEGAMENTO") { pingPhone() }
        addFullButton(page, "RISINCRONIZZA", enabled = phoneReachable) { requestSnapshot() }
        if (note.isNotBlank()) line(page, note, muted, 10f)
        line(page, "Punteggio ufficiale sul telefono Android", muted, 9f)
    }

    private fun refreshUi() {
        if (!::pager.isInitialized) return
        val previous = (pager.currentView as? ScrollView)?.scrollY ?: 0
        clockLabel = null
        pager.removeAllViews()
        pager.addView(scorePage())
        pager.addView(controlsPage())
        pager.addView(detailsPage())
        pager.addView(connectionPage())
        pager.displayedChild = currentPage
        updatePageIndicator()
        pager.post { (pager.currentView as? ScrollView)?.scrollTo(0, previous) }
    }

    private fun chooseRules() {
        if (!canControl() || status() != "live") return
        if (!stateBool("canChangeRules")) {
            AlertDialog.Builder(this).setTitle("Regola bloccata")
                .setMessage("Puoi cambiare la regola soltanto prima del primo punto.")
                .setPositiveButton("OK", null).show()
            return
        }
        val labels = arrayOf("Punto d'oro", "Star Point", "Un vantaggio + Punto d'oro",
            "Vantaggi tradizionali")
        val actions = arrayOf("rule_golden", "rule_star", "rule_one_advantage", "rule_traditional")
        AlertDialog.Builder(this).setTitle("Tipo di punteggio")
            .setItems(labels) { _, which -> queueCommand(actions[which]) }
            .setNegativeButton("Annulla", null).show()
    }

    private fun confirmServer() {
        if (!stateBool("canChangeServer")) return
        AlertDialog.Builder(this).setTitle("Cambiare battitore?")
            .setMessage("Consentito soltanto prima di iniziare il game, fuori dal tie-break.")
            .setPositiveButton("Conferma") { _, _ -> queueCommand("change_server") }
            .setNegativeButton("Annulla", null).show()
    }

    private fun confirmEnd() {
        val finished = status() == "finished"
        AlertDialog.Builder(this).setTitle(if (finished) "Salvare il risultato?" else "Terminare la partita?")
            .setMessage(if (finished) "Il risultato verra' salvato nello storico."
                else "La partita verra' salvata fra le Interrotte.")
            .setPositiveButton("Salva") { _, _ -> queueCommand("end_match") }
            .setNegativeButton("Annulla", null).show()
    }

    private fun showFinishedDialog() {
        if (status() != "finished") return
        val winner = if (stateString("winner") == "A") stateString("teamA") else stateString("teamB")
        val result = "Vincitori: $winner\nSet ${stateInt("setsA")}-${stateInt("setsB")}"
        AlertDialog.Builder(this).setTitle("PARTITA TERMINATA")
            .setMessage(result)
            .setPositiveButton(if (stateBool("tournamentMatch")) "Torna al torneo" else "Nuovo incontro") {
                _, _ -> queueCommand("new_match")
            }
            .setNeutralButton("Condividi") { _, _ -> queueCommand("share_result") }
            .setNegativeButton("Statistiche") { _, _ -> showStatsDialog() }
            .show()
    }

    private fun showStatsDialog() {
        val parts = mutableListOf(
            "${stateString("teamA")}: ${stateInt("setsA")} set",
            "${stateString("teamB")}: ${stateInt("setsB")} set",
            "Durata: ${timerValue()}"
        )
        val sets = matchState?.optJSONArray("sets")
        if (sets != null) {
            for (i in 0 until sets.length()) {
                val obj = sets.optJSONObject(i) ?: continue
                parts.add(if (obj.optBoolean("matchTieBreak"))
                    "Set ${i+1}: MTB ${obj.optInt("tieBreakA")}-${obj.optInt("tieBreakB")}" else
                    "Set ${i+1}: ${obj.optInt("gamesA")}-${obj.optInt("gamesB")}")
            }
        }
        AlertDialog.Builder(this).setTitle("STATISTICHE MATCH")
            .setMessage(parts.joinToString("\n"))
            .setPositiveButton("OK", null).show()
    }

    override fun onStart() {
        super.onStart()
        Wearable.getDataClient(this).addListener(this)
        Wearable.getMessageClient(this).addListener(this)
        refreshConnection()
        readStoredSnapshot()
        handler.post(tick)
    }

    override fun onStop() {
        handler.removeCallbacks(tick)
        Wearable.getDataClient(this).removeListener(this)
        Wearable.getMessageClient(this).removeListener(this)
        super.onStop()
    }

    private val tick = object : Runnable {
        override fun run() {
            clockLabel?.text = timerValue()
            if (SystemClock.elapsedRealtime() - lastNodeCheck >= 10000L) refreshConnection()
            handler.postDelayed(this, 1000L)
        }
    }

    private fun refreshConnection() {
        lastNodeCheck = SystemClock.elapsedRealtime()
        Wearable.getNodeClient(this).connectedNodes
            .addOnSuccessListener { nodes ->
                runOnUiThread {
                    val available = nodes.isNotEmpty()
                    if (phoneReachable != available) {
                        phoneReachable = available
                        refreshUi()
                    }
                }
            }
            .addOnFailureListener {
                runOnUiThread {
                    if (phoneReachable) { phoneReachable = false; refreshUi() }
                }
            }
    }

    private fun readStoredSnapshot() {
        Wearable.getDataClient(this).dataItems.addOnSuccessListener { items ->
            try {
                for (item in items) if (item.uri.path == "/psb/match") readItem(item)
            } finally { items.release() }
        }.addOnFailureListener { runOnUiThread { note = "Stato non disponibile"; refreshUi() } }
    }

    override fun onDataChanged(events: DataEventBuffer) {
        for (event in events) {
            if (event.type == DataEvent.TYPE_CHANGED && event.dataItem.uri.path == "/psb/match") {
                readItem(event.dataItem)
            }
        }
    }

    private fun readItem(item: DataItem) {
        val raw = try { DataMapItem.fromDataItem(item).dataMap.getString("payload") }
            catch (_: Exception) { null } ?: return
        onSnapshot(raw)
    }

    private fun onSnapshot(raw: String, fromPhoneRequest: Boolean = false) {
        val snapshot = try { JSONObject(raw) } catch (_: Exception) { return }
        if (snapshot.optInt("version", 0) != 1) return
        val freshTime = snapshot.optLong("sentAt", -1L)
        if (freshTime < lastSentAt) return
        val newStatus = snapshot.optString("status", "idle")
        if (newStatus !in setOf("idle", "live", "finished", "recovery")) return
        runOnUiThread {
            if (freshTime < lastSentAt) return@runOnUiThread
            val wasFinished = status() == "finished"
            lastSentAt = freshTime
            matchState = snapshot
            receivedAt = SystemClock.elapsedRealtime()
            if (requiresResync && resyncAcknowledged &&
                (freshTime > uncertainBaseline ||
                    (fromPhoneRequest && freshTime == uncertainBaseline))) {
                requiresResync = false
                resyncAcknowledged = false
                note = "Punteggio verificato"
            }
            if (newStatus == "live") lastFinishedShown = null
            refreshUi()
            if (newStatus == "finished" && (!wasFinished || lastFinishedShown != stateString("matchId"))) {
                lastFinishedShown = stateString("matchId")
                if (!isFinishing) showFinishedDialog()
            }
        }
    }

    override fun onMessageReceived(event: MessageEvent) {
        when (event.path) {
            "/psb/ack" -> {
                val reply = try { JSONObject(String(event.data, Charsets.UTF_8)) }
                    catch (_: Exception) { return }
                runOnUiThread { onAck(reply) }
            }
            "/psb/snapshot" -> onSnapshot(String(event.data, Charsets.UTF_8), fromPhoneRequest = true)
            "/psb/pong" -> {
                val pong = String(event.data, Charsets.UTF_8)
                runOnUiThread {
                    if (pong == pingId) { pingId = null; note = "Telefono risponde"; refreshUi() }
                }
            }
        }
    }

    private fun queueCommand(action: String) {
        val allowed = setOf("point_a", "point_b", "undo", "start_match", "pause_match",
            "resume_match", "end_match", "switch_sides", "change_server", "rule_golden",
            "rule_star", "rule_one_advantage", "rule_traditional", "share_result", "new_match")
        if (action !in allowed || !canControl()) return
        val stage = status()
        if (action == "undo" && !canUndo()) return
        if (action.startsWith("point_") && stage != "live") return
        if (action == "start_match" && stage != "idle") return
        if (action == "new_match" && stage != "finished") return
        if (action == "share_result" && stage != "finished") return
        if (action == "end_match" && stage != "live" && stage != "finished") return
        if (action in setOf("pause_match", "resume_match", "switch_sides", "change_server") &&
            stage != "live") return
        if (action == "change_server" && !stateBool("canChangeServer")) return
        if (action.startsWith("rule_") && (stage != "live" || !stateBool("canChangeRules"))) return
        val matchId = stateString("matchId")
        if (matchId.isBlank()) return
        commandQueue.addLast(QueuedCommand(UUID.randomUUID().toString(), matchId, action))
        refreshUi()
        sendNext()
    }

    private fun sendNext() {
        if (activeCommand != null || commandQueue.isEmpty() || requiresResync) return
        val command = commandQueue.removeFirst()
        activeCommand = command
        refreshUi()
        val raw = JSONObject().put("commandId", command.id)
            .put("matchId", command.matchId).put("action", command.action)
            .toString().toByteArray(Charsets.UTF_8)
        val timeout = Runnable {
            if (activeCommand?.id != command.id) return@Runnable
            timeoutRunnable = null
            activeCommand = null
            commandQueue.clear()
            requiresResync = true
            resyncAcknowledged = false
            uncertainBaseline = lastSentAt
            note = "Comando senza conferma: verifica sul telefono"
            refreshUi()
        }
        timeoutRunnable = timeout
        handler.postDelayed(timeout, 15000L)
        Wearable.getNodeClient(this).connectedNodes.addOnSuccessListener { nodes ->
            val node = nodes.firstOrNull { it.isNearby } ?: nodes.firstOrNull()
            if (node == null) {
                runOnUiThread { finishFailure(command.id, "Telefono non connesso", false) }
            } else {
                Wearable.getMessageClient(this)
                    .sendMessage(node.id, "/psb/command", raw)
                    .addOnFailureListener {
                        runOnUiThread { finishFailure(command.id, "Invio non confermato", true) }
                    }
            }
        }.addOnFailureListener {
            runOnUiThread { finishFailure(command.id, "Collegamento non disponibile", false) }
        }
    }

    private fun clearTimeout() {
        timeoutRunnable?.let { handler.removeCallbacks(it) }
        timeoutRunnable = null
    }

    private fun finishFailure(id: String, message: String, uncertain: Boolean) {
        if (activeCommand?.id != id) return
        clearTimeout()
        activeCommand = null
        commandQueue.clear()
        if (uncertain) {
            requiresResync = true
            resyncAcknowledged = false
            uncertainBaseline = lastSentAt
        }
        note = message
        refreshUi()
    }

    private fun onAck(ack: JSONObject) {
        val cmd = activeCommand ?: return
        if (cmd.id != ack.optString("commandId")) return
        clearTimeout()
        activeCommand = null
        note = if (ack.optBoolean("ok", false)) "Comando eseguito"
            else "Non eseguito: ${ack.optString("code", "errore")}"
        refreshUi()
        sendNext()
    }

    private fun requestSnapshot() {
        if (!phoneReachable) { note = "Telefono non raggiungibile"; refreshUi(); return }
        if (requiresResync) {
            AlertDialog.Builder(this)
                .setTitle("Verifica il punteggio")
                .setMessage("Controlla sul telefono se il comando precedente e' stato eseguito. " +
                    "Sblocca i comandi soltanto dopo aver ricevuto uno stato aggiornato.")
                .setPositiveButton("Ho verificato") { _, _ ->
                    resyncAcknowledged = true
                    pullSnapshot()
                }
                .setNegativeButton("Annulla", null).show()
        } else pullSnapshot()
    }

    private fun pullSnapshot() {
        readStoredSnapshot()
        val token = UUID.randomUUID().toString().toByteArray(Charsets.UTF_8)
        Wearable.getNodeClient(this).connectedNodes.addOnSuccessListener { nodes ->
            val node = nodes.firstOrNull { it.isNearby } ?: nodes.firstOrNull()
            if (node != null) Wearable.getMessageClient(this)
                .sendMessage(node.id, "/psb/request_snapshot", token)
                .addOnFailureListener { runOnUiThread {
                    note = "Risincronizzazione non disponibile"; refreshUi()
                } }
        }
    }

    private fun pingPhone() {
        val token = UUID.randomUUID().toString()
        pingId = token
        note = "Verifica collegamento..."
        refreshUi()
        Wearable.getNodeClient(this).connectedNodes.addOnSuccessListener { nodes ->
            val node = nodes.firstOrNull { it.isNearby } ?: nodes.firstOrNull()
            if (node == null) {
                runOnUiThread { note = "Telefono non raggiungibile"; refreshUi() }
            } else Wearable.getMessageClient(this)
                .sendMessage(node.id, "/psb/ping", token.toByteArray(Charsets.UTF_8))
                .addOnFailureListener { runOnUiThread { note = "Ping non riuscito"; refreshUi() } }
        }
        handler.postDelayed({
            if (pingId == token) { pingId = null; note = "Nessuna risposta dal telefono"; refreshUi() }
        }, 5000L)
    }
}
