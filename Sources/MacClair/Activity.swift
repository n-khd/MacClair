import Foundation
import Observation

/// Un nettoyage réalisé par MacClair, conservé localement pour l'historique.
struct ActivityEvent: Codable, Identifiable, Sendable {
    let id: UUID
    let date: Date
    let kind: String
    let freedBytes: Int64
    let movedCount: Int
}

/// Historique persistant des nettoyages (UserDefaults). Ne contient que des
/// métadonnées agrégées : aucune nom ni chemin de fichier n'est conservé.
@Observable
final class ActivityStore {
    private(set) var events: [ActivityEvent] = []
    private let defaults: UserDefaults
    private let key: String

    init(defaults: UserDefaults = .standard, key: String = "macclair.activity.v1") {
        self.defaults = defaults
        self.key = key
        load()
    }

    var totalFreed: Int64 { events.reduce(0) { $0 + $1.freedBytes } }
    var totalItems: Int { events.reduce(0) { $0 + $1.movedCount } }
    var totalCleanings: Int { events.count }
    var lastEvent: ActivityEvent? { events.first }

    func record(kind: String, freed: Int64, moved: Int) {
        guard moved > 0 || freed > 0 else { return }
        events.insert(ActivityEvent(id: UUID(), date: Date(), kind: kind, freedBytes: freed, movedCount: moved), at: 0)
        if events.count > 200 { events.removeLast(events.count - 200) }
        save()
    }

    func reset() {
        events.removeAll()
        save()
    }

    private func load() {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([ActivityEvent].self, from: data) else { return }
        events = decoded
    }

    private func save() {
        if let data = try? JSONEncoder().encode(events) {
            defaults.set(data, forKey: key)
        }
    }
}
