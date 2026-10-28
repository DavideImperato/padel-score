import Foundation
import Testing
@testable import PadelScoreWatch_Watch_App

/// Fase 7B: validazione degli snapshot dal bridge iPhone, anche per i tornei.
struct PadelScoreWatch_Watch_AppTests {
  private func payload() -> [String: Any] {
    [
      "version": 1, "matchId": "match-tournament-1",
      "sentAt": Int64(1_750_000_000_000_000),
      "status": "live", "teamA": "A", "teamB": "B",
      "pointsA": "40", "pointsB": "30",
      "tournamentMatch": true,
      "sets": [
        ["gamesA": 6, "gamesB": 4],
        ["gamesA": 0, "gamesB": 0,
         "matchTieBreak": true, "tieBreakA": 10, "tieBreakB": 8],
      ],
    ]
  }

  @Test func tournamentSnapshotAndMatchTieBreak() {
    let snapshot = WatchMatchState(payload())
    #expect(snapshot != nil)
    #expect(snapshot?.matchId == "match-tournament-1")
    #expect(snapshot?.tournamentMatch == true)
    #expect(snapshot?.completedSets.map(\.result) == ["6-4", "MTB 10-8"])
    #expect(snapshot?.pointsA == "40")
  }

  @Test func uncertainCommandRequiresManualVerification() {
    let prior = WatchMatchState(payload())!
    var newer = payload()
    newer["sentAt"] = Int64(1_750_000_000_000_001)
    let incoming = WatchMatchState(newer)!
    let auto = WatchSnapshotDecision.evaluate(
      previous: prior, incoming: incoming,
      manualVerification: false, requiresResync: true)
    #expect(auto.accept && auto.update && !auto.unlock)

    let manual = WatchSnapshotDecision.evaluate(
      previous: incoming, incoming: incoming,
      manualVerification: true, requiresResync: true)
    #expect(manual.accept && !manual.update && manual.unlock)

    let older = WatchSnapshotDecision.evaluate(
      previous: incoming, incoming: prior,
      manualVerification: true, requiresResync: true)
    #expect(!older.accept && !older.unlock)

    let ordinary = WatchSnapshotDecision.evaluate(
      previous: incoming, incoming: incoming,
      manualVerification: true, requiresResync: false)
    #expect(!ordinary.unlock)
  }

  @Test func rejectInvalidProtocolOrStatus() {
    var data = payload()
    data["version"] = 2
    #expect(WatchMatchState(data) == nil)
    data = payload()
    data["status"] = "unknown"
    #expect(WatchMatchState(data) == nil)
    data = payload()
    data.removeValue(forKey: "matchId")
    #expect(WatchMatchState(data) == nil)
  }

  @Test func defaultOptionalValuesForOlderSnapshot() {
    var data = payload()
    data.removeValue(forKey: "tournamentMatch")
    data.removeValue(forKey: "sets")
    let snapshot = WatchMatchState(data)
    #expect(snapshot?.tournamentMatch == false)
    #expect(snapshot?.completedSets.isEmpty == true)
    #expect(snapshot?.canUndo == false)
    #expect(snapshot?.bestOfSets == 3)
  }
}
