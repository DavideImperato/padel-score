import SwiftUI

private let padelYellow = Color(red: 0.83, green: 1.0, blue: 0.0)
private let padelCyan = Color(red: 0.0, green: 0.88, blue: 1.0)

/// Fase 4C.1: comandi rapidi sulla prima pagina, azioni secondarie a swipe.
/// L'iPhone continua a essere l'unica fonte ufficiale del punteggio.
struct WatchConnectionView: View {
  @EnvironmentObject private var connection: WatchConnectionModel
  @State private var showEndConfirmation = false
  @State private var showRuleSelection = false
  @State private var showRuleLockedInfo = false
  @State private var showServerConfirmation = false

  var body: some View {
    TabView {
      scorePage
      matchControlsPage
      detailsPage
      connectionPage
    }
    .tabViewStyle(.page(indexDisplayMode: .automatic))
    .onAppear { connection.requestSnapshot() }
    .confirmationDialog("Terminare la partita?", isPresented: $showEndConfirmation,
                        titleVisibility: .visible) {
      Button("Salva e termina", role: .destructive) {
        connection.sendCommand("end_match")
      }
      Button("Annulla", role: .cancel) {}
    } message: {
      Text("Una partita non conclusa verrà salvata fra le Interrotte.")
    }
    .confirmationDialog("Tipo di punteggio", isPresented: $showRuleSelection,
                        titleVisibility: .visible) {
      Button("Punto d'oro") { connection.sendCommand("rule_golden") }
      Button("Star Point") { connection.sendCommand("rule_star") }
      Button("Un vantaggio + Punto d'oro") { connection.sendCommand("rule_one_advantage") }
      Button("Vantaggi tradizionali") { connection.sendCommand("rule_traditional") }
      Button("Annulla", role: .cancel) {}
    } message: {
      Text("Le regole possono cambiare soltanto prima del primo punto.")
    }
    .alert("Tipo di punteggio bloccato", isPresented: $showRuleLockedInfo) {
      Button("OK", role: .cancel) {}
    } message: {
      Text("Puoi cambiare la regola soltanto prima del primo punto del match. Durante una partita resta fissa per mantenere corretti punteggio e Undo.")
    }
    .confirmationDialog("Cambiare battitore?", isPresented: $showServerConfirmation,
                        titleVisibility: .visible) {
      Button("Conferma cambio") { connection.sendCommand("change_server") }
      Button("Annulla", role: .cancel) {}
    } message: {
      Text("Consentito soltanto prima di iniziare il game, fuori dal tie-break.")
    }
  }

  private var scorePage: some View {
    Group {
      if let match = connection.match, match.status == "live" || match.status == "finished" {
        GeometryReader { geometry in
          VStack(spacing: 5) {
            HStack(spacing: 5) {
              quickButton("arrow.uturn.backward", label: "Undo") {
                connection.sendCommand("undo")
              }
              .disabled(!connection.reachable || !match.canUndo || connection.pendingCommands > 0)

              quickButton(match.timerRunning ? "pause.fill" : "play.fill",
                          label: match.timerRunning ? "Pausa" : "Riprendi") {
                connection.sendCommand(match.timerRunning ? "pause_match" : "resume_match")
              }
              .disabled(!connection.reachable || match.status != "live" || connection.pendingCommands > 0)

              Button {
                if match.canChangeRules {
                  showRuleSelection = true
                } else {
                  showRuleLockedInfo = true
                }
              } label: {
                HStack(spacing: 3) {
                  Text(shortRule(match.rules, tieBreak: match.isTieBreak))
                  if !match.canChangeRules {
                    Image(systemName: "lock.fill")
                      .font(.system(size: 7))
                  }
                }
                .font(.system(size: 9, weight: .heavy, design: .rounded))
                .minimumScaleFactor(0.65)
                .lineLimit(1)
                .foregroundStyle(padelYellow)
                .frame(maxWidth: .infinity, minHeight: 28)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
              }
              .buttonStyle(.plain)
              .disabled(!connection.reachable || match.status != "live" || connection.pendingCommands > 0)
              .accessibilityLabel("Tipo di gioco: \(match.rules)")
              .accessibilityHint(match.canChangeRules
                ? "Tocca per scegliere il tipo di punteggio"
                : "Regola bloccata. Tocca per conoscere il motivo")
            }

            HStack(spacing: 4) {
              stat("SET", "\(match.setsA)–\(match.setsB)")
              Spacer(minLength: 0)
              TimelineView(.periodic(from: .now, by: 1)) { timeline in
                stat("TIME", displayDuration(match, at: timeline.date))
              }
              Spacer(minLength: 0)
              stat("GAME", "\(match.gamesA)–\(match.gamesB)")
            }
            .font(.system(size: 10, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .lineLimit(1)

            HStack(spacing: 4) {
              Circle()
                .fill(match.servingTeam == "A" ? padelYellow : padelCyan)
                .frame(width: 5, height: 5)
              Text(match.status == "finished"
                    ? "PARTITA TERMINATA"
                    : "Serve: \(match.servingPlayer)")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .foregroundStyle(match.servingTeam == "A" ? padelYellow : padelCyan)
              Spacer(minLength: 0)
              Circle()
                .fill(connection.reachable ? Color.green : Color.orange)
                .frame(width: 6, height: 6)
                .accessibilityLabel(connection.reachable ? "iPhone connesso" : "iPhone non raggiungibile")
            }

            HStack(spacing: 6) {
              if match.sidesSwapped {
                scoreTile(name: match.teamB, points: match.pointsB, tint: padelCyan,
                          serving: match.servingTeam == "B", action: "point_b")
                scoreTile(name: match.teamA, points: match.pointsA, tint: padelYellow,
                          serving: match.servingTeam == "A", action: "point_a")
              } else {
                scoreTile(name: match.teamA, points: match.pointsA, tint: padelYellow,
                          serving: match.servingTeam == "A", action: "point_a")
                scoreTile(name: match.teamB, points: match.pointsB, tint: padelCyan,
                          serving: match.servingTeam == "B", action: "point_b")
              }
            }
            .frame(maxHeight: .infinity)

            if connection.pendingCommands > 0 {
              Text("Invio \(connection.pendingCommands)…")
                .font(.system(size: 9)).foregroundStyle(.orange)
            } else if !connection.reachable {
              Text("Ultimo risultato ricevuto · offline")
                .font(.system(size: 9)).foregroundStyle(.orange)
            } else if match.status == "finished" {
              Text("Vai a Controlli per salvare")
                .font(.system(size: 9)).foregroundStyle(.green)
            }
          }
          .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .padding(.horizontal, 4)
      } else {
        initialMatchPage
      }
    }
  }

  private var initialMatchPage: some View {
    VStack(spacing: 8) {
      HStack(spacing: 5) {
        Circle().fill(connection.reachable ? .green : .orange).frame(width: 7, height: 7)
        Text(connection.reachable ? "iPhone raggiungibile" : "iPhone non raggiungibile")
          .font(.caption2)
      }
      Spacer(minLength: 0)
      Image(systemName: "sportscourt.fill")
        .foregroundStyle(padelYellow).font(.title2)
      Text(connection.match?.status == "recovery"
           ? "Riprendi prima la partita salvata su iPhone"
           : "Pronto per giocare")
        .font(.caption2).multilineTextAlignment(.center)
      if connection.match?.status == "idle" {
        Button("INIZIA MATCH") { connection.sendCommand("start_match") }
          .disabled(!connection.reachable || connection.pendingCommands > 0)
          .tint(padelYellow)
      } else if connection.match == nil {
        Button("SINCRONIZZA") { connection.requestSnapshot() }
          .disabled(!connection.reachable)
      }
      Spacer(minLength: 0)
    }
    .padding(.horizontal, 7)
  }

  private func quickButton(_ symbol: String, label: String,
                           action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Image(systemName: symbol)
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(.white)
        .frame(width: 36, height: 28)
        .background(Color.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
    }
    .buttonStyle(.plain)
    .accessibilityLabel(label)
  }

  private func stat(_ label: String, _ value: String) -> some View {
    HStack(spacing: 2) {
      Text(label).foregroundStyle(.secondary)
      Text(value).foregroundStyle(.white)
    }
  }

  /// Il Watch interpola solo il cronometro fra due snapshot iPhone.
  /// Punteggio, game e set rimangono sempre quelli confermati da Flutter.
  private func displayDuration(_ match: WatchMatchState, at time: Date) -> String {
    let delta: Int
    if match.status == "live", match.timerRunning, connection.reachable,
       let updated = connection.updatedAt {
      delta = max(0, Int(time.timeIntervalSince(updated)))
    } else {
      delta = 0
    }
    let seconds = match.elapsedSeconds + delta
    let hours = seconds / 3600
    let minutes = (seconds % 3600) / 60
    if hours > 0 {
      return String(format: "%02d:%02d:%02d", hours, minutes, seconds % 60)
    }
    return String(format: "%02d:%02d", minutes, seconds % 60)
  }

  private func shortRule(_ rules: String, tieBreak: Bool) -> String {
    if tieBreak { return "TIE-BREAK" }
    if rules.contains("Star") { return "STAR POINT" }
    if rules.contains("d’oro") && rules.contains("vantaggi") { return "1 VANT. + ORO" }
    if rules.contains("d'oro") || rules.contains("d’oro") { return "PUNTO D'ORO" }
    return "VANTAGGI"
  }

  private func scoreTile(name: String, points: String, tint: Color,
                         serving: Bool, action: String) -> some View {
    Button { connection.sendCommand(action) } label: {
      VStack(spacing: 2) {
        Text(name.uppercased())
          .font(.system(size: 9, weight: .semibold, design: .rounded))
          .foregroundStyle(.white)
          .lineLimit(1)
          .minimumScaleFactor(0.65)
        Spacer(minLength: 0)
        Text(points)
          .font(.system(size: 42, weight: .black, design: .rounded))
          .foregroundStyle(tint)
          .minimumScaleFactor(0.48)
          .lineLimit(1)
        Spacer(minLength: 0)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .padding(.horizontal, 3)
      .padding(.vertical, 8)
      .background(Color.white.opacity(0.085), in: RoundedRectangle(cornerRadius: 12))
      .overlay(RoundedRectangle(cornerRadius: 12)
        .strokeBorder(serving ? tint.opacity(0.65) : Color.clear, lineWidth: 1.5))
      .contentShape(RoundedRectangle(cornerRadius: 12))
    }
    .buttonStyle(.plain)
    .disabled(!connection.canScore)
    .accessibilityLabel("Punto \(name), attuale \(points)")
  }

  private var matchControlsPage: some View {
    ScrollView {
      VStack(spacing: 8) {
        Label("CONTROLLI MATCH", systemImage: "slider.horizontal.3")
          .font(.system(size: 12, weight: .bold, design: .rounded))
          .frame(maxWidth: .infinity, alignment: .leading)
        if connection.match?.status == "live" {
          Button {
            connection.sendCommand("switch_sides")
          } label: {
            Label("Cambia campo", systemImage: "arrow.left.arrow.right")
              .frame(maxWidth: .infinity, alignment: .leading)
          }
          .disabled(!connection.reachable || connection.pendingCommands > 0)

          Button { showServerConfirmation = true } label: {
            Label("Cambia battitore", systemImage: "person.crop.circle.badge.checkmark")
              .frame(maxWidth: .infinity, alignment: .leading)
          }
          .disabled(!connection.reachable || connection.pendingCommands > 0 ||
                    connection.match?.canChangeServer != true)

          if connection.match?.canChangeRules == false {
            Text("La regola si cambia solo prima del primo punto")
              .font(.system(size: 9)).foregroundStyle(.secondary)
          }
          Divider()
          Button(role: .destructive) { showEndConfirmation = true } label: {
            Label("Salva e interrompi", systemImage: "stop.circle")
              .frame(maxWidth: .infinity, alignment: .leading)
          }
          .disabled(!connection.reachable || connection.pendingCommands > 0)
        } else if connection.match?.status == "finished" {
          Button { showEndConfirmation = true } label: {
            Label("Salva risultato", systemImage: "checkmark.seal")
              .frame(maxWidth: .infinity, alignment: .leading)
          }
          .disabled(!connection.reachable || connection.pendingCommands > 0)
        } else {
          Text("Avvia una partita per attivare i controlli")
            .font(.caption2).foregroundStyle(.secondary)
        }
        Button { connection.requestSnapshot() } label: {
          Label("Risincronizza", systemImage: "arrow.clockwise")
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .disabled(!connection.reachable)
        if !connection.lastCommandFeedback.isEmpty {
          Text(connection.lastCommandFeedback)
            .font(.system(size: 9)).multilineTextAlignment(.center)
            .foregroundStyle(.secondary)
        }
      }
      .font(.system(size: 11, weight: .semibold))
      .padding(.horizontal, 6)
    }
  }

  private var detailsPage: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 8) {
        Label("DETTAGLI", systemImage: "list.bullet.rectangle").font(.caption.bold())
        if let match = connection.match, match.status != "idle" {
          Text("\(match.teamA) vs \(match.teamB)").font(.caption2.bold())
          ForEach(Array(match.players.enumerated()), id: \.offset) { index, name in
            Text("\(index + 1). \(name)").font(.caption2)
          }
          Divider()
          Text(match.rules).font(.caption2)
          Text("\(match.bestOfSets) set · \(match.shortSets ? "Mini-set" : "Set standard")")
            .font(.caption2)
          if match.decidingMatchTieBreak {
            Text("Decisivo a \(match.decidingTieBreakPoints)").font(.caption2)
          }
          Text("Durata: \(match.duration)").font(.caption2)
          if !match.completedSets.isEmpty {
            Divider()
            ForEach(match.completedSets) { set in
              Text("Set \(set.id + 1): \(set.result)").font(.caption2)
            }
          }
          Text(match.lastEvent).font(.caption2).foregroundStyle(.secondary)
        } else {
          Text("Avvia una partita su iPhone").font(.caption2)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, 7)
    }
  }

  private var connectionPage: some View {
    ScrollView {
      VStack(spacing: 9) {
        Label("CONNESSIONE", systemImage: "applewatch").font(.caption.bold())
        Label(connection.status, systemImage: connection.reachable ? "checkmark.circle.fill" : "iphone.slash")
          .font(.caption2)
          .foregroundStyle(connection.reachable ? .green : .orange)
          .multilineTextAlignment(.center)
        Button("PROVA PING") { connection.pingPhone() }
          .disabled(!connection.reachable || connection.isPinging)
        Button("RISINCRONIZZA") { connection.requestSnapshot() }
          .disabled(!connection.reachable)
        if let updated = connection.updatedAt {
          Text("Ultimo stato: \(updated.formatted(date: .omitted, time: .standard))")
            .font(.caption2).foregroundStyle(.secondary)
        }
        if !connection.lastResult.isEmpty {
          Text(connection.lastResult).font(.caption2).multilineTextAlignment(.center)
        }
        if !connection.lastCommandFeedback.isEmpty {
          Text(connection.lastCommandFeedback).font(.caption2).multilineTextAlignment(.center)
        }
      }
      .padding(.horizontal, 7)
    }
  }
}
