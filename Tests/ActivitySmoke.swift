import Foundation

@main
struct ActivitySmoke {
    static func main() {
        let suite = "macclair.activity.test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let store = ActivityStore(defaults: defaults, key: "k")
        precondition(store.events.isEmpty)

        store.record(kind: "A", freed: 100, moved: 2)
        store.record(kind: "B", freed: 50, moved: 1)
        precondition(store.events.count == 2)
        precondition(store.totalFreed == 150)
        precondition(store.totalItems == 3)
        precondition(store.totalCleanings == 2)
        precondition(store.lastEvent?.kind == "B")

        // Persistance : un nouvel instance relit les mêmes données.
        let reloaded = ActivityStore(defaults: defaults, key: "k")
        precondition(reloaded.events.count == 2 && reloaded.totalFreed == 150)

        // Un enregistrement vide est ignoré.
        store.record(kind: "C", freed: 0, moved: 0)
        precondition(store.events.count == 2)

        store.reset()
        precondition(store.events.isEmpty)
        precondition(ActivityStore(defaults: defaults, key: "k").events.isEmpty)

        print("ActivitySmoke OK: enregistrement, totaux, persistance et réinitialisation")
    }
}
