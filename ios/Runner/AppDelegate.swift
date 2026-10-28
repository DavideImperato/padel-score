import Flutter
import UIKit
import WatchConnectivity

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    WatchLinkBridge.shared.activate()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // Flutter 3.41+: l'engine viene creato dal ciclo di vita UIScene.
  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    WatchLinkBridge.shared.attach(
      messenger: engineBridge.applicationRegistrar.messenger()
    )
  }
}

/// Bridge 4C: riceve i comandi dal Watch, li delega al provider Flutter e
/// risponde soltanto dopo l'esecuzione. L'iPhone e` la fonte ufficiale.
private final class WatchLinkBridge: NSObject, WCSessionDelegate, FlutterStreamHandler {
  static let shared = WatchLinkBridge()

  private let methodName = "padel_score_board/watch_link"
  private let eventName = "padel_score_board/watch_link_events"
  private var methodChannel: FlutterMethodChannel?
  private var eventChannel: FlutterEventChannel?
  private var eventSink: FlutterEventSink?
  private var lastWatchPing: Date?
  private var latestMatchState: [String: Any]?

  func activate() {
    guard WCSession.isSupported() else { return }
    let session = WCSession.default
    session.delegate = self
    if session.activationState != .activated { session.activate() }
  }

  func attach(messenger: FlutterBinaryMessenger) {
    methodChannel?.setMethodCallHandler(nil)
    eventChannel?.setStreamHandler(nil)
    let methods = FlutterMethodChannel(name: methodName, binaryMessenger: messenger)
    methods.setMethodCallHandler { [weak self] call, reply in
      guard let self else {
        reply(FlutterError(code: "bridge_unavailable", message: "Bridge Watch non disponibile", details: nil))
        return
      }
      switch call.method {
      case "getStatus": reply(self.status())
      case "activate":
        self.activate()
        reply(self.status())
      case "ping": self.pingWatch(reply: reply)
      case "publishMatch":
        guard let state = call.arguments as? [String: Any],
              state["version"] as? Int == 1,
              state["matchId"] is String else {
          reply(FlutterError(code: "invalid_state", message: "Stato Watch non valido", details: nil))
          return
        }
        self.publishMatch(state)
        reply(nil)
      default: reply(FlutterMethodNotImplemented)
      }
    }
    methodChannel = methods

    let events = FlutterEventChannel(name: eventName, binaryMessenger: messenger)
    events.setStreamHandler(self)
    eventChannel = events
  }

  /// Usa applicationContext per l'ultimo stato e sendMessage quando raggiungibile.
  /// Non mette in coda tutti i punti, che potrebbero arrivare fuori tempo.
  private func publishMatch(_ state: [String: Any]) {
    latestMatchState = state
    guard WCSession.isSupported() else { return }
    let session = WCSession.default
    guard session.activationState == .activated,
          session.isPaired, session.isWatchAppInstalled else { return }
    do {
      try session.updateApplicationContext(["type": "match_state", "state": state])
    } catch {
      NSLog("Watch context non inviato: %@", error.localizedDescription)
    }
    if session.isReachable {
      session.sendMessage(["type": "match_state", "state": state],
                          replyHandler: nil, errorHandler: { _ in })
    }
  }

  private func status() -> [String: Any] {
    guard WCSession.isSupported() else {
      return ["supported": false, "activated": false, "paired": false,
              "installed": false, "reachable": false]
    }
    let session = WCSession.default
    let active = session.activationState == .activated
    var details: [String: Any] = [
      "supported": true,
      "activated": active,
      "paired": active && session.isPaired,
      "installed": active && session.isWatchAppInstalled,
      "reachable": active && session.isReachable,
    ]
    if let lastWatchPing {
      details["lastWatchPing"] = Int(lastWatchPing.timeIntervalSince1970 * 1000)
    }
    return details
  }

  private func emitStatus() {
    DispatchQueue.main.async { [weak self] in
      guard let self else { return }
      self.eventSink?(self.status())
    }
  }

  private func pingWatch(reply: @escaping FlutterResult) {
    guard WCSession.isSupported() else {
      reply(FlutterError(code: "unsupported", message: "WatchConnectivity non supportato", details: nil))
      return
    }
    let session = WCSession.default
    guard session.activationState == .activated, session.isPaired,
          session.isWatchAppInstalled, session.isReachable else {
      reply(FlutterError(code: "watch_unreachable", message: "Apri Padel Score Board su Apple Watch e riprova", details: nil))
      return
    }
    let requestId = UUID().uuidString
    let start = Date()
    session.sendMessage(
      ["type": "ping", "requestId": requestId],
      replyHandler: { response in
        DispatchQueue.main.async {
          guard response["type"] as? String == "pong",
                response["requestId"] as? String == requestId else {
            reply(FlutterError(code: "invalid_reply", message: "Risposta Watch non valida", details: nil))
            return
          }
          reply(["ok": true, "roundTripMs": Int(Date().timeIntervalSince(start) * 1000)])
        }
      },
      errorHandler: { error in
        DispatchQueue.main.async {
          reply(FlutterError(code: "ping_failed", message: error.localizedDescription, details: nil))
        }
      }
    )
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    eventSink = events
    emitStatus()
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }

  func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
    emitStatus()
    DispatchQueue.main.async { [weak self] in
      guard state == .activated, let current = self?.latestMatchState else { return }
      self?.publishMatch(current)
    }
  }

  func sessionDidBecomeInactive(_ session: WCSession) { emitStatus() }

  func sessionDidDeactivate(_ session: WCSession) {
    // Richiesto su iOS quando l'utente cambia Apple Watch abbinato.
    session.activate()
    emitStatus()
  }

  func sessionReachabilityDidChange(_ session: WCSession) {
    emitStatus()
    if session.isReachable {
      DispatchQueue.main.async { [weak self] in
        guard let self, let current = self.latestMatchState else { return }
        self.publishMatch(current)
      }
    }
  }

  func sessionWatchStateDidChange(_ session: WCSession) { emitStatus() }

  func session(_ session: WCSession, didReceiveMessage message: [String: Any],
               replyHandler: @escaping ([String: Any]) -> Void) {
    if message["type"] as? String == "watch_command" {
      // Flutter e` l'unico proprietario del motore; mai attribuire punti in Swift.
      DispatchQueue.main.async { [weak self] in
        guard let channel = self?.methodChannel else {
          replyHandler(["type": "watch_command_ack", "ok": false, "code": "flutter_unavailable"])
          return
        }
        channel.invokeMethod("watchCommand", arguments: message, result: { result in
          var response: [String: Any] = ["type": "watch_command_ack"]
          if let outcome = result as? [String: Any] {
            response.merge(outcome) { _, new in new }
          } else if let error = result as? FlutterError {
            response["ok"] = false
            response["code"] = error.code
          } else {
            response["ok"] = false
            response["code"] = "invalid_flutter_response"
          }
          replyHandler(response)
        })
      }
      return
    }
    if message["type"] as? String == "get_match_state" {
      DispatchQueue.main.async { [weak self] in
        if let state = self?.latestMatchState {
          replyHandler(["type": "match_state", "state": state])
        } else {
          replyHandler(["type": "no_match_state"])
        }
      }
      return
    }
    guard message["type"] as? String == "ping",
          let id = message["requestId"] as? String else {
      replyHandler(["type": "error", "reason": "unsupported_message"])
      return
    }
    DispatchQueue.main.async { [weak self] in
      self?.lastWatchPing = Date()
      self?.emitStatus()
    }
    replyHandler(["type": "pong", "requestId": id])
  }
}
