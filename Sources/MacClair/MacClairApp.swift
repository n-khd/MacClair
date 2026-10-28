import SwiftUI

@main
struct MacClairApp: App {
    #if canImport(Sparkle)
    @StateObject private var updates = UpdateController()
    #endif
    /// Langue choisie dans le menu MacClair : « auto » suit la langue du système.
    @AppStorage("macclair.language") private var language = "auto"

    private var activeLocale: Locale {
        switch language {
        case "fr": return Locale(identifier: "fr")
        case "en": return Locale(identifier: "en")
        default:
            let preferred = Locale.preferredLanguages.first ?? "fr"
            return Locale(identifier: preferred.hasPrefix("en") ? "en" : "fr")
        }
    }

    var body: some Scene {
        WindowGroup("MacClair") {
            ModernContentView()
                .frame(minWidth: 1100, minHeight: 720)
                .environment(\.locale, activeLocale)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(after: .appInfo) {
                #if canImport(Sparkle)
                Button("Rechercher des mises à jour…") {
                    updates.checkForUpdates()
                }
                #endif
                Menu("Langue / Language") {
                    Picker("Langue / Language", selection: $language) {
                        Text("Système / System").tag("auto")
                        Text("Français").tag("fr")
                        Text("English").tag("en")
                    }
                    .pickerStyle(.inline)
                }
            }
        }
    }
}

@MainActor
@Observable
final class CleanupModel {
    var items: [CleanupItem] = []
    var insights: InsightReport?
    var scanning = false
    var cleanupProgress = "Préparation…"
    var insightProgress = "Préparation…"
    private var scanID = UUID()
    var moving = false
    var hasScanned = false
    var unreadablePaths = 0
    var stoppedAtLimit = false
    var message: String?
    var cleanProgress = ""
    var lastMovedCount = 0
    var lastFreedBytes: Int64 = 0
    var cleanSummary: String?

    var selectedBytes: Int64 { items.filter(\.selected).reduce(0) { $0 + $1.bytes } }
    var selectedCount: Int { items.filter(\.selected).count }
    var totalBytes: Int64 { items.reduce(0) { $0 + $1.bytes } }
    var recommendedBytes: Int64 { items.filter(\.canMoveToTrash).reduce(0) { $0 + $1.bytes } }
    var recommendedCount: Int { items.filter(\.canMoveToTrash).count }

    func scan(insightRoot: URL? = nil) {
        guard !scanning && !moving else { return }
        scanning = true
        let currentScan = UUID()
        scanID = currentScan
        cleanupProgress = "Préparation…"
        insightProgress = "Préparation…"
        message = nil
        Task {
            async let cleanup = Task.detached(priority: .userInitiated) {
                Cleaner().scan { stage, count in
                    Task { @MainActor in
                        guard self.scanning, self.scanID == currentScan else { return }
                        self.cleanupProgress = "\(stage) · \(count) éléments parcourus"
                    }
                }
            }.value
            async let discovery = Task.detached(priority: .userInitiated) {
                InsightScanner(scanRoot: insightRoot).scan { stage, count in
                    Task { @MainActor in
                        guard self.scanning, self.scanID == currentScan else { return }
                        self.insightProgress = "\(stage) · \(count) éléments"
                    }
                }
            }.value
            let report = await cleanup
            items = report.items
            insights = await discovery
            unreadablePaths = report.unreadablePaths
            stoppedAtLimit = report.stoppedAtLimit
            hasScanned = true
            scanning = false
        }
    }

    func cleanRecommended(completion: ((Int, Int64) -> Void)? = nil) {
        guard !moving && !scanning else { return }
        for index in items.indices { items[index].selected = items[index].canMoveToTrash }
        moveSelectedToTrash(completion: completion)
    }

    func moveSelectedToTrash(completion: ((Int, Int64) -> Void)? = nil) {
        let selected = items.filter(\.selected)
        guard !selected.isEmpty && !moving else { return }
        moving = true
        message = nil
        cleanProgress = "Déplacement en cours…"
        Task {
            let results = await Task.detached(priority: .userInitiated) { () -> (moved: [URL], freed: Int64, failures: [String]) in
                Cleaner().moveToTrash(selected) { done, total in
                    Task { @MainActor in
                        self.cleanProgress = "Déplacement \(done)/\(total)…"
                    }
                }
            }.value
            items.removeAll { results.moved.contains($0.id) }
            lastMovedCount = results.moved.count
            lastFreedBytes = results.freed
            if results.moved.isEmpty {
                cleanSummary = nil
                message = results.failures.isEmpty
                    ? "Aucun fichier n’a été déplacé."
                    : "Aucun fichier n’a été déplacé. " + results.failures.prefix(3).joined(separator: " ; ")
            } else {
                cleanSummary = "\(results.moved.count) élément(s) déplacé(s) vers la Corbeille · \(ByteCountFormatter.string(fromByteCount: results.freed, countStyle: .file)) libérés."
                message = cleanSummary! + (results.failures.isEmpty ? "" : " Échecs : " + results.failures.prefix(3).joined(separator: " ; "))
            }
            moving = false
            cleanProgress = ""
            hasScanned = true
            completion?(results.moved.count, results.freed)
        }
    }
}

