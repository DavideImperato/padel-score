import SwiftUI

@main
struct PadelScoreWatchApp: App {
  @StateObject private var connection = WatchConnectionModel()

  var body: some Scene {
    WindowGroup {
      WatchConnectionView()
        .environmentObject(connection)
    }
  }
}
