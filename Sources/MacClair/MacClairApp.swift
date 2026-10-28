import SwiftUI

@main
struct MacClairApp: App {
    #if canImport(Sparkle)
    @StateObject private var updates = UpdateController()
    #endif

    var body: some Scene {
        WindowGroup("MacClair") {
            ModernContentView()
                .frame(minWidth: 1080, minHeight: 700)
        }
        .windowStyle(.titleBar)
        .commands {
            #if canImport(Sparkle)
            CommandGroup(after: .appInfo) {
                Button("Rechercher des mises à jour…") {
                    updates.checkForUpdates()
                }
            }
            #endif
        }
    }
}

@MainActor
@Observable
final class CleanupModel {
    var items: [CleanupItem] = []
    var insights: InsightReport?
    var scanning = false
    var moving = false
    var hasScanned = false
    var unreadablePaths = 0
    var stoppedAtLimit = false
    var message: String?

    var selectedBytes: Int64 { items.filter(\.selected).reduce(0) { $0 + $1.bytes } }
    var selectedCount: Int { items.filter(\.selected).count }
    var totalBytes: Int64 { items.reduce(0) { $0 + $1.bytes } }

    func scan(insightRoot: URL? = nil) {
        guard !scanning && !moving else { return }
        scanning = true
        message = nil
        Task {
            async let cleanup = Task.detached(priority: .userInitiated) { Cleaner().scan() }.value
            async let discovery = Task.detached(priority: .userInitiated) { InsightScanner(scanRoot: insightRoot).scan() }.value
            let report = await cleanup
            items = report.items
            insights = await discovery
            unreadablePaths = report.unreadablePaths
            stoppedAtLimit = report.stoppedAtLimit
            hasScanned = true
            scanning = false
        }
    }

    func moveSelectedToTrash() {
        let selected = items.filter(\.selected)
        guard !selected.isEmpty && !moving else { return }
        moving = true
        message = nil
        Task {
            let results = await Task.detached(priority: .userInitiated) {
                let cleaner = Cleaner()
                var moved: [URL] = []
                var failures: [String] = []
                for item in selected where item.canMoveToTrash {
                    do {
                        try cleaner.moveToTrash(item)
                        moved.append(item.id)
                    } catch {
                        failures.append("\(item.name) : \(error.localizedDescription)")
                    }
                }
                return (moved, failures)
            }.value
            items.removeAll { results.0.contains($0.id) }
            message = "\(results.0.count) fichier(s) déplacé(s) vers la Corbeille." +
                (results.1.isEmpty ? "" : " Échecs : " + results.1.prefix(3).joined(separator: " ; "))
            moving = false
        }
    }
}

