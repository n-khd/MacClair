import Foundation
import AppKit

// MCP over stdio: stdout is reserved exclusively for newline-delimited JSON-RPC.
struct MCPServer {
    private var prepared: [String: TrashCandidate] = [:]
    private let supportedVersions = ["2025-06-18", "2025-03-26", "2024-11-05"]
    private let tools: [[String: Any]] = [
        ["name": "scan_downloads", "description": "Analyse locale en lecture seule des gros fichiers et doublons exacts dans Téléchargements. Les chemins sont des données personnelles. Les très gros fichiers peuvent allonger l’analyse.", "inputSchema": ["type": "object", "properties": [:], "additionalProperties": false], "annotations": ["readOnlyHint": true, "destructiveHint": false, "openWorldHint": false]],
        ["name": "prepare_trash", "description": "Prépare un fichier ordinaire dans Téléchargements pour la Corbeille. Retourne un jeton valable uniquement dans cette session, sans modifier le fichier.", "inputSchema": ["type": "object", "properties": ["path": ["type": "string", "description": "Chemin absolu du fichier"]], "required": ["path"], "additionalProperties": false], "annotations": ["readOnlyHint": true, "destructiveHint": false, "openWorldHint": false]],
        ["name": "move_to_trash", "description": "Demande une confirmation native à l’utilisateur puis déplace vers la Corbeille un fichier préparé et inchangé. Ne jamais appeler sans demande explicite de l’utilisateur.", "inputSchema": ["type": "object", "properties": ["token": ["type": "string"]], "required": ["token"], "additionalProperties": false], "annotations": ["readOnlyHint": false, "destructiveHint": true, "openWorldHint": false]],
        ["name": "scan_cleanup", "description": "Inventorie en lecture seule les anciens caches, journaux et installateurs. Aucun fichier n'est déplacé.", "inputSchema": ["type": "object", "properties": [:], "additionalProperties": false], "annotations": ["readOnlyHint": true, "destructiveHint": false, "openWorldHint": false]]
    ]

    mutating func run() {
        while let line = readLine() {
            guard let data = line.data(using: .utf8) else { continue }
            guard let value = try? JSONSerialization.jsonObject(with: data),
                  let request = value as? [String: Any] else {
                send(["jsonrpc": "2.0", "id": NSNull(), "error": ["code": -32700, "message": "Parse error"]])
                continue
            }
            guard let id = request["id"] else { continue }
            guard request["jsonrpc"] as? String == "2.0", let method = request["method"] as? String else {
                error(id, -32600, "Invalid Request"); continue
            }
            let params = request["params"] as? [String: Any] ?? [:]
            switch method {
            case "initialize":
                let requested = params["protocolVersion"] as? String ?? ""
                reply(id, ["protocolVersion": supportedVersions.contains(requested) ? requested : supportedVersions[0],
                           "capabilities": ["tools": [:]], "serverInfo": ["name": "MacClair", "version": "0.1.0"]])
            case "ping": reply(id, [:])
            case "tools/list": reply(id, ["tools": tools])
            case "tools/call":
                guard let name = params["name"] as? String,
                      params["arguments"] == nil || params["arguments"] is [String: Any] else {
                    error(id, -32602, "Invalid params"); continue
                }
                let args = params["arguments"] as? [String: Any] ?? [:]
                switch name {
                case "scan_downloads":
                    guard args.isEmpty else { error(id, -32602, "Invalid params"); continue }
                    let report = InsightScanner().scan()
                    let result: [String: Any] = [
                        "scannedFiles": report.scannedFiles, "limited": report.limited,
                        "unreadablePaths": report.unreadablePaths,
                        "largeFiles": report.largeFiles.prefix(50).map { ["path": $0.url.path, "bytes": $0.bytes] },
                        "duplicateGroups": report.duplicates.prefix(50).map { ["paths": $0.files.map(\.path), "bytesPerFile": $0.bytesPerFile] },
                        "largeFilesReturned": min(report.largeFiles.count, 50), "duplicateGroupsReturned": min(report.duplicates.count, 50),
                        "duplicateGroupsTotal": report.duplicates.count,
                        "limitations": "Résultats limités à 50 éléments par catégorie ; dossiers cachés et paquets exclus."
                    ]
                    toolReply(id, result)
                case "scan_cleanup":
                    guard args.isEmpty else { error(id, -32602, "Invalid params"); continue }
                    let report = Cleaner().scan()
                    let items: [[String: Any]] = report.items.prefix(100).map {
                        ["path": $0.id.path, "category": $0.category.rawValue, "bytes": $0.bytes]
                    }
                    toolReply(id, ["items": items, "totalItems": report.items.count,
                                   "unreadablePaths": report.unreadablePaths, "limited": report.stoppedAtLimit,
                                   "limitations": "Résultats limités à 100 éléments ; fichiers de moins de 30 jours exclus."])
                case "prepare_trash":
                    guard args.count == 1, let path = args["path"] as? String, path.hasPrefix("/") else {
                        error(id, -32602, "Invalid params"); continue
                    }
                    do {
                        let candidate = try SafeTrash().capture(URL(fileURLWithPath: path))
                        let token = UUID().uuidString
                        prepared[token] = candidate
                        toolReply(id, ["token": token, "path": candidate.url.path, "bytes": candidate.bytes,
                                       "message": "Aucun déplacement effectué. La confirmation de l’utilisateur sera demandée avant le déplacement."])
                    } catch { toolError(id, error.localizedDescription) }
                case "move_to_trash":
                    guard args.count == 1, let token = args["token"] as? String,
                          let candidate = prepared.removeValue(forKey: token) else {
                        error(id, -32602, "Jeton inconnu ou déjà utilisé"); continue
                    }
                    do {
                        try SafeTrash().validate(candidate)
                        guard confirm(candidate) else { toolError(id, "Déplacement annulé par l’utilisateur."); continue }
                        try SafeTrash().moveToTrash(candidate)
                        toolReply(id, ["path": candidate.url.path, "message": "Fichier déplacé vers la Corbeille."])
                    } catch { toolError(id, error.localizedDescription) }
                default: error(id, -32602, "Unknown tool")
                }
            default: error(id, -32601, "Method not found")
            }
        }
    }

    private func confirm(_ candidate: TrashCandidate) -> Bool {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        app.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Autoriser le déplacement vers la Corbeille ?"
        alert.informativeText = "Un agent demande à déplacer ce fichier :\n\n\(candidate.url.path)\n\nTaille : \(candidate.bytes) octets. Vérifiez ce fichier avant de confirmer."
        alert.addButton(withTitle: "Déplacer vers la Corbeille")
        alert.addButton(withTitle: "Annuler")
        return alert.runModal() == .alertFirstButtonReturn
    }
    private func toolError(_ id: Any, _ message: String) {
        reply(id, ["content": [["type": "text", "text": message]], "isError": true])
    }
    private func toolReply(_ id: Any, _ result: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: result, options: [.sortedKeys]),
              let text = String(data: data, encoding: .utf8) else {
            error(id, -32603, "Internal error"); return
        }
        reply(id, ["content": [["type": "text", "text": text]]])
    }
    private func reply(_ id: Any, _ result: [String: Any]) { send(["jsonrpc": "2.0", "id": id, "result": result]) }
    private func error(_ id: Any, _ code: Int, _ message: String) { send(["jsonrpc": "2.0", "id": id, "error": ["code": code, "message": message]]) }
    private func send(_ object: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]) else { return }
        FileHandle.standardOutput.write(data)
        FileHandle.standardOutput.write(Data([10]))
    }
}

var server = MCPServer()
server.run()
