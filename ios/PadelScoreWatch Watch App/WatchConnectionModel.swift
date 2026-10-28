import Foundation
import WatchConnectivity
import Combine

/// Stato ricevuto e convalidato dall'iPhone (fonte ufficiale della partita).
struct WatchMatchState {
  struct SetResult: Identifiable {
    let id: Int
    let result: String
  }

  let matchId: String
  let tournamentMatch: Bool
  let sentAt: Int64
  let status: String
  let teamA: String
  let teamB: String
  let pointsA: String
  let pointsB: String
  let gamesA: Int
  let gamesB: Int
  let setsA: Int
  let setsB: Int
  let servingTeam: String
  let servingPlayer: String
  let players: [String]
  let completedSets: [SetResult]
  let rules: String
  let shortSets: Bool
  let bestOfSets: Int
  let decidingMatchTieBreak: Bool
  let decidingTieBreakPoints: Int
  let isTieBreak: Bool
  let isMatchTieBreak: Bool
  let elapsedSeconds: Int
  let timerRunning: Bool
  let lastEvent: String
  let winner: String
  let sidesSwapped: Bool
  let canUndo: Bool
  let canChangeRules: Bool
  let canChangeServer: Bool

  init?(_ data: [String: Any]) {
    guard data["version"] as? Int == 1,
          let matchId = data["matchId"] as? String,
          let sentAt = (data["sentAt"] as? NSNumber)?.int64Value,
          let status = data["status"] as? String,
          ["idle", "live", "finished", "recovery"].contains(status),
          let teamA = data["teamA"] as? String,
          let teamB = data["teamB"] as? String,
          let pointsA = data["pointsA"] as? String,
          let pointsB = data["pointsB"] as? String else { return nil }
    self.matchId = matchId
    tournamentMatch = data["tournamentMatch"] as? Bool ?? false
    self.sentAt = sentAt
    self.status = status
    self.teamA = teamA
    self.teamB = teamB
    self.pointsA = pointsA
    self.pointsB = pointsB
    gamesA = data["gamesA"] as? Int ?? 0
    gamesB = data["gamesB"] as? Int ?? 0
    setsA = data["setsA"] as? Int ?? 0
    setsB = data["setsB"] as? Int ?? 0
    servingTeam = data["servingTeam"] as? String ?? ""
    servingPlayer = data["servingPlayer"] as? String ?? ""
    players = data["players"] as? [String] ?? []
    rules = data["rules"] as? String ?? ""
    shortSets = data["shortSets"] as? Bool ?? false
    bestOfSets = data["bestOfSets"] as? Int ?? 3
    decidingMatchTieBreak = data["decidingMatchTieBreak"] as? Bool ?? false
    decidingTieBreakPoints = data["decidingTieBreakPoints"] as? Int ?? 10
    isTieBreak = data["isTieBreak"] as? Bool ?? false
    isMatchTieBreak = data["isMatchTieBreak"] as? Bool ?? false
    elapsedSeconds = data["elapsedSeconds"] as? Int ?? 0
    timerRunning = data["timerRunning"] as? Bool ?? false
    lastEvent = data["lastEvent"] as? String ?? ""
    winner = data["winner"] as? String ?? ""
    sidesSwapped = data["sidesSwapped"] as? Bool ?? false
    canUndo = data["canUndo"] as? Bool ?? false
    canChangeRules = data["canChangeRules"] as? Bool ?? false
    canChangeServer = data["canChangeServer"] as? Bool ?? false
    let setData = data["sets"] as? [[String: Any]] ?? []
    completedSets = setData.enumerated().map { (idx, set) in
      let a = set["gamesA"] as? Int ?? 0
      let b = set["gamesB"] as? Int ?? 0
      let isMatchTB = set["matchTieBreak"] as? Bool ?? false
      let tbA = set["tieBreakA"] as? Int ?? -1
      let tbB = set["tieBreakB"] as? Int ?? -1
      let result = isMatchTB ? "MTB \(tbA)-\(tbB)" : "\(a)-\(b)"
      return SetResult(id: idx, result: result)
    }
  }

  var duration: String {
    let hours = elapsedSeconds / 3600
    let minutes = (elapsedSeconds % 3600) / 60
    let seconds = elapsedSeconds % 60
    if hours > 0 { return String(format: "%02d:%02d:%02d", hours, minutes, seconds) }
    return String(format: "%02d:%02d", minutes, seconds)
  }
}

/// Regole testabili di accettazione snapshot: non sbloccare mai un comando
/// incerto con un context automatico o uno stato piu' vecchio.
struct WatchSnapshotDecision {
  let accept: Bool
  let update: Bool
  let unlock: Bool

  static func evaluate(previous: WatchMatchState?, incoming: WatchMatchState,
                       manualVerification: Bool, requiresResync: Bool) -> Self {
    if let previous, incoming.sentAt < previous.sentAt {
      return Self(accept: false, update: false, unlock: false)
    }
    return Self(
      accept: true,
      update: previous?.sentAt != incoming.sentAt || previous?.matchId != incoming.matchId,
      unlock: manualVerification && requiresResync
    )
  }
}

/// Fase 4C: iPhone autorevole; tap sul Watch invia solo comandi con ID univoci.
final class WatchConnectionModel: NSObject, ObservableObject, WCSessionDelegate {
  @Published private(set) var status = "Inizializzazione…"
  @Published private(set) var reachable = false
  @Published private(set) var lastResult = ""
  @Published private(set) var isPinging = false
  @Published private(set) var match: WatchMatchState?
  @Published private(set) var updatedAt: Date?
  @Published private(set) var pendingCommands = 0
  @Published private(set) var requiresResync = false
  @Published private(set) var lastCommandFeedback = ""
  private struct QueuedCommand {
    let id: String
    let matchId: String
    let action: String
  }
  private var commandQueue: [QueuedCommand] = []
  private var sendingCommand = false
  // Un comando senza ACK non deve bloccare definitivamente l'orologio.
  // Non lo ritrasmettiamo: potrebbe essere gia' stato applicato su iPhone.
  private var activeCommandId: String?
  private var commandTimeout: DispatchWorkItem?
  private let commandTimeoutSeconds: TimeInterval = 20

  override init() {
    super.init()
    activate()
  }

  func activate() {
    guard WCSession.isSupported() else {
      status = "WatchConnectivity non supportato"
      return
    }
    let session = WCSession.default
    session.delegate = self
    if session.activationState != .activated { session.activate() }
    refreshStatus()
    if !session.receivedApplicationContext.isEmpty {
      receiveEnvelope(session.receivedApplicationContext)
    }
  }

  private func refreshStatus() {
    DispatchQueue.main.async {
      let session = WCSession.default
      let active = session.activationState == .activated
      self.reachable = active && session.isReachable
      self.status = !active ? "Connessione in avvio" :
        (!session.isCompanionAppInstalled ? "Installa l’app su iPhone" :
         (session.isReachable ? "iPhone raggiungibile" : "Apri l’app su iPhone"))
      // Se il link cade con un comando in volo, l'iPhone potrebbe averlo gia'
      // applicato. Evita che nuovi tap rimangano dietro a un ACK irraggiungibile.
      if !self.reachable && self.pendingCommands > 0 {
        self.commandOutcomeUnknown("Connessione interrotta: verifica il risultato su iPhone.")
      }
    }
  }

  private func receiveEnvelope(_ envelope: [String: Any],
                               confirmUnknownResult: Bool = false) {
    guard envelope["type"] as? String == "match_state" else { return }
    guard let payload = envelope["state"] as? [String: Any],
          let newMatch = WatchMatchState(payload) else {
      DispatchQueue.main.async {
        self.lastResult = "Stato partita ricevuto ma non valido"
      }
      return
    }
    DispatchQueue.main.async {
      // Ignora snapshot obsoleti. Un duplicato e' valido per una verifica
      // richiesta esplicitamente, senza azzerare il cronometro interpolato.
      let decision = WatchSnapshotDecision.evaluate(
        previous: self.match, incoming: newMatch,
        manualVerification: confirmUnknownResult, requiresResync: self.requiresResync
      )
      guard decision.accept else { return }
      if decision.update {
        self.match = newMatch
        self.updatedAt = Date()
      }
      // Gli aggiornamenti automatici non sono conferma di un comando con
      // esito incerto: potrebbe essere arrivato uno snapshot precedente.
      // Il giocatore deve controllare iPhone e richiedere la risincronizzazione.
      if decision.unlock {
        self.requiresResync = false
        self.lastCommandFeedback = "Stato verificato con iPhone."
      }
      self.lastResult = "Stato aggiornato da iPhone"
    }
  }

  func requestSnapshot(confirmUnknownResult: Bool = false) {
    let session = WCSession.default
    guard session.activationState == .activated, session.isReachable else { return }
    session.sendMessage(["type": "get_match_state"], replyHandler: { response in
      if response["type"] as? String == "no_match_state" {
        DispatchQueue.main.async {
          self.lastResult = "Nessuna partita ancora pubblicata da iPhone"
        }
      } else {
        // Soltanto una risposta diretta ad una richiesta esplicita dell'utente
        // puo' sbloccare i comandi dopo un esito incerto.
        self.receiveEnvelope(response, confirmUnknownResult: confirmUnknownResult)
      }
    }, errorHandler: { error in
      DispatchQueue.main.async {
        self.lastResult = "Risincronizzazione: \(error.localizedDescription)"
      }
    })
  }

  var canScore: Bool {
    reachable && !requiresResync && match?.status == "live" && pendingCommands < 5
  }

  /// Comandi FIFO: tap rapidi mantengono l'ordine in cui vengono effettuati.
  /// Nessuna modifica ottimistica al punteggio e nessuna ritrasmissione automatica.
  func sendCommand(_ action: String) {
    let allowed: Set<String> = ["point_a", "point_b", "undo", "start_match",
                                 "pause_match", "resume_match", "end_match",
                                 "switch_sides", "change_server",
                                 "rule_golden", "rule_star", "rule_traditional",
                                 "rule_one_advantage", "share_result", "new_match"]
    guard allowed.contains(action) else { return }
    guard !requiresResync else {
      lastCommandFeedback = "Verifica il risultato su iPhone, poi risincronizza."
      return
    }
    let session = WCSession.default
    guard session.activationState == .activated, session.isReachable else {
      lastCommandFeedback = "iPhone non raggiungibile"
      return
    }
    guard pendingCommands < 5 else {
      lastCommandFeedback = "Attendi i comandi in corso"
      return
    }
    guard let id = match?.matchId else {
      lastCommandFeedback = "Attendi sincronizzazione partita"
      requestSnapshot()
      return
    }
    if action == "undo" {
      guard (match?.status == "live" || match?.status == "finished"), match?.canUndo == true else {
        lastCommandFeedback = "Nessun punto da annullare"
        return
      }
    } else if action.hasPrefix("point_") || action == "pause_match" || action == "resume_match" ||
              action == "switch_sides" || action == "change_server" || action.hasPrefix("rule_") {
      guard match?.status == "live" else {
        lastCommandFeedback = "Partita non in corso"
        return
      }
    }
    if (action == "share_result" || action == "new_match") && match?.status != "finished" {
      lastCommandFeedback = "Disponibile soltanto a partita conclusa"
      return
    }
    if action == "end_match" && match?.status != "live" && match?.status != "finished" {
      lastCommandFeedback = "Nessuna partita da terminare"
      return
    }
    commandQueue.append(QueuedCommand(id: UUID().uuidString, matchId: id, action: action))
    pendingCommands += 1
    lastCommandFeedback = "Comando in coda…"
    sendNextCommand()
  }

  private func invalidatePendingCommand() {
    commandTimeout?.cancel()
    commandTimeout = nil
    activeCommandId = nil
    sendingCommand = false
    commandQueue.removeAll()
    pendingCommands = 0
  }

  private func commandOutcomeUnknown(_ reason: String) {
    invalidatePendingCommand()
    requiresResync = true
    lastCommandFeedback = reason
    requestSnapshot() // Non ritrasmettere un punto con esito sconosciuto.
  }

  private func sendNextCommand() {
    guard !sendingCommand, !commandQueue.isEmpty else { return }
    let session = WCSession.default
    guard session.activationState == .activated, session.isReachable else {
      commandOutcomeUnknown("Connessione persa. Risincronizza.")
      return
    }
    // Dopo uno start/end il matchId puo' cambiare: nessun comando in coda
    // deve essere applicato alla partita precedente.
    guard commandQueue[0].matchId == match?.matchId else {
      commandOutcomeUnknown("Partita cambiata. Controlla il risultato.")
      return
    }
    let command = commandQueue.removeFirst()
    sendingCommand = true
    activeCommandId = command.id

    let timeout = DispatchWorkItem { [weak self] in
      guard let self, self.activeCommandId == command.id else { return }
      self.commandOutcomeUnknown("Risposta scaduta: controlla iPhone e risincronizza.")
    }
    commandTimeout = timeout
    DispatchQueue.main.asyncAfter(deadline: .now() + commandTimeoutSeconds, execute: timeout)

    session.sendMessage([
      "type": "watch_command", "commandId": command.id,
      "matchId": command.matchId, "action": command.action,
      "sentAt": Int64(Date().timeIntervalSince1970 * 1000)
    ], replyHandler: { [weak self] response in
      DispatchQueue.main.async {
        guard let self, self.activeCommandId == command.id else { return }
        self.commandTimeout?.cancel()
        self.commandTimeout = nil
        self.activeCommandId = nil
        self.sendingCommand = false
        self.pendingCommands = max(0, self.pendingCommands - 1)
        guard response["type"] as? String == "watch_command_ack",
              response["commandId"] as? String == command.id else {
          self.commandOutcomeUnknown("Risposta non valida: risincronizza.")
          return
        }
        if response["ok"] as? Bool == true {
          self.lastCommandFeedback = "Comando confermato da iPhone"
        } else {
          let code = response["code"] as? String ?? "unknown"
          self.lastCommandFeedback = "Comando non eseguito: \(code)"
        }
        self.requestSnapshot()
        self.sendNextCommand()
      }
    }, errorHandler: { [weak self] error in
      DispatchQueue.main.async {
        guard let self, self.activeCommandId == command.id else { return }
        self.commandOutcomeUnknown("Esito incerto: risincronizza (\(error.localizedDescription))")
      }
    })
  }

  func pingPhone() {
    let session = WCSession.default
    guard session.activationState == .activated, session.isReachable else {
      lastResult = "iPhone non raggiungibile"
      return
    }
    isPinging = true
    lastResult = "Ping in corso…"
    let id = UUID().uuidString
    let started = Date()
    session.sendMessage(["type": "ping", "requestId": id], replyHandler: { reply in
      DispatchQueue.main.async {
        self.isPinging = false
        if reply["type"] as? String == "pong", reply["requestId"] as? String == id {
          self.lastResult = "Pong: \(Int(Date().timeIntervalSince(started) * 1000)) ms"
          self.requestSnapshot()
        } else {
          self.lastResult = "Risposta iPhone non valida"
        }
      }
    }, errorHandler: { error in
      DispatchQueue.main.async {
        self.isPinging = false
        self.lastResult = "Errore: \(error.localizedDescription)"
        self.refreshStatus()
      }
    })
  }

  func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
    refreshStatus()
    if activationState == .activated { requestSnapshot() }
  }

  func sessionReachabilityDidChange(_ session: WCSession) {
    refreshStatus()
    if session.isReachable { requestSnapshot() }
  }

  func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
    receiveEnvelope(applicationContext)
  }

  func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
    receiveEnvelope(message)
  }

  func session(_ session: WCSession, didReceiveMessage message: [String: Any],
               replyHandler: @escaping ([String: Any]) -> Void) {
    guard message["type"] as? String == "ping",
          let id = message["requestId"] as? String else {
      replyHandler(["type": "error", "reason": "unsupported_message"])
      return
    }
    DispatchQueue.main.async { self.lastResult = "Ping ricevuto da iPhone" }
    replyHandler(["type": "pong", "requestId": id])
  }
}
