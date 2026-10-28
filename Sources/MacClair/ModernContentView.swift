import SwiftUI

private enum Module: String, CaseIterable, Identifiable {
    case smart = "Entretien intelligent"
    case cleaning = "Nettoyage"
    case protection = "Protection"
    case performance = "Performances"
    case apps = "Applications"
    case clutter = "Mes fichiers inutiles"
    case lens = "Télescope"
    case cloud = "Nettoyage cloud"
    case tools = "Mes outils"
    case activity = "Mon activité"

    var id: String { rawValue }
    var icon: String {
        switch self {
        case .smart: "sparkles"
        case .cleaning: "wind"
        case .protection: "shield.lefthalf.filled"
        case .performance: "gauge.with.dots.needle.67percent"
        case .apps: "square.grid.2x2.fill"
        case .clutter: "square.stack.3d.up.fill"
        case .lens: "viewfinder"
        case .cloud: "icloud.fill"
        case .tools: "wrench.and.screwdriver.fill"
        case .activity: "chart.bar.fill"
        }
    }
    var subtitle: String {
        switch self {
        case .smart: "Une vue claire de votre Mac"
        case .cleaning: "Repérez les fichiers temporaires"
        case .protection: "Vérifiez les protections du système"
        case .performance: "Surveillez les ressources et le démarrage"
        case .apps: "Explorez les applications installées"
        case .clutter: "Retrouvez les fichiers qui occupent de la place"
        case .lens: "Visualisez le stockage de vos dossiers"
        case .cloud: "Inspectez les dossiers synchronisés locaux"
        case .tools: "Des outils ciblés pour vos fichiers"
        case .activity: "Suivez les analyses de MacClair"
        }
    }
}

private struct Capability: Identifiable {
    let title: String
    let detail: String
    let icon: String
    let available: Bool
    var id: String { title }
}

private enum ClutterTab: String, CaseIterable, Identifiable {
    case large = "Gros fichiers"
    case duplicates = "Doublons"
    case images = "Images similaires"
    case installers = "Installateurs"
    var id: String { rawValue }
}

@MainActor
struct ModernContentView: View {
    @State private var model = CleanupModel()
    @State private var module: Module = .smart
    @State private var storage: StorageAudit?
    @State private var storageRoot = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads")
    @State private var startup: [StartupItem] = []
    @State private var auditingStorage = false
    @State private var imageAudit: ImageAudit?
    @State private var auditingImages = false
    @State private var showTrashConfirmation = false
    @State private var showFileTrashConfirmation = false
    @State private var clutterTab: ClutterTab = .large
    @State private var clutterRoot = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads")
    @State private var selectedFiles: [URL: TrashCandidate] = [:]
    @State private var duplicateKeepers = Set<URL>()
    @State private var selectingDuplicates = false
    @State private var bulkDuplicateSelection = false
    @State private var bulkIncludedRisky = false
    @State private var includeProjectAndOtherFolders = false
    @State private var trashBusy = false
    @State private var trashFeedback: String?
    @State private var visibleDuplicateGroups = 20
    @AppStorage("macclair.scanCount") private var scanCount = 0
    @AppStorage("macclair.lastScan") private var lastScan = 0.0

    private let ink = Color(red: 0.08, green: 0.07, blue: 0.20)
    private let panel = Color(red: 0.13, green: 0.12, blue: 0.29)
    private let pink = Color(red: 0.98, green: 0.30, blue: 0.64)
    private let soft = Color.white.opacity(0.66)

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    title
                    if module == .smart { smartHero }
                    moduleBody
                }
                .frame(maxWidth: 1050, alignment: .leading)
                .padding(36)
            }
            .background(LinearGradient(colors: [Color(red: 0.13, green: 0.11, blue: 0.32), ink],
                                       startPoint: .topLeading, endPoint: .bottomTrailing))
        }
        .preferredColorScheme(.dark)
        .alert("Déplacer vers la Corbeille ?", isPresented: $showTrashConfirmation) {
            Button("Annuler", role: .cancel) {}
            Button("Déplacer \(model.selectedCount) fichier(s)", role: .destructive) { model.moveSelectedToTrash() }
        } message: {
            Text("Vérifiez votre sélection. Seuls les fichiers d’installation de Téléchargements seront déplacés. Taille : \(size(model.selectedBytes)).")
        }
        .alert("Déplacer les fichiers sélectionnés ?", isPresented: $showFileTrashConfirmation) {
            Button("Annuler", role: .cancel) {}
            Button("Déplacer \(selectedFiles.count) fichier(s)", role: .destructive) { moveSelectedFiles() }
        } message: {
            Text("Ces fichiers de Téléchargements seront déplacés vers la Corbeille et pourront y être restaurés. \(bulkDuplicateSelection ? "Une copie est conservée dans chaque groupe de doublons. " : "")\(bulkIncludedRisky ? "Des fichiers de projets ou de dossiers différents peuvent être inclus. " : "")Taille : \(size(selectedFileBytes)).")
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 11) {
                Image(systemName: "sparkle.magnifyingglass")
                    .font(.title2).foregroundStyle(pink)
                Text("MacClair").font(.title2.bold())
            }
            .padding(.horizontal, 22).padding(.top, 30).padding(.bottom, 24)
            ForEach(Module.allCases) { item in
                Button { module = item } label: {
                    HStack(spacing: 14) {
                        Image(systemName: item.icon).frame(width: 22)
                        Text(item.rawValue).frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .font(.system(size: 14, weight: module == item ? .semibold : .medium))
                    .foregroundStyle(module == item ? .white : soft)
                    .padding(.horizontal, 16).padding(.vertical, 12)
                    .background(module == item ? Color.white.opacity(0.13) : .clear,
                                in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
            }
            Spacer()
            HStack(spacing: 8) {
                Image(systemName: "lock.shield.fill").foregroundStyle(.mint)
                Text("Actions sûres et explicites")
            }
            .font(.caption).foregroundStyle(soft)
            .padding(22)
        }
        .frame(width: 248)
        .background(Color(red: 0.09, green: 0.08, blue: 0.22))
    }

    private var title: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                Text(module.rawValue).font(.system(size: 34, weight: .bold, design: .rounded))
                Text(module.subtitle).font(.title3).foregroundStyle(soft)
            }
            Spacer()
            Button(action: runScan) {
                Label(model.scanning ? "Analyse…" : "Analyser le Mac", systemImage: "magnifyingglass")
                    .fontWeight(.semibold)
            }
            .buttonStyle(.borderedProminent).tint(pink)
            .disabled(model.scanning || model.moving)
        }
    }

    private var smartHero: some View {
        HStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Votre Mac, en toute confiance")
                    .font(.system(size: 29, weight: .bold, design: .rounded))
                Text("Comprenez ce qui occupe l’espace, repérez les doublons et choisissez chaque action. Aucun nettoyage automatique.")
                    .font(.system(size: 15)).foregroundStyle(soft)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 10) {
                    Button(action: runScan) {
                        Label("Lancer l’analyse", systemImage: "sparkles")
                            .fontWeight(.bold).padding(.horizontal, 10).padding(.vertical, 5)
                    }
                    .buttonStyle(.borderedProminent).tint(pink)
                    .disabled(model.scanning)
                    Button("Voir les fichiers") { module = .clutter }
                        .buttonStyle(.bordered)
                }
            }
            Spacer(minLength: 5)
            if let image = NSImage(contentsOfFile: Bundle.main.path(forResource: "hero-storage", ofType: "png") ?? "") {
                Image(nsImage: image).resizable().scaledToFit().frame(width: 230, height: 200)
            } else {
                Image(systemName: "externaldrive.fill.badge.checkmark").font(.system(size: 96)).foregroundStyle(pink)
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity, minHeight: 238)
        .background(LinearGradient(colors: [Color(red: 0.30, green: 0.23, blue: 0.64),
                                            Color(red: 0.15, green: 0.18, blue: 0.44)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 24))
    }

    @ViewBuilder private var moduleBody: some View {
        switch module {
        case .smart:
            stats
            if let report = model.insights {
                section("À explorer") {
                    HStack(spacing: 12) {
                        metric("Gros fichiers", "\(report.largeFiles.count)", "externaldrive")
                        metric("Groupes de doublons", "\(report.duplicates.count)", "square.on.square")
                        metric("Applications", "\(report.apps.count)", "app.fill")
                    }
                    Button("Examiner les fichiers et choisir une action") { module = .clutter }
                        .buttonStyle(.borderedProminent).tint(pink)
                }
            } else { empty("Lancez une analyse pour obtenir un aperçu de votre Mac.") }
        case .cleaning:
            capabilities([
                .init(title: "Fichiers système inutiles", detail: "Caches et journaux de votre compte, en lecture seule", icon: "folder.fill", available: true),
                .init(title: "Fichiers IA inutiles", detail: "Analyse spécialisée à venir", icon: "sparkles.rectangle.stack", available: false),
                .init(title: "Pièces jointes Mail", detail: "Analyse spécialisée à venir", icon: "envelope.fill", available: false),
                .init(title: "Corbeilles", detail: "Ouverture dans le Finder uniquement", icon: "trash.fill", available: true)
            ])
            cleanupList(categories: [.caches, .logs])
            Button("Ouvrir la Corbeille dans le Finder") { NSWorkspace.shared.open(FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".Trash")) }
                .buttonStyle(.bordered)
        case .protection:
            capabilities([
                .init(title: "Protections macOS", detail: "FileVault, Gatekeeper et intégrité du système", icon: "checkmark.shield", available: true),
                .init(title: "Analyse des malwares", detail: "Moteur antivirus requis", icon: "shield.fill", available: false),
                .init(title: "Confidentialité", detail: "Audit détaillé à venir", icon: "hand.raised.fill", available: false),
                .init(title: "Autorisations des apps", detail: "Ouvrez les réglages de confidentialité", icon: "checkmark.seal.fill", available: true)
            ])
            if let report = model.insights {
                section("État de macOS") {
                    status("FileVault", report.security.fileVault)
                    status("Gatekeeper", report.security.gatekeeper)
                    status("Intégrité du système", report.security.systemIntegrity)
                }
            }
            Button("Ouvrir Confidentialité et sécurité") { NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security")!) }
                .buttonStyle(.bordered)
        case .performance:
            capabilities([
                .init(title: "Vue des ressources", detail: "Espace disque, mémoire et processeurs", icon: "gauge.high", available: true),
                .init(title: "Éléments d’ouverture", detail: "Inventaire des agents et services de démarrage", icon: "power", available: true),
                .init(title: "Tâches d’entretien", detail: "Commandes système non automatisées", icon: "wand.and.stars", available: false),
                .init(title: "Éléments d’arrière-plan", detail: "Gérez-les dans Réglages Système", icon: "clock.arrow.circlepath", available: true)
            ])
            if let report = model.insights {
                HStack(spacing: 12) {
                    metric("Espace libre", size(report.system.available), "internaldrive")
                    metric("Mémoire", size(Int64(report.system.memory)), "memorychip")
                    metric("Cœurs actifs", "\(report.system.processors)", "cpu")
                }
            }
            section("Agents et services détectés • \(startup.count)") {
                ForEach(startup.prefix(30)) { item in fileRow(item.url, trailing: item.kind) }
                if startup.count > 30 { Text("\(startup.count - 30) autres éléments non affichés").foregroundStyle(soft) }
            }
            Button("Ouvrir les éléments d’ouverture") { NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension")!) }
                .buttonStyle(.bordered)
        case .apps:
            capabilities([
                .init(title: "Inventaire des applications", detail: "Applications installées et versions", icon: "app.fill", available: true),
                .init(title: "Désinstallateur", detail: "Suppression guidée à venir", icon: "trash", available: false),
                .init(title: "Mises à jour", detail: "Ouvrez l’App Store", icon: "arrow.triangle.2.circlepath", available: true),
                .init(title: "Résidus de fichiers", detail: "Correspondance sûre à venir", icon: "doc.badge.gearshape", available: false)
            ])
            if let apps = model.insights?.apps {
                section("Applications installées • \(apps.count)") {
                    ForEach(apps.prefix(80)) { app in fileRow(app.url, trailing: app.version) }
                }
            }
            Button("Ouvrir l’App Store") { NSWorkspace.shared.open(URL(string: "macappstore://showUpdatesPage")!) }
                .buttonStyle(.bordered)
        case .clutter:
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Dossier analysé").font(.caption).foregroundStyle(soft)
                    Text(clutterRoot.path).font(.subheadline.weight(.semibold)).textSelection(.enabled)
                }
                Spacer()
                Button("Choisir un sous dossier…") { chooseClutterFolder() }
                    .buttonStyle(.bordered).disabled(model.scanning)
            }
            HStack(spacing: 10) {
                ForEach(ClutterTab.allCases) { tab in
                    Button(tab.rawValue) { clutterTab = tab }
                        .buttonStyle(.borderedProminent)
                        .tint(clutterTab == tab ? pink : panel)
                }
            }
            Text("Cliquez sur un nom pour le lire, ouvrez-le dans le Finder et cochez uniquement les fichiers à déplacer.")
                .font(.subheadline).foregroundStyle(soft)
            if model.insights?.limited == true {
                Text("Analyse partielle : limite de 10 000 fichiers atteinte. Choisissez un sous dossier pour obtenir un résultat plus complet.")
                    .font(.subheadline.weight(.semibold)).foregroundStyle(.orange)
            }
            if let trashFeedback { Text(trashFeedback).foregroundStyle(.mint) }
            if clutterTab != .installers { selectedFilesBar }
            switch clutterTab {
            case .large:
                if let report = model.insights {
                    section("Gros fichiers • \(report.largeFiles.count)") {
                        Text("Fichiers de 25 Mo ou plus, classés du plus gros au plus petit.")
                            .font(.caption).foregroundStyle(soft)
                        if report.largeFiles.isEmpty { Text("Aucun fichier de 25 Mo ou plus trouvé.").foregroundStyle(soft) }
                        ForEach(report.largeFiles) { file in
                            selectableFileRow(file.url, bytes: file.bytes)
                        }
                    }
                } else { empty("Cliquez sur « Analyser le Mac » pour voir les vrais fichiers.") }
            case .duplicates:
                if let report = model.insights {
                    section("Doublons exacts • \(report.duplicates.count) groupes") {
                        Text("Contenu vérifié par SHA-256. Au moins une copie reste dans chaque groupe.")
                            .font(.caption).foregroundStyle(soft)
                        Toggle("Inclure les copies de dossiers différents et de projets", isOn: $includeProjectAndOtherFolders)
                            .toggleStyle(.checkbox)
                        if includeProjectAndOtherFolders {
                            Text("Des projets peuvent utiliser chaque copie. Examinez les fichiers cochés avant de confirmer.")
                                .font(.caption).foregroundStyle(.orange)
                        } else {
                            Text("Par défaut, seuls les doublons du même dossier hors projets sont préparés.")
                                .font(.caption).foregroundStyle(soft)
                        }
                        Button {
                            selectRedundantDuplicates(report.duplicates.map(\.files))
                        } label: {
                            Label(selectingDuplicates ? "Préparation…" : "Nettoyer les doublons en lot…",
                                  systemImage: "checkmark.circle.fill")
                        }
                        .buttonStyle(.borderedProminent).tint(pink)
                        .disabled(report.duplicates.isEmpty || selectingDuplicates || model.scanning || trashBusy)
                        if report.duplicates.isEmpty { Text("Aucun doublon exact trouvé.").foregroundStyle(soft) }
                        ForEach(report.duplicates.prefix(visibleDuplicateGroups)) { group in
                            VStack(alignment: .leading, spacing: 9) {
                                Text("\(group.files.count) copies de \(size(group.bytesPerFile))")
                                    .font(.headline)
                                ForEach(group.files, id: \.self) { file in
                                    selectableFileRow(file, bytes: group.bytesPerFile,
                                                      kept: duplicateKeepers.contains(file))
                                }
                            }
                            .padding(.vertical, 10)
                            Divider()
                        }
                        if report.duplicates.count > visibleDuplicateGroups {
                            Button("Afficher 20 autres groupes") { visibleDuplicateGroups += 20 }
                                .buttonStyle(.bordered)
                        }
                    }
                } else { empty("Cliquez sur « Analyser le Mac » pour voir les doublons.") }
            case .images:
                Button("Chercher des images ressemblantes") { scanImages() }
                    .buttonStyle(.bordered).disabled(auditingImages)
                if auditingImages { ProgressView("Comparaison des images…") }
                if let imageAudit {
                    section("Images ressemblantes • \(imageAudit.pairs.count) paires possibles") {
                        Text("\(imageAudit.scanned) images comparées\(imageAudit.limited ? " • résultats partiels" : ""). Ces rapprochements sont des suggestions à vérifier visuellement.")
                            .font(.caption).foregroundStyle(soft)
                        if imageAudit.pairs.isEmpty { Text("Aucune paire proposée.").foregroundStyle(soft) }
                        ForEach(imageAudit.pairs.prefix(50)) { pair in
                            VStack(alignment: .leading, spacing: 7) {
                                selectableFileRow(pair.first)
                                selectableFileRow(pair.second)
                            }.padding(.vertical, 8)
                            Divider()
                        }
                    }
                }
            case .installers:
                cleanupList(categories: [.diskImages])
            }
        case .lens:
            capabilities([
                .init(title: "Cartographie du stockage", detail: "Tailles des éléments du dossier choisi", icon: "circle.grid.cross", available: true),
                .init(title: "Fichiers cachés", detail: "Inventaire des noms commençant par un point", icon: "eye.slash", available: true),
                .init(title: "Gros dossiers", detail: "Classement par taille, en lecture seule", icon: "folder.fill", available: true)
            ])
            HStack {
                Text("Dossier : \(storageRoot.path)").font(.caption).foregroundStyle(soft).lineLimit(1)
                Spacer()
                Button("Choisir un dossier…") { chooseStorageFolder() }.buttonStyle(.bordered)
                Button("Cartographier") { scanStorage() }.buttonStyle(.borderedProminent).tint(pink)
                    .disabled(auditingStorage)
            }
            if auditingStorage { ProgressView("Cartographie en cours…") }
            else if let storage {
                Text("\(storage.scannedFiles) fichiers analysés\(storage.limited ? " • limite de 20 000 atteinte" : "")")
                    .font(.caption).foregroundStyle(soft)
                section("Dossiers et fichiers les plus volumineux") {
                    ForEach(storage.folders.prefix(50)) { folder in
                        VStack(alignment: .leading, spacing: 5) {
                            fileRow(folder.url, trailing: size(folder.bytes))
                            GeometryReader { geo in
                                RoundedRectangle(cornerRadius: 3).fill(pink.opacity(0.85))
                                    .frame(width: max(4, geo.size.width * CGFloat(folder.bytes) / CGFloat(max(1, storage.folders.first?.bytes ?? 1))), height: 6)
                            }.frame(height: 6)
                        }.padding(.vertical, 3)
                    }
                }
                section("Fichiers cachés • \(storage.hidden.count) affichés") {
                    ForEach(storage.hidden, id: \.self) { file in fileRow(file) }
                    if storage.hidden.isEmpty { Text("Aucun fichier caché repéré dans la limite de l’analyse.").foregroundStyle(soft) }
                }
            } else { empty("Choisissez un dossier puis lancez la cartographie.") }
        case .cloud:
            capabilities([
                .init(title: "iCloud Drive", detail: "Dossier local uniquement", icon: "icloud.fill", available: true),
                .init(title: "Dropbox", detail: "Dossier local uniquement", icon: "shippingbox.fill", available: true),
                .init(title: "Google Drive", detail: "Dossier local uniquement", icon: "externaldrive.fill", available: true),
                .init(title: "OneDrive", detail: "Dossier local uniquement", icon: "cloud.fill", available: true)
            ])
            section("Dossiers synchronisés détectés") {
                ForEach(cloudFolders, id: \.self) { url in fileRow(url) }
                if cloudFolders.isEmpty { Text("Aucun dossier local détecté.").foregroundStyle(soft) }
            }
            Text("Aucune connexion OAuth ou suppression de fichiers synchronisés.")
                .font(.caption).foregroundStyle(soft)
        case .tools:
            capabilities([
                .init(title: "Installateurs anciens", detail: "Sélection puis déplacement à la Corbeille", icon: "archivebox.fill", available: true),
                .init(title: "Entretien du navigateur", detail: "Nettoyage dédié à venir", icon: "safari.fill", available: false),
                .init(title: "Nettoyage des e-mails", detail: "Connexion Mail à venir", icon: "envelope.fill", available: false),
                .init(title: "Nettoyage de l’écran", detail: "Mode dédié à venir", icon: "display", available: false)
            ])
            cleanupList(categories: [.diskImages])
        case .activity:
            HStack(spacing: 12) {
                metric("Analyses lancées", "\(scanCount)", "magnifyingglass")
                metric("Dernière analyse", lastScan > 0 ? Date(timeIntervalSince1970: lastScan).formatted(date: .abbreviated, time: .shortened) : "—", "clock")
            }
            Text("Les compteurs sont conservés localement sur ce Mac. Ils ne mesurent que l’activité de MacClair.")
                .font(.caption).foregroundStyle(soft)
        }
    }

    private var stats: some View {
        HStack(spacing: 12) {
            metric("Éléments repérés", "\(model.items.count)", "doc.on.doc")
            metric("Espace repéré", size(model.totalBytes), "internaldrive")
            metric("À confirmer", size(model.selectedBytes), "checkmark.circle")
        }
    }

    private func capabilities(_ items: [Capability]) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(items) { item in
                HStack(alignment: .top, spacing: 13) {
                    Image(systemName: item.icon).font(.title3).foregroundStyle(item.available ? pink : soft)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(item.title).fontWeight(.semibold)
                        Text(item.detail).font(.caption).foregroundStyle(soft)
                        Text(item.available ? "Disponible" : "À venir")
                            .font(.caption2.bold()).foregroundStyle(item.available ? .mint : .orange)
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, minHeight: 80, alignment: .topLeading)
                .padding(16).background(panel, in: RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    private func section<Content: View>(_ heading: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(heading).font(.title3.bold())
            VStack(alignment: .leading, spacing: 12, content: content)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(18).background(panel, in: RoundedRectangle(cornerRadius: 18))
        }
    }

    private func metric(_ heading: String, _ value: String, _ symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Image(systemName: symbol).font(.title3).foregroundStyle(pink)
            Text(value).font(.title3.bold()).lineLimit(1).minimumScaleFactor(0.7)
            Text(heading).font(.caption).foregroundStyle(soft)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18).background(panel, in: RoundedRectangle(cornerRadius: 16))
    }

    private func status(_ heading: String, _ detail: String) -> some View {
        HStack {
            Text(heading).fontWeight(.semibold)
            Spacer()
            Text(detail).font(.caption).foregroundStyle(soft).lineLimit(2)
        }
        .padding(.vertical, 5)
    }

    private func fileRow(_ url: URL, trailing: String = "") -> some View {
        HStack(spacing: 10) {
            Image(systemName: "doc.fill").foregroundStyle(pink).frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(url.lastPathComponent).lineLimit(1)
                Text(url.deletingLastPathComponent().path).font(.caption2).foregroundStyle(soft).lineLimit(1)
            }
            Spacer()
            Text(trailing).font(.caption).foregroundStyle(soft).lineLimit(1)
            Button("Finder") { NSWorkspace.shared.activateFileViewerSelecting([url]) }
                .buttonStyle(.borderless).font(.caption)
        }
    }

    private var selectedFileBytes: Int64 {
        selectedFiles.values.reduce(0) { $0 + $1.bytes }
    }

    private var selectedFilesBar: some View {
        HStack(spacing: 14) {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(pink)
            Text("\(selectedFiles.count) fichier(s) sélectionné(s) • \(size(selectedFileBytes))")
                .fontWeight(.semibold)
            Spacer()
            if !selectedFiles.isEmpty {
                Button("Effacer la sélection") {
                    selectedFiles.removeAll()
                    duplicateKeepers.removeAll()
                    bulkDuplicateSelection = false
                    bulkIncludedRisky = false
                }.buttonStyle(.borderless)
            }
            Button("Déplacer vers la Corbeille") { showFileTrashConfirmation = true }
                .buttonStyle(.borderedProminent).tint(pink)
                .disabled(selectedFiles.isEmpty || trashBusy || model.scanning)
        }
        .padding(16)
        .background(panel, in: RoundedRectangle(cornerRadius: 16))
    }

    private func selectableFileRow(_ url: URL, bytes: Int64? = nil, kept: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Toggle("Sélectionner \(url.lastPathComponent)", isOn: Binding(
                get: { selectedFiles[url] != nil },
                set: { setSelected(url, $0) }
            ))
            .labelsHidden()
            .help("Sélectionner \(url.lastPathComponent)")
            VStack(alignment: .leading, spacing: 5) {
                Text(url.lastPathComponent)
                    .font(.system(size: 14, weight: .semibold))
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                Text(url.path)
                    .font(.caption)
                    .foregroundStyle(soft)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            if kept { Text("Copie conservée").font(.caption.bold()).foregroundStyle(.mint) }
            if let bytes { Text(size(bytes)).font(.caption).monospacedDigit().foregroundStyle(soft) }
            Button("Finder") { NSWorkspace.shared.activateFileViewerSelecting([url]) }
                .buttonStyle(.borderless).font(.caption)
        }
        .padding(.vertical, 5)
    }

    private func setSelected(_ url: URL, _ value: Bool) {
        duplicateKeepers.removeAll()
        bulkDuplicateSelection = false
        bulkIncludedRisky = false
        if !value { selectedFiles.removeValue(forKey: url); return }
        do {
            let newSelection = Set(selectedFiles.keys).union([url])
            try SafeTrash().validateDuplicateSelection(newSelection,
                groups: model.insights?.duplicates.map(\.files) ?? [])
            selectedFiles[url] = try SafeTrash().capture(url)
            trashFeedback = nil
        } catch {
            trashFeedback = error.localizedDescription
        }
    }

    private func selectRedundantDuplicates(_ groups: [[URL]]) {
        guard !selectingDuplicates && !trashBusy else { return }
        selectingDuplicates = true
        let include = includeProjectAndOtherFolders
        Task {
            let plan = await Task.detached(priority: .userInitiated) {
                SafeTrash().planRedundantDuplicates(groups: groups,
                    includeProjectAndOtherFolders: include)
            }.value
            selectingDuplicates = false
            selectedFiles = plan.selected
            duplicateKeepers = plan.keepers
            bulkDuplicateSelection = true
            bulkIncludedRisky = include
            if plan.selected.isEmpty {
                trashFeedback = "Aucune copie préparée. \(plan.groupsSkipped) groupe(s) réparti(s) entre dossiers ou projets ont été ignorés. Activez l’option ci-dessus pour les inclure après vérification."
            } else {
                trashFeedback = "\(plan.selected.count) copie(s) préparée(s) dans \(plan.groupsPrepared) groupe(s). \(plan.groupsSkipped) groupe(s) ignoré(s), \(plan.protectedFiles) fichier(s) protégé(s)."
                showFileTrashConfirmation = true
            }
        }
    }

    private func moveSelectedFiles() {
        guard !selectedFiles.isEmpty && !trashBusy else { return }
        let candidates = Array(selectedFiles.values)
        let groups = model.insights?.duplicates.map(\.files) ?? []
        do {
            try SafeTrash().validateDuplicateSelection(Set(candidates.map(\.url)), groups: groups)
        } catch {
            trashFeedback = error.localizedDescription
            return
        }
        trashBusy = true
        Task {
            let outcome = await Task.detached(priority: .userInitiated) { () -> (Int, [String]) in
                let trash = SafeTrash()
                var count = 0
                var failures: [String] = []
                for candidate in candidates {
                    do {
                        try trash.moveToTrash(candidate)
                        count += 1
                    } catch {
                        failures.append("\(candidate.url.lastPathComponent) : \(error.localizedDescription)")
                    }
                }
                return (count, failures)
            }.value
            selectedFiles.removeAll()
            duplicateKeepers.removeAll()
            bulkDuplicateSelection = false
            bulkIncludedRisky = false
            imageAudit = nil
            trashBusy = false
            trashFeedback = "\(outcome.0) fichier(s) déplacé(s) vers la Corbeille." +
                (outcome.1.isEmpty ? "" : " Échecs : " + outcome.1.prefix(3).joined(separator: " ; "))
            model.scan(insightRoot: clutterRoot)
        }
    }

    private func cleanupList(categories: Set<CleanupCategory>) -> some View {
        let items = model.items.filter { categories.contains($0.category) }
        return section("Fichiers repérés • \(items.count)") {
            if model.scanning { ProgressView("Analyse en cours…") }
            else if !model.hasScanned { Text("Lancez l’analyse pour afficher les fichiers.").foregroundStyle(soft) }
            else if items.isEmpty { Text("Aucun fichier de plus de 30 jours repéré.").foregroundStyle(soft) }
            else {
                ForEach(items.prefix(100)) { item in
                    HStack(spacing: 10) {
                        if item.canMoveToTrash {
                            Toggle("", isOn: Binding(
                                get: { model.items.first(where: { $0.id == item.id })?.selected ?? false },
                                set: { value in
                                    if let i = model.items.firstIndex(where: { $0.id == item.id }) { model.items[i].selected = value }
                                }
                            )).labelsHidden()
                        } else { Image(systemName: "lock.shield").foregroundStyle(soft).frame(width: 20) }
                        fileRow(item.id, trailing: size(item.bytes))
                    }
                }
                if items.count > 100 { Text("\(items.count - 100) autres résultats non affichés").font(.caption).foregroundStyle(soft) }
            }
            if categories.contains(.diskImages) {
                Button("Déplacer la sélection vers la Corbeille (\(model.selectedCount))") { showTrashConfirmation = true }
                    .buttonStyle(.borderedProminent).tint(pink)
                    .disabled(model.selectedCount == 0 || model.scanning || model.moving)
            }
            if let message = model.message { Text(message).font(.caption).foregroundStyle(soft) }
        }
    }

    private func empty(_ text: String) -> some View {
        HStack { Image(systemName: "sparkle.magnifyingglass"); Text(text) }
            .foregroundStyle(soft).frame(maxWidth: .infinity, minHeight: 100)
            .background(panel, in: RoundedRectangle(cornerRadius: 18))
    }

    private var cloudFolders: [URL] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let roots = [home.appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs"),
                     home.appendingPathComponent("Library/CloudStorage"),
                     home.appendingPathComponent("Dropbox")]
        let cloudStorage = roots[1]
        let nested = (try? FileManager.default.contentsOfDirectory(at: cloudStorage, includingPropertiesForKeys: nil)) ?? []
        return (roots + nested).filter { FileManager.default.fileExists(atPath: $0.path) }
    }

    private func runScan() {
        guard !model.scanning else { return }
        selectedFiles.removeAll()
        duplicateKeepers.removeAll()
        bulkDuplicateSelection = false
        bulkIncludedRisky = false
        trashFeedback = nil
        scanCount += 1
        lastScan = Date().timeIntervalSince1970
        model.scan(insightRoot: clutterRoot)
        startup = StartupAuditor().scan()
        if module == .lens { scanStorage() }
    }

    private func chooseStorageFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Cartographier"
        if panel.runModal() == .OK, let url = panel.url {
            storageRoot = url
            storage = nil
            scanStorage()
        }
    }

    private func chooseClutterFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads")
        panel.prompt = "Analyser ce dossier"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let downloads = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads").resolvingSymlinksInPath().standardizedFileURL.path
        let chosen = url.resolvingSymlinksInPath().standardizedFileURL.path
        guard chosen == downloads || chosen.hasPrefix(downloads + "/") else {
            trashFeedback = "Choisissez un dossier situé dans Téléchargements."
            return
        }
        clutterRoot = url
        selectedFiles.removeAll()
        trashFeedback = nil
        runScan()
    }

    private func scanStorage() {
        guard !auditingStorage else { return }
        auditingStorage = true
        let root = storageRoot
        Task {
            storage = await Task.detached(priority: .userInitiated) { StorageAuditor(root: root).scan() }.value
            auditingStorage = false
        }
    }

    private func scanImages() {
        guard !auditingImages else { return }
        auditingImages = true
        let root = clutterRoot
        Task {
            imageAudit = await Task.detached(priority: .userInitiated) { ImageAuditor(root: root).scan() }.value
            auditingImages = false
        }
    }

    private func size(_ bytes: Int64) -> String {
        if bytes == 0 { return "0 octet" }
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
