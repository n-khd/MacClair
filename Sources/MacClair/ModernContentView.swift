import SwiftUI
import AppKit

// MARK: - Modules

private enum Module: String, CaseIterable, Identifiable {
    case smart = "État du Mac"
    case cleaning = "Nettoyage"
    case protection = "Protection"
    case performance = "Performances"
    case apps = "Applications"
    case clutter = "Fichiers inutiles"
    case lens = "Télescope"
    case cloud = "Cloud"
    case tools = "Outils"
    case activity = "Activité"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .smart: "speedometer"
        case .cleaning: "broom.fill"
        case .protection: "lock.shield.fill"
        case .performance: "cpu.fill"
        case .apps: "square.grid.2x2.fill"
        case .clutter: "shippingbox.fill"
        case .lens: "chart.pie.fill"
        case .cloud: "icloud.fill"
        case .tools: "wrench.and.screwdriver.fill"
        case .activity: "chart.bar.fill"
        }
    }

    var subtitle: String {
        switch self {
        case .smart: "Diagnostic global et espace"
        case .cleaning: "Caches et journaux obsolètes"
        case .protection: "Sécurité et intégrité"
        case .performance: "Ressources et démarrage"
        case .apps: "Désinstallation et résidus"
        case .clutter: "Gros fichiers et doublons"
        case .lens: "Visualisation du disque"
        case .cloud: "Dossiers synchronisés"
        case .tools: "Installateurs anciens"
        case .activity: "Historique des nettoyages"
        }
    }

    var accentColor: Color {
        switch self {
        case .smart: MacClairTheme.cyan
        case .cleaning: MacClairTheme.mint
        case .protection: MacClairTheme.emerald
        case .performance: MacClairTheme.amber
        case .apps: MacClairTheme.purple
        case .clutter: MacClairTheme.azure
        case .lens: MacClairTheme.violet
        case .cloud: MacClairTheme.cyan
        case .tools: MacClairTheme.rose
        case .activity: MacClairTheme.emerald
        }
    }

    var gradient: LinearGradient {
        switch self {
        case .smart: MacClairTheme.gradientHero
        case .cleaning: MacClairTheme.gradientClean
        case .protection: MacClairTheme.gradientProtect
        case .performance: MacClairTheme.gradientPerf
        case .apps: MacClairTheme.gradientApps
        case .clutter: LinearGradient(colors: [MacClairTheme.azure, MacClairTheme.violet], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .lens: MacClairTheme.gradientLens
        case .cloud: LinearGradient(colors: [MacClairTheme.cyan, MacClairTheme.azure], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .tools: LinearGradient(colors: [MacClairTheme.rose, MacClairTheme.coral], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .activity: MacClairTheme.gradientClean
        }
    }
}

private struct Capability: Identifiable {
    let title: String
    let detail: String
    let icon: String
    var id: String { title }
}

private enum ClutterTab: String, CaseIterable, Identifiable {
    case large = "Gros fichiers"
    case duplicates = "Doublons"
    case images = "Images similaires"
    case installers = "Installateurs"
    var id: String { rawValue }
}

// MARK: - Modern Content View

@MainActor
struct ModernContentView: View {
    @State private var model = CleanupModel()
    @State private var activity = ActivityStore()
    @State private var module: Module = .smart
    @State private var hoveredModule: Module?
    @State private var storage: StorageAudit?
    @State private var privacyAudit: PrivacyAuditReport?
    @State private var auditingPrivacy = false
    @State private var storageRoot = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads")
    @State private var startup: [StartupItem] = []
    @State private var auditingStorage = false
    @State private var imageAudit: ImageAudit?
    @State private var auditingImages = false
    @State private var developerAudit: DeveloperJunkReport?
    @State private var auditingDeveloper = false
    @State private var showTrashConfirmation = false
    @State private var showSmartCleanConfirmation = false
    @State private var pendingUninstall: InstalledApp?
    @State private var uninstallPlan: AppUninstallPlan?
    @State private var showUninstallConfirmation = false
    @State private var uninstallFeedback: String?
    @State private var uninstalling = false
    @State private var removedApps = Set<URL>()
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

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    titleBar
                    if model.scanning {
                        ModernScanRadarBanner(
                            detail: model.insightProgress,
                            subdetail: model.cleanupProgress
                        )
                        .transition(.scale.combined(with: .opacity))
                    }
                    if module == .smart {
                        smartHero
                    }
                    if model.moving {
                        cleaningProgressBanner
                            .transition(.scale.combined(with: .opacity))
                    }
                    if module == .smart, let summary = model.cleanSummary {
                        cleanResultBanner(summary)
                            .transition(.scale.combined(with: .opacity))
                    }
                    Group {
                        moduleBody
                    }
                    .id(module)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .trailing)),
                        removal: .opacity
                    ))
                }
                .frame(maxWidth: 1080, alignment: .leading)
                .padding(.horizontal, 42)
                .padding(.top, 34)
                .padding(.bottom, 48)
            }
            .background { FluidAuroraBackground() }
        }
        .preferredColorScheme(.dark)
        .animation(.snappy(duration: 0.35), value: model.scanning)
        .animation(.snappy(duration: 0.35), value: model.moving)
        .animation(.snappy(duration: 0.35), value: module)
        .alert("Déplacer vers la Corbeille ?", isPresented: $showTrashConfirmation) {
            Button("Annuler", role: .cancel) {}
            Button("Déplacer \(model.selectedCount) élément(s)", role: .destructive) { moveCleanSelection() }
        } message: {
            Text("Taille : \(size(model.selectedBytes)). Restauration possible depuis la Corbeille.")
        }
        .alert("Nettoyer maintenant ?", isPresented: $showSmartCleanConfirmation) {
            Button("Annuler", role: .cancel) {}
            Button("Nettoyer \(model.recommendedCount) élément(s)", role: .destructive) { runSmartClean() }
        } message: {
            Text("\(size(model.recommendedBytes)) de caches et logs > 30 jours seront déplacés vers la Corbeille.")
        }
        .alert("Désinstaller \(pendingUninstall?.name ?? "l’application") ?", isPresented: $showUninstallConfirmation) {
            Button("Annuler", role: .cancel) { uninstallPlan = nil }
            Button("Déplacer vers la Corbeille", role: .destructive) { performUninstall() }
        } message: {
            if let plan = uninstallPlan {
                Text("\(plan.items.count) fichiers (\(size(plan.totalBytes))) : application et résidus (caches, préférences).")
            } else {
                Text("Calcul des résidus en cours…")
            }
        }
        .alert("Déplacer les fichiers sélectionnés ?", isPresented: $showFileTrashConfirmation) {
            Button("Annuler", role: .cancel) {}
            Button("Déplacer \(selectedFiles.count) fichier(s)", role: .destructive) { moveSelectedFiles() }
        } message: {
            Text("Taille : \(size(selectedFileBytes)). Déplacement réversible vers la Corbeille.")
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Living Animated App Icon & Logo Header
            HStack(spacing: 12) {
                LivingAnimatedAppIcon(size: 38)

                VStack(alignment: .leading, spacing: 2) {
                    Text("MacClair")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(MacClairTheme.textPrimary)

                    Text("OPTIMISEUR MAC")
                        .font(.system(size: 8.5, weight: .heavy))
                        .tracking(1.4)
                        .foregroundStyle(MacClairTheme.textTertiary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 40)
            .padding(.bottom, 22)

            // Navigation List
            ScrollView {
                VStack(alignment: .leading, spacing: 5) {
                    sidebarGroup("VUE D’ENSEMBLE", items: [.smart])
                    sidebarDivider
                    sidebarGroup("EXPLORER", items: [.cleaning, .protection, .performance, .apps, .clutter, .lens])
                    sidebarDivider
                    sidebarGroup("UTILITAIRES", items: [.cloud, .tools, .activity])
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }

            // Bottom Minimal Status
            HStack(spacing: 8) {
                Circle().fill(MacClairTheme.emerald).frame(width: 6, height: 6)
                    .shadow(color: MacClairTheme.emerald, radius: 3)
                Text("100% réversible via la Corbeille")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(MacClairTheme.textTertiary)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 18)
        }
        .frame(width: 256)
        .background(
            Color(red: 0.040, green: 0.052, blue: 0.082).opacity(0.97)
        )
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(width: 1)
        }
    }

    private var sidebarDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.06))
            .frame(height: 1)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
    }

    private func sidebarGroup(_ title: String, items: [Module]) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(LocalizedStringKey(title))
                .font(.system(size: 8.5, weight: .heavy))
                .tracking(1.4)
                .foregroundStyle(MacClairTheme.textTertiary)
                .padding(.horizontal, 12)
                .padding(.top, 6)
                .padding(.bottom, 3)

            ForEach(items) { item in
                sidebarRow(item)
            }
        }
    }

    private func sidebarRow(_ item: Module) -> some View {
        let active = module == item
        let hovered = hoveredModule == item

        return Button {
            withAnimation(.snappy(duration: 0.28)) {
                module = item
            }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(
                            active
                                ? AnyShapeStyle(item.gradient)
                                : AnyShapeStyle(Color.white.opacity(hovered ? 0.12 : 0.06))
                        )
                    Image(systemName: item.icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(
                            active
                                ? Color(red: 0.02, green: 0.05, blue: 0.12)
                                : (hovered ? Color.white : MacClairTheme.textSecondary)
                        )
                }
                .frame(width: 28, height: 28)
                .shadow(color: active ? item.accentColor.opacity(0.4) : Color.clear, radius: 6)

                Text(LocalizedStringKey(item.rawValue))
                    .font(.system(size: 13, weight: active ? .bold : .medium, design: .rounded))
                    .foregroundStyle(
                        active
                            ? MacClairTheme.textPrimary
                            : (hovered ? Color.white : MacClairTheme.textSecondary)
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)

                if active {
                    Circle()
                        .fill(item.accentColor)
                        .frame(width: 6, height: 6)
                        .shadow(color: item.accentColor, radius: 4)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(
                        active
                            ? Color.white.opacity(0.10)
                            : (hovered ? Color.white.opacity(0.05) : Color.clear)
                    )
            }
            .overlay {
                if active {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .strokeBorder(item.accentColor.opacity(0.35), lineWidth: 1)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { inside in
            if inside { hoveredModule = item }
            else if hoveredModule == item { hoveredModule = nil }
        }
    }

    // MARK: - Header / Title Bar (Minimalist)

    private var titleBar: some View {
        HStack(alignment: .center, spacing: 18) {
            VStack(alignment: .leading, spacing: 3) {
                Text(LocalizedStringKey(module.rawValue))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(MacClairTheme.textPrimary)

                Text(LocalizedStringKey(module.subtitle))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(MacClairTheme.textSecondary)
            }

            Spacer()

            if module != .smart {
                Button(action: runScan) {
                    HStack(spacing: 7) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12, weight: .bold))
                            .rotationEffect(.degrees(model.scanning ? 360 : 0))
                            .animation(model.scanning ? .linear(duration: 1.2).repeatForever(autoreverses: false) : .default, value: model.scanning)
                        Text(model.scanning ? LocalizedStringKey("Analyse…") : LocalizedStringKey("Analyser"))
                    }
                }
                .buttonStyle(ModernPrimaryButton(gradient: module.gradient))
                .disabled(model.scanning || model.moving)
            }
        }
    }

    // MARK: - Smart Hero Section (Concise & Minimal)

    private var smartHero: some View {
        HStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 14) {
                // Status pill
                HStack(spacing: 6) {
                    Circle()
                        .fill(model.scanning ? MacClairTheme.cyan : (model.hasScanned ? MacClairTheme.emerald : MacClairTheme.violet))
                        .frame(width: 7, height: 7)
                        .shadow(color: model.scanning ? MacClairTheme.cyan : MacClairTheme.emerald, radius: 4)

                    Text(model.scanning ? LocalizedStringKey("Analyse en cours…") : (model.hasScanned ? LocalizedStringKey("Diagnostic terminé") : LocalizedStringKey("Prêt à scanner")))
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(model.scanning ? MacClairTheme.cyan : (model.hasScanned ? MacClairTheme.emerald : MacClairTheme.cyan))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.white.opacity(0.08)))

                // Minimalist Headline
                Text(
                    model.scanning ? "Analyse du Mac…" :
                    (model.hasScanned ? (model.recommendedCount > 0 ? "\(size(model.recommendedBytes)) à libérer" : "Mac optimisé") : "Diagnostic de votre Mac")
                )
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(MacClairTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

                // Minimalist Subtext
                Text(
                    model.scanning ? "Recherche des caches, logs et doublons." :
                    (model.hasScanned ? (model.recommendedCount > 0 ? "\(model.recommendedCount) éléments anciens prêts pour la Corbeille." : "Aucun fichier superflu détecté.") : "Analyse rapide, sans risque et réversible.")
                )
                .font(.system(size: 13))
                .foregroundStyle(MacClairTheme.textSecondary)

                // Action buttons
                HStack(spacing: 12) {
                    if model.hasScanned && model.recommendedCount > 0 && !model.scanning {
                        Button { showSmartCleanConfirmation = true } label: {
                            Label("Nettoyer (\(size(model.recommendedBytes)))", systemImage: "broom.fill")
                        }
                        .buttonStyle(ModernPrimaryButton(gradient: MacClairTheme.gradientHero))
                        .disabled(model.moving)

                        Button("Re-scanner") { runScan() }
                            .buttonStyle(.bordered)
                            .disabled(model.scanning || model.moving)

                        Button("Détails") {
                            withAnimation { module = .cleaning }
                        }
                        .buttonStyle(.bordered)
                    } else {
                        Button(action: runScan) {
                            HStack(spacing: 7) {
                                Image(systemName: model.hasScanned ? "arrow.clockwise" : "play.fill")
                                Text(model.scanning ? LocalizedStringKey("Analyse…") : (model.hasScanned ? LocalizedStringKey("Re-scanner") : LocalizedStringKey("Lancer l’analyse")))
                            }
                        }
                        .buttonStyle(ModernPrimaryButton(gradient: MacClairTheme.gradientHero))
                        .disabled(model.scanning || model.moving)

                        if model.hasScanned {
                            Button("Explorer") {
                                withAnimation { module = .clutter }
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
                .padding(.top, 4)
            }

            Spacer(minLength: 0)

            // 3D Interactive Holographic Orb (SceneKit)
            CosmicOrb3DView(
                scanning: model.scanning,
                hasScanned: model.hasScanned,
                isSuccess: model.cleanSummary != nil
            )
        }
        .padding(28)
        .frame(maxWidth: .infinity, minHeight: 250, alignment: .leading)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.16, blue: 0.32).opacity(0.65),
                    Color(red: 0.11, green: 0.09, blue: 0.24).opacity(0.40)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
        .modifier(ModernGlassPanel(radius: 22, glowColor: MacClairTheme.cyan, glowIntensity: model.scanning ? 0.3 : 0.1))
        .modifier(Pointer3DCard(maxAngle: 8, glowColor: MacClairTheme.cyan))
    }

    // MARK: - Cleaning Progress Banner

    private var cleaningProgressBanner: some View {
        HStack(alignment: .center, spacing: 16) {
            ProgressView()
                .controlSize(.regular)
                .tint(MacClairTheme.cyan)

            VStack(alignment: .leading, spacing: 2) {
                Text("Déplacement vers la Corbeille…")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(MacClairTheme.textPrimary)
                Text(LocalizedStringKey(model.cleanProgress))
                    .font(.system(size: 12))
                    .foregroundStyle(MacClairTheme.textSecondary)
            }
            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(ModernGlassPanel(radius: 16, glowColor: MacClairTheme.cyan, glowIntensity: 0.2))
    }

    // MARK: - Clean Result Banner

    private func cleanResultBanner(_ summary: String) -> some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20))
                .foregroundStyle(MacClairTheme.emerald)

            VStack(alignment: .leading, spacing: 2) {
                Text("Nettoyage terminé")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(MacClairTheme.textPrimary)

                Text(LocalizedStringKey(summary))
                    .font(.system(size: 12))
                    .foregroundStyle(MacClairTheme.textSecondary)
            }
            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            MacClairTheme.emerald.opacity(0.15),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(MacClairTheme.emerald.opacity(0.35), lineWidth: 1)
        )
    }

    // MARK: - Module Body

    @ViewBuilder
    private var moduleBody: some View {
        switch module {
        case .smart:
            smartModuleView

        case .cleaning:
            cleaningModuleView

        case .protection:
            protectionModuleView

        case .performance:
            performanceModuleView

        case .apps:
            appsModuleView

        case .clutter:
            clutterModuleView

        case .lens:
            lensModuleView

        case .cloud:
            cloudModuleView

        case .tools:
            toolsModuleView

        case .activity:
            activityModuleView
        }
    }

    // MARK: - Subviews for Modules

    private var smartModuleView: some View {
        VStack(alignment: .leading, spacing: 18) {
            if model.hasScanned {
                // Storage Breakdown Bar
                if let report = model.insights {
                    let totalDisk = report.system.available + model.totalBytes + Int64(report.largeFiles.reduce(0) { $0 + $1.bytes })
                    ModernStorageBreakdownBar(
                        totalBytes: max(totalDisk, 100_000_000_000),
                        segments: [
                            .init(name: "Caches & Logs", bytes: model.totalBytes, color: MacClairTheme.cyan, icon: "bolt.fill"),
                            .init(name: "Gros fichiers", bytes: Int64(report.largeFiles.reduce(0) { $0 + $1.bytes }), color: MacClairTheme.purple, icon: "externaldrive.fill"),
                            .init(name: "Installateurs", bytes: Int64(model.items.filter { $0.category == .diskImages }.reduce(0) { $0 + $1.bytes }), color: MacClairTheme.amber, icon: "archivebox.fill")
                        ],
                        freeBytes: report.system.available
                    )
                }

                statsCards

                if let report = model.insights {
                    HStack(spacing: 12) {
                        metricCard("Gros fichiers", "\(report.largeFiles.count)", "externaldrive")
                        metricCard("Doublons", "\(report.duplicates.count)", "square.on.square")
                        metricCard("Applications", "\(report.apps.count)", "app.fill")
                    }
                }
            }

            // Scope & Safety Accordion (Minimal)
            DisclosureGroup("Détails & sécurité") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("• Caches et journaux > 30 jours uniquement.")
                    Text("• Doublons vérifiés par empreinte SHA-256 (copie protégée).")
                    Text("• Déplacements réversibles dans la Corbeille.")
                    if let report = model.insights {
                        Text(LocalizedStringKey("\(report.scannedFiles) fichiers examinés\(report.limited ? ") · limite atteinteLocalizedStringKey(" : ")LocalizedStringKey(")."))
                            .foregroundStyle(MacClairTheme.mint)
                    }
                }
                .font(.caption)
                .foregroundStyle(MacClairTheme.textSecondary)
                .padding(.top, 8)
            }
            .font(.subheadline.weight(.semibold))
            .padding(16)
            .modifier(ModernGlassPanel(radius: 16))
        }
    }

    private var cleaningModuleView: some View {
        VStack(alignment: .leading, spacing: 18) {
            capabilities([
                .init(title: "Caches système & apps", detail: "Fichiers temporaires > 30 jours", icon: "bolt.fill"),
                .init(title: "Navigateurs & Mail", detail: "Inventaire local en lecture seule", icon: "safari.fill"),
                .init(title: "Développement", detail: "DerivedData Xcode et simulateurs", icon: "hammer.fill"),
                .init(title: "Corbeille", detail: "Ouverture Finder directe", icon: "trash.fill")
            ])

            cleanupList(categories: [.caches, .logs])

            section("Navigateurs & Mail") {
                Button("Analyser caches navigateurs") { scanPrivacy() }
                    .buttonStyle(.bordered).disabled(auditingPrivacy)

                if auditingPrivacy { ProgressView() }

                if let audit = privacyAudit {
                    ForEach(audit.items) { item in
                        fileRow(item.url, trailing: "\(size(item.bytes))")
                    }
                }
            }

            section("Développement") {
                Button("Analyser caches Xcode") { scanDeveloper() }
                    .buttonStyle(.bordered).disabled(auditingDeveloper)

                if auditingDeveloper { ProgressView() }

                if let audit = developerAudit {
                    ForEach(audit.items) { item in
                        fileRow(item.url, trailing: "\(size(item.bytes))")
                    }
                }
            }

            Button("Ouvrir la Corbeille dans le Finder") {
                NSWorkspace.shared.open(FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".Trash"))
            }
            .buttonStyle(.bordered)
        }
    }

    private var protectionModuleView: some View {
        VStack(alignment: .leading, spacing: 18) {
            capabilities([
                .init(title: "FileVault", detail: "Chiffrement du disque", icon: "lock.shield.fill"),
                .init(title: "Gatekeeper", detail: "Signature des applications", icon: "checkmark.shield.fill"),
                .init(title: "SIP", detail: "Intégrité du système", icon: "shield.lefthalf.filled")
            ])

            if let report = model.insights {
                section("État de sécurité macOS") {
                    statusRow("FileVault", report.security.fileVault, isOK: report.security.fileVault.lowercased().contains("activ"))
                    Divider()
                    statusRow("Gatekeeper", report.security.gatekeeper, isOK: report.security.gatekeeper.lowercased().contains("activ"))
                    Divider()
                    statusRow("SIP (Intégrité)", report.security.systemIntegrity, isOK: report.security.systemIntegrity.lowercased().contains("activ"))
                }
            }

            Button("Réglages Sécurité macOS") {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security")!)
            }
            .buttonStyle(.bordered)
        }
    }

    private var performanceModuleView: some View {
        VStack(alignment: .leading, spacing: 18) {
            if let report = model.insights {
                let values = try? URL(fileURLWithPath: "/").resourceValues(forKeys: [.volumeTotalCapacityKey])
                let totalDisk = Int64(values?.volumeTotalCapacity ?? 500_000_000_000)
                let usedDisk = max(0, totalDisk - report.system.available)
                let diskPct = Double(usedDisk) / Double(max(1, totalDisk))

                HStack(spacing: 14) {
                    ModernRingGauge(
                        title: "Disque",
                        valueString: "\(size(report.system.available)) libres",
                        percentage: diskPct,
                        icon: "internaldrive.fill",
                        gradient: MacClairTheme.gradientHero,
                        glowColor: MacClairTheme.cyan
                    )

                    ModernRingGauge(
                        title: "Mémoire",
                        valueString: memory(Int64(report.system.memory)),
                        percentage: 0.65,
                        icon: "memorychip.fill",
                        gradient: MacClairTheme.gradientApps,
                        glowColor: MacClairTheme.purple
                    )

                    ModernRingGauge(
                        title: "Processeur",
                        valueString: "\(report.system.processors) cœurs",
                        percentage: 0.35,
                        icon: "cpu.fill",
                        gradient: MacClairTheme.gradientPerf,
                        glowColor: MacClairTheme.amber
                    )
                }
            }

            section("Ouverture & Démarrage (\(startup.count))") {
                ForEach(startup.prefix(20)) { item in
                    fileRow(item.url, trailing: item.broken ? "Cassé" : item.kind)
                }
            }

            Button("Gérer dans Réglages Système") {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension")!)
            }
            .buttonStyle(.bordered)
        }
    }

    private var appsModuleView: some View {
        VStack(alignment: .leading, spacing: 18) {
            if let feedback = uninstallFeedback {
                Label(feedback, systemImage: "checkmark.circle.fill")
                    .font(.caption.weight(.bold)).foregroundStyle(MacClairTheme.emerald)
            }
            if uninstalling { ProgressView("Désinstallation…") }

            if let apps = model.insights?.apps {
                let visible = apps.filter { !removedApps.contains($0.url) }
                section("Applications (\(visible.count))") {
                    ForEach(visible.prefix(80)) { app in appRow(app) }
                }
            } else {
                emptyState("Lancez l’analyse pour inventorier vos applications.")
            }
        }
    }

    private var clutterModuleView: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Clutter Tabs
            HStack(spacing: 8) {
                ForEach(ClutterTab.allCases) { tab in
                    Button {
                        withAnimation(.snappy(duration: 0.25)) { clutterTab = tab }
                    } label: {
                        Text(LocalizedStringKey(tab.rawValue))
                            .font(.system(size: 13, weight: clutterTab == tab ? .bold : .medium))
                            .foregroundStyle(clutterTab == tab ? Color(red: 0.02, green: 0.05, blue: 0.12) : MacClairTheme.textSecondary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(clutterTab == tab ? AnyShapeStyle(MacClairTheme.gradientHero) : AnyShapeStyle(Color.white.opacity(0.06)))
                            )
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
                Button("Changer de dossier…") { chooseClutterFolder() }
                    .buttonStyle(.bordered)
            }

            if clutterTab != .installers { selectedFilesBar }

            switch clutterTab {
            case .large:
                if let report = model.insights {
                    section("Gros fichiers (\(report.largeFiles.count))") {
                        if !report.largeFiles.isEmpty {
                            selectionHeader(urls: report.largeFiles.map(\.url))
                        }
                        ForEach(report.largeFiles) { file in
                            selectableFileRow(file.url, bytes: file.bytes)
                        }
                    }
                } else { emptyState("Lancez l’analyse pour voir les gros fichiers.") }

            case .duplicates:
                if let report = model.insights {
                    section("Doublons (\(report.duplicates.count) groupes)") {
                        Button {
                            selectRedundantDuplicates(report.duplicates.map(\.files))
                        } label: {
                            Label("Sélectionner les copies redondantes", systemImage: "checkmark.circle.fill")
                        }
                        .buttonStyle(ModernPrimaryButton(gradient: MacClairTheme.gradientHero))
                        .disabled(report.duplicates.isEmpty || selectingDuplicates || model.scanning || trashBusy)

                        ForEach(report.duplicates.prefix(visibleDuplicateGroups)) { group in
                            VStack(alignment: .leading, spacing: 6) {
                                Text("\(group.files.count) copies · \(size(group.bytesPerFile))")
                                    .font(.system(size: 12, weight: .bold))
                                ForEach(group.files, id: \.self) { file in
                                    selectableFileRow(file, bytes: group.bytesPerFile, kept: duplicateKeepers.contains(file))
                                }
                            }
                            .padding(.vertical, 4)
                            Divider()
                        }
                    }
                } else { emptyState("Lancez l’analyse pour repérer les doublons.") }

            case .images:
                Button("Rechercher images similaires") { scanImages() }
                    .buttonStyle(.bordered).disabled(auditingImages)
                if auditingImages { ProgressView() }
                if let imageAudit {
                    section("Images similaires (\(imageAudit.pairs.count))") {
                        ForEach(imageAudit.pairs.prefix(40)) { pair in
                            VStack(alignment: .leading, spacing: 4) {
                                selectableFileRow(pair.first)
                                selectableFileRow(pair.second)
                            }
                            .padding(.vertical, 4)
                            Divider()
                        }
                    }
                }

            case .installers:
                cleanupList(categories: [.diskImages])
            }
        }
    }

    private var lensModuleView: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Dossier : \(storageRoot.lastPathComponent)").font(.subheadline.bold())
                Spacer()
                Button("Choisir…") { chooseStorageFolder() }.buttonStyle(.bordered)
                Button("Cartographier") { scanStorage() }
                    .buttonStyle(ModernPrimaryButton(gradient: MacClairTheme.gradientLens))
                    .disabled(auditingStorage)
            }

            if auditingStorage { ProgressView() }
            else if let storage {
                section("Dossiers volumineux") {
                    ForEach(storage.folders.prefix(40)) { folder in
                        VStack(alignment: .leading, spacing: 4) {
                            fileRow(folder.url, trailing: size(folder.bytes))
                            GeometryReader { geo in
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(MacClairTheme.gradientLens)
                                    .frame(width: max(6, geo.size.width * CGFloat(folder.bytes) / CGFloat(max(1, storage.folders.first?.bytes ?? 1))), height: 5)
                            }
                            .frame(height: 5)
                        }
                        .padding(.vertical, 2)
                    }
                }
            } else { emptyState("Lancez la cartographie.") }
        }
    }

    private var cloudModuleView: some View {
        VStack(alignment: .leading, spacing: 18) {
            section("Dossiers locaux détectés") {
                ForEach(cloudFolders, id: \.self) { url in fileRow(url) }
                if cloudFolders.isEmpty { Text("Aucun dossier synchronisé trouvé.").foregroundStyle(MacClairTheme.textTertiary) }
            }
        }
    }

    private var toolsModuleView: some View {
        VStack(alignment: .leading, spacing: 18) {
            cleanupList(categories: [.diskImages])
        }
    }

    private var activityModuleView: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                metricCard("Espace libéré", size(activity.totalFreed), "internaldrive.fill")
                metricCard("Éléments", "\(activity.totalItems)", "doc.on.doc.fill")
                metricCard("Nettoyages", "\(activity.totalCleanings)", "checkmark.seal.fill")
            }

            if activity.events.isEmpty {
                emptyState("Aucune activité enregistrée.")
            } else {
                section("Historique") {
                    ForEach(activity.events.prefix(25)) { event in
                        HStack(spacing: 12) {
                            Image(systemName: "arrow.down.circle.fill")
                                .foregroundStyle(MacClairTheme.emerald)

                            Text(LocalizedStringKey(event.kind)).font(.system(size: 13, weight: .semibold))
                            Spacer()
                            Text("\(size(event.freedBytes))")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundStyle(MacClairTheme.textSecondary)
                        }
                        .padding(.vertical, 4)
                        Divider()
                    }

                    Button("Réinitialiser") { activity.reset() }.buttonStyle(.bordered)
                }
            }
        }
    }

    // MARK: - Component Helpers

    private var statsCards: some View {
        HStack(spacing: 12) {
            metricCard("Éléments repérés", "\(model.items.count)", "doc.on.doc.fill")
            metricCard("Espace analysé", size(model.totalBytes), "internaldrive.fill")
            metricCard("À confirmer", size(model.selectedBytes), "checkmark.circle.fill")
        }
    }

    private func metricCard(_ heading: String, _ value: String, _ symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(MacClairTheme.cyan)

            Text(LocalizedStringKey(value))
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(MacClairTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(LocalizedStringKey(heading))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(MacClairTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .modifier(ModernGlassPanel(radius: 16))
        .modifier(Pointer3DCard(maxAngle: 7, glowColor: MacClairTheme.cyan))
    }

    private func capabilities(_ items: [Capability]) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(items) { item in
                HStack(alignment: .center, spacing: 12) {
                    Image(systemName: item.icon)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(module.accentColor)
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(LocalizedStringKey(item.title))
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(MacClairTheme.textPrimary)
                        Text(LocalizedStringKey(item.detail))
                            .font(.system(size: 11))
                            .foregroundStyle(MacClairTheme.textSecondary)
                    }
                    Spacer(minLength: 0)
                }
                .padding(14)
                .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
                .modifier(ModernGlassPanel(radius: 14))
                .modifier(Pointer3DCard(maxAngle: 6, glowColor: module.accentColor))
            }
        }
    }

    private func section<Content: View>(_ heading: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(LocalizedStringKey(heading))
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(MacClairTheme.textPrimary)

            VStack(alignment: .leading, spacing: 12, content: content)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .modifier(ModernGlassPanel(radius: 18))
        }
    }

    private func statusRow(_ heading: String, _ detail: String, isOK: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: isOK ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(isOK ? MacClairTheme.emerald : MacClairTheme.amber)
                .font(.system(size: 15))

            Text(LocalizedStringKey(heading)).font(.system(size: 13, weight: .bold))
            Spacer()
            Text(LocalizedStringKey(detail)).font(.system(size: 12)).foregroundStyle(MacClairTheme.textSecondary)
        }
        .padding(.vertical, 3)
    }

    private func appRow(_ app: InstalledApp) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: app.url.path))
                .resizable()
                .interpolation(.high)
                .frame(width: 30, height: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(app.name).font(.system(size: 13, weight: .bold))
                Text(app.bundleID).font(.system(size: 10)).foregroundStyle(MacClairTheme.textTertiary)
            }

            Spacer(minLength: 8)

            Text(app.version).font(.system(size: 11, design: .monospaced)).foregroundStyle(MacClairTheme.textTertiary)

            Button("Finder") { NSWorkspace.shared.activateFileViewerSelecting([app.url]) }
                .buttonStyle(.borderless).font(.system(size: 11, weight: .semibold))

            Button("Désinstaller") { prepareUninstall(app) }
                .buttonStyle(.borderless)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(MacClairTheme.coral)
                .disabled(uninstalling)
        }
        .padding(.vertical, 4)
    }

    private func fileRow(_ url: URL, trailing: String = "") -> some View {
        let iconInfo = fileIcon(for: url)
        return HStack(spacing: 10) {
            Image(systemName: iconInfo.name)
                .foregroundStyle(iconInfo.color)
                .font(.system(size: 14))
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(url.lastPathComponent)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                Text(url.deletingLastPathComponent().path)
                    .font(.system(size: 10))
                    .foregroundStyle(MacClairTheme.textTertiary)
                    .lineLimit(1)
            }

            Spacer()

            if !trailing.isEmpty {
                Text(LocalizedStringKey(trailing)).font(.system(size: 11, design: .monospaced)).foregroundStyle(MacClairTheme.textSecondary)
            }

            Button {
                NSWorkspace.shared.activateFileViewerSelecting([url])
            } label: {
                Image(systemName: "folder")
                    .font(.system(size: 11))
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 3)
    }

    private var selectedFileBytes: Int64 {
        selectedFiles.values.reduce(0) { $0 + $1.bytes }
    }

    private var selectedFilesBar: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(selectedFiles.isEmpty ? Color.white.opacity(0.10) : MacClairTheme.cyan)
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(Color(red: 0.02, green: 0.08, blue: 0.15))
                    .opacity(selectedFiles.isEmpty ? 0 : 1)
            }
            .frame(width: 22, height: 22)

            Text(selectedFiles.isEmpty ? LocalizedStringKey("Aucun fichier sélectionné") : LocalizedStringKey("\(selectedFiles.count) sélectionné(s) · \(size(selectedFileBytes))"))
                .font(.system(size: 13, weight: .bold))

            Spacer()

            if !selectedFiles.isEmpty {
                Button("Tout décocher") {
                    selectedFiles.removeAll()
                    duplicateKeepers.removeAll()
                    bulkDuplicateSelection = false
                    bulkIncludedRisky = false
                }
                .buttonStyle(.borderless)
                .font(.system(size: 11, weight: .semibold))
            }

            Button {
                showFileTrashConfirmation = true
            } label: {
                Label("Mettre à la Corbeille", systemImage: "trash.fill")
            }
            .buttonStyle(ModernPrimaryButton(gradient: MacClairTheme.gradientHero))
            .disabled(selectedFiles.isEmpty || trashBusy || model.scanning)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(selectedFiles.isEmpty ? Color.white.opacity(0.04) : MacClairTheme.cyan.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(selectedFiles.isEmpty ? Color.white.opacity(0.08) : MacClairTheme.cyan.opacity(0.5), lineWidth: 1)
        )
    }

    private func checkbox(_ on: Bool) -> some View {
        ZStack {
            Circle()
                .fill(on ? MacClairTheme.cyan : Color.white.opacity(0.08))
                .frame(width: 20, height: 20)

            Circle()
                .strokeBorder(on ? MacClairTheme.cyan : Color.white.opacity(0.35), lineWidth: 1.5)
                .frame(width: 20, height: 20)

            Image(systemName: "checkmark")
                .font(.system(size: 10, weight: .heavy))
                .foregroundStyle(Color(red: 0.02, green: 0.08, blue: 0.15))
                .scaleEffect(on ? 1.0 : 0.2)
                .opacity(on ? 1 : 0)
        }
        .scaleEffect(on ? 1.05 : 0.95)
        .animation(.spring(response: 0.25, dampingFraction: 0.65), value: on)
    }

    private func selectableFileRow(_ url: URL, bytes: Int64? = nil, kept: Bool = false) -> some View {
        let isSelected = selectedFiles[url] != nil
        let iconInfo = fileIcon(for: url)

        return HStack(alignment: .center, spacing: 12) {
            checkbox(isSelected)

            Image(systemName: iconInfo.name)
                .foregroundStyle(iconInfo.color)
                .font(.system(size: 14))
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(url.lastPathComponent)
                    .font(.system(size: 13, weight: .bold))
                    .lineLimit(1)
                Text(url.path)
                    .font(.system(size: 10))
                    .foregroundStyle(MacClairTheme.textTertiary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            if kept {
                Text("Conservé")
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundStyle(MacClairTheme.emerald)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(MacClairTheme.emerald.opacity(0.15), in: Capsule())
            }

            if let bytes {
                Text(size(bytes))
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(MacClairTheme.textSecondary)
            }

            Button {
                NSWorkspace.shared.activateFileViewerSelecting([url])
            } label: {
                Image(systemName: "folder").font(.system(size: 11))
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isSelected ? MacClairTheme.cyan.opacity(0.14) : Color.white.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(isSelected ? MacClairTheme.cyan.opacity(0.55) : Color.white.opacity(0.06), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture { setSelected(url, !isSelected) }
    }

    private func selectionHeader(urls: [URL]) -> some View {
        let selectedCount = urls.filter { selectedFiles[$0] != nil }.count
        let selectedBytes = urls.compactMap { selectedFiles[$0]?.bytes }.reduce(0, +)
        let allSelected = !urls.isEmpty && selectedCount == urls.count

        return HStack(spacing: 10) {
            Button {
                setSelection(urls, !allSelected)
            } label: {
                Text(allSelected ? LocalizedStringKey("Tout décocher") : LocalizedStringKey("Tout cocher"))
                    .font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(.bordered)

            if selectedCount > 0 {
                Text("\(selectedCount) · \(size(selectedBytes))")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(MacClairTheme.cyan)
            }
            Spacer()
        }
        .padding(.vertical, 2)
    }

    private func cleanupList(categories: Set<CleanupCategory>) -> some View {
        let items = model.items.filter { categories.contains($0.category) }
        let selectedIDs = Set(model.items.filter(\.selected).map(\.id))
        let selectedHere = items.filter { selectedIDs.contains($0.id) }
        let allSelected = !items.isEmpty && selectedHere.count == items.count

        return section("Éléments anciens (\(items.count))") {
            if model.scanning { ProgressView() }
            else if !model.hasScanned { Text("Lancez l’analyse.").foregroundStyle(MacClairTheme.textTertiary) }
            else if items.isEmpty { Text("Aucun fichier à nettoyer.").foregroundStyle(MacClairTheme.textTertiary) }
            else {
                HStack(spacing: 10) {
                    Button {
                        for index in model.items.indices where categories.contains(model.items[index].category) {
                            model.items[index].selected = !allSelected
                        }
                    } label: {
                        Text(allSelected ? LocalizedStringKey("Tout décocher") : LocalizedStringKey("Tout cocher"))
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .buttonStyle(.bordered).disabled(model.moving)

                    if !selectedHere.isEmpty {
                        Text("\(selectedHere.count) · \(size(selectedHere.reduce(0) { $0 + $1.bytes }))")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(MacClairTheme.cyan)
                    }

                    Spacer()

                    Button { showTrashConfirmation = true } label: {
                        Label("Nettoyer la sélection", systemImage: "trash.fill")
                    }
                    .buttonStyle(ModernPrimaryButton(gradient: MacClairTheme.gradientHero))
                    .disabled(model.selectedCount == 0 || model.moving)
                }
                .padding(.bottom, 4)

                ForEach(items.prefix(100)) { item in
                    let isSelected = selectedIDs.contains(item.id)
                    let iconInfo = fileIcon(for: item.id)

                    HStack(spacing: 12) {
                        checkbox(isSelected)

                        Image(systemName: iconInfo.name)
                            .foregroundStyle(iconInfo.color)
                            .font(.system(size: 14))
                            .frame(width: 20)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.id.lastPathComponent)
                                .font(.system(size: 13, weight: .bold))
                                .lineLimit(1)
                            Text(item.id.deletingLastPathComponent().path)
                                .font(.system(size: 10))
                                .foregroundStyle(MacClairTheme.textTertiary)
                                .lineLimit(1)
                        }

                        Spacer(minLength: 8)

                        Text(size(item.bytes))
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundStyle(MacClairTheme.textSecondary)

                        Button {
                            NSWorkspace.shared.activateFileViewerSelecting([item.id])
                        } label: {
                            Image(systemName: "folder").font(.system(size: 11))
                        }
                        .buttonStyle(.borderless)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(isSelected ? MacClairTheme.cyan.opacity(0.14) : Color.white.opacity(0.03))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(isSelected ? MacClairTheme.cyan.opacity(0.55) : Color.white.opacity(0.06), lineWidth: 1)
                    )
                    .contentShape(Rectangle())
                    .onTapGesture { toggleItem(item) }
                }
            }
        }
    }

    private func emptyState(_ text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "tray.fill")
                .foregroundStyle(MacClairTheme.cyan)
            Text(LocalizedStringKey(text))
                .font(.system(size: 13))
                .foregroundStyle(MacClairTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 70)
        .modifier(ModernGlassPanel(radius: 16))
    }

    private func fileIcon(for url: URL) -> (name: String, color: Color) {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "dmg", "pkg", "iso":
            return ("shippingbox.fill", MacClairTheme.amber)
        case "zip", "tar", "gz", "7z", "rar":
            return ("archivebox.fill", MacClairTheme.purple)
        case "log":
            return ("doc.text.fill", MacClairTheme.rose)
        case "cache":
            return ("bolt.fill", MacClairTheme.cyan)
        case "jpg", "jpeg", "png", "heic", "webp", "gif":
            return ("photo.fill", MacClairTheme.emerald)
        case "mov", "mp4", "m4v", "mkv":
            return ("film.fill", MacClairTheme.violet)
        case "mp3", "wav", "m4a", "flac":
            return ("waveform", MacClairTheme.azure)
        case "app":
            return ("app.fill", MacClairTheme.purple)
        default:
            return ("doc.fill", MacClairTheme.azure)
        }
    }

    // MARK: - Actions & Business Logic

    private func toggleItem(_ item: CleanupItem) {
        if let index = model.items.firstIndex(where: { $0.id == item.id }) {
            model.items[index].selected.toggle()
        }
    }

    private var cloudFolders: [URL] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let roots = [
            home.appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs"),
            home.appendingPathComponent("Library/CloudStorage"),
            home.appendingPathComponent("Dropbox")
        ]
        let cloudStorage = roots[1]
        let nested = (try? FileManager.default.contentsOfDirectory(at: cloudStorage, includingPropertiesForKeys: nil)) ?? []
        return (roots + nested).filter { FileManager.default.fileExists(atPath: $0.path) }
    }

    private func setSelection(_ urls: [URL], _ value: Bool) {
        duplicateKeepers.removeAll()
        bulkDuplicateSelection = false
        bulkIncludedRisky = false
        if !value {
            for url in urls { selectedFiles.removeValue(forKey: url) }
            return
        }
        let trash = SafeTrash()
        for url in urls where selectedFiles[url] == nil {
            if let candidate = try? trash.capture(url) { selectedFiles[url] = candidate }
        }
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
                trashFeedback = "Aucune copie préparée."
            } else {
                trashFeedback = "\(plan.selected.count) copie(s) préparée(s)."
                showFileTrashConfirmation = true
            }
        }
    }

    private func moveSelectedFiles() {
        guard !selectedFiles.isEmpty && !trashBusy else { return }
        let candidates = Array(selectedFiles.values)
        let duplicateGroups = model.insights?.duplicates ?? []
        let groups = duplicateGroups.map(\.files)
        let selected = Set(candidates.map(\.url))
        do {
            try SafeTrash().validateDuplicateSelection(Set(candidates.map(\.url)), groups: groups)
        } catch {
            trashFeedback = error.localizedDescription
            return
        }
        trashBusy = true
        Task {
            let outcome = await Task.detached(priority: .userInitiated) { () -> (moved: Int, freed: Int64, failures: [String]) in
                let trash = SafeTrash()
                var count = 0
                var freed: Int64 = 0
                var failures: [String] = []
                for candidate in candidates {
                    do {
                        if let group = duplicateGroups.first(where: { $0.files.contains(candidate.url) }) {
                            guard let keeper = group.files.first(where: { !selected.contains($0) }) else {
                                throw TrashError.lastDuplicate
                            }
                            try trash.validateDuplicate(candidate, keeper: keeper, expectedDigest: group.digest)
                        }
                        try trash.moveToTrash(candidate)
                        count += 1
                        freed += candidate.bytes
                    } catch {
                        failures.append("\(candidate.url.lastPathComponent) : \(error.localizedDescription)")
                    }
                }
                return (count, freed, failures)
            }.value
            selectedFiles.removeAll()
            duplicateKeepers.removeAll()
            bulkDuplicateSelection = false
            bulkIncludedRisky = false
            imageAudit = nil
            trashBusy = false
            trashFeedback = "\(outcome.moved) fichier(s) déplacé(s)."
            activity.record(kind: "Fichiers inutiles", freed: outcome.freed, moved: outcome.moved)
            model.scan(insightRoot: clutterRoot)
        }
    }

    private func runSmartClean() {
        model.cleanRecommended { moved, freed in
            activity.record(kind: "Nettoyage", freed: freed, moved: moved)
        }
    }

    private func moveCleanSelection() {
        model.moveSelectedToTrash { moved, freed in
            activity.record(kind: "Caches et journaux", freed: freed, moved: moved)
        }
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
        panel.prompt = "Analyser"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let downloads = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads").resolvingSymlinksInPath().standardizedFileURL.path
        let chosen = url.resolvingSymlinksInPath().standardizedFileURL.path
        guard chosen == downloads || chosen.hasPrefix(downloads + "/") else {
            trashFeedback = "Choisissez un sous-dossier de Téléchargements."
            return
        }
        clutterRoot = url
        selectedFiles.removeAll()
        trashFeedback = nil
        runScan()
    }

    private func scanPrivacy() {
        guard !auditingPrivacy else { return }
        auditingPrivacy = true
        Task {
            privacyAudit = await Task.detached(priority: .userInitiated) { PrivacyAuditor().scan() }.value
            auditingPrivacy = false
        }
    }

    private func scanDeveloper() {
        guard !auditingDeveloper else { return }
        auditingDeveloper = true
        Task {
            developerAudit = await Task.detached(priority: .userInitiated) { DeveloperJunkAuditor().scan() }.value
            auditingDeveloper = false
        }
    }

    private func prepareUninstall(_ app: InstalledApp) {
        guard !uninstalling else { return }
        pendingUninstall = app
        uninstallPlan = nil
        Task {
            let plan = await Task.detached(priority: .userInitiated) {
                UninstallerPlanner().plan(appURL: app.url)
            }.value
            uninstallPlan = plan
            showUninstallConfirmation = true
        }
    }

    private func performUninstall() {
        guard let plan = uninstallPlan, let app = pendingUninstall, !uninstalling else { return }
        uninstalling = true
        uninstallFeedback = nil
        let urls = plan.items.map(\.url)
        Task {
            let result = await Task.detached(priority: .userInitiated) {
                AppUninstaller().moveToTrash(urls)
            }.value
            uninstalling = false
            removedApps.insert(app.url)
            activity.record(kind: "Désinstallation · \(app.name)", freed: result.freed, moved: result.moved)
            if result.moved > 0 {
                uninstallFeedback = "\(app.name) : \(result.moved) élément(s) déplacé(s) · \(size(result.freed)) libérés."
            } else {
                uninstallFeedback = "Aucun élément déplacé."
            }
            uninstallPlan = nil
        }
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

    private func memory(_ bytes: Int64) -> String {
        if bytes == 0 { return "—" }
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .memory)
    }
}
