import SwiftUI
import AppKit

// MARK: - MacClair Design System & Theme

public enum MacClairTheme {
    // MARK: - Background Colors
    public static let bgDeep = Color(red: 0.035, green: 0.047, blue: 0.075)       // #090C13
    public static let bgSidebar = Color(red: 0.045, green: 0.060, blue: 0.095)    // #0C0F18
    public static let bgCard = Color(red: 0.070, green: 0.095, blue: 0.150)       // #121826
    public static let bgCardHover = Color(red: 0.095, green: 0.125, blue: 0.195)  // #182032

    // MARK: - Vibrant Accents
    public static let cyan = Color(red: 0.00, green: 0.90, blue: 1.00)            // #00E5FF
    public static let azure = Color(red: 0.20, green: 0.65, blue: 1.00)           // #33A6FF
    public static let violet = Color(red: 0.55, green: 0.40, blue: 1.00)          // #8C66FF
    public static let purple = Color(red: 0.70, green: 0.30, blue: 0.95)          // #B34DF2
    public static let emerald = Color(red: 0.00, green: 0.92, blue: 0.60)         // #00EBA0
    public static let mint = Color(red: 0.10, green: 0.85, blue: 0.75)            // #1AD9BF
    public static let amber = Color(red: 1.00, green: 0.68, blue: 0.15)           // #FFAD26
    public static let coral = Color(red: 1.00, green: 0.38, blue: 0.38)           // #FF6161
    public static let rose = Color(red: 1.00, green: 0.28, blue: 0.58)            // #FF4794

    // MARK: - Gradients
    public static let gradientHero = LinearGradient(
        colors: [Color(red: 0.00, green: 0.88, blue: 1.00), Color(red: 0.58, green: 0.38, blue: 1.00)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    public static let gradientClean = LinearGradient(
        colors: [Color(red: 0.00, green: 0.92, blue: 0.65), Color(red: 0.00, green: 0.75, blue: 1.00)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    public static let gradientProtect = LinearGradient(
        colors: [Color(red: 0.10, green: 0.90, blue: 0.65), Color(red: 0.05, green: 0.65, blue: 0.50)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    public static let gradientPerf = LinearGradient(
        colors: [Color(red: 1.00, green: 0.70, blue: 0.20), Color(red: 1.00, green: 0.35, blue: 0.35)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    public static let gradientApps = LinearGradient(
        colors: [Color(red: 0.65, green: 0.40, blue: 1.00), Color(red: 0.95, green: 0.30, blue: 0.75)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    public static let gradientLens = LinearGradient(
        colors: [Color(red: 0.45, green: 0.35, blue: 1.00), Color(red: 0.10, green: 0.85, blue: 1.00)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    public static let gradientGlassBorder = LinearGradient(
        colors: [Color.white.opacity(0.24), Color.white.opacity(0.04), Color.white.opacity(0.12)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - Typography Colors
    public static let textPrimary = Color.white
    public static let textSecondary = Color.white.opacity(0.72)
    public static let textTertiary = Color.white.opacity(0.42)
}

// MARK: - Glass Panel Modifier

public struct ModernGlassPanel: ViewModifier {
    var radius: CGFloat = 20
    var isHovered: Bool = false
    var glowColor: Color = MacClairTheme.cyan
    var glowIntensity: Double = 0.0

    public func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(MacClairTheme.bgCard.opacity(0.85))
                    .overlay {
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .fill(LinearGradient(
                                colors: [Color.white.opacity(0.08), Color.white.opacity(0.01)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                    }
                    .overlay {
                        if glowIntensity > 0 {
                            RoundedRectangle(cornerRadius: radius, style: .continuous)
                                .fill(glowColor.opacity(glowIntensity * 0.15))
                        }
                    }
            }
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(isHovered ? 0.35 : 0.18),
                                Color.white.opacity(isHovered ? 0.12 : 0.04),
                                glowIntensity > 0 ? glowColor.opacity(0.4) : Color.white.opacity(0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .shadow(
                color: (glowIntensity > 0 ? glowColor : Color.black).opacity(glowIntensity > 0 ? 0.25 : 0.28),
                radius: isHovered ? 18 : 12,
                y: isHovered ? 8 : 4
            )
    }
}

// MARK: - Advanced 3D Parallax Card Modifier

public struct Pointer3DCard: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var size: CGSize = .zero
    @State private var rotX: Double = 0
    @State private var rotY: Double = 0
    @State private var glarePoint: UnitPoint = .center
    @State private var isHovered = false

    var maxAngle: Double = 9
    var enableGlare: Bool = true
    var glowColor: Color = MacClairTheme.cyan

    public func body(content: Content) -> some View {
        content
            .background(GeometryReader { geo in
                Color.clear.preference(key: ViewSizePrefKey.self, value: geo.size)
            })
            .onPreferenceChange(ViewSizePrefKey.self) { size = $0 }
            .overlay {
                if enableGlare && isHovered && !reduceMotion {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(
                            RadialGradient(
                                colors: [Color.white.opacity(0.14), Color.clear],
                                center: glarePoint,
                                startRadius: 10,
                                endRadius: max(size.width, size.height) * 0.7
                            )
                        )
                        .allowsHitTesting(false)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
            }
            .rotation3DEffect(.degrees(rotX), axis: (x: 1, y: 0, z: 0), perspective: 0.55)
            .rotation3DEffect(.degrees(rotY), axis: (x: 0, y: 1, z: 0), perspective: 0.55)
            .scaleEffect(isHovered && !reduceMotion ? 1.012 : 1.0)
            .shadow(
                color: isHovered ? glowColor.opacity(0.16) : Color.black.opacity(0.22),
                radius: isHovered ? 20 : 10,
                x: -CGFloat(rotY) * 1.2,
                y: CGFloat(rotX) * 1.2 + (isHovered ? 6 : 2)
            )
            .animation(.interactiveSpring(response: 0.26, dampingFraction: 0.75), value: rotX)
            .animation(.interactiveSpring(response: 0.26, dampingFraction: 0.75), value: rotY)
            .animation(.easeInOut(duration: 0.2), value: isHovered)
            .onContinuousHover { phase in
                guard !reduceMotion, size.width > 1, size.height > 1 else { return }
                switch phase {
                case .active(let point):
                    isHovered = true
                    let nx = Double(point.x / size.width - 0.5)
                    let ny = Double(point.y / size.height - 0.5)
                    rotY = nx * maxAngle
                    rotX = -ny * maxAngle
                    glarePoint = UnitPoint(x: point.x / size.width, y: point.y / size.height)
                case .ended:
                    isHovered = false
                    rotX = 0
                    rotY = 0
                    glarePoint = .center
                }
            }
    }
}

public struct ViewSizePrefKey: PreferenceKey {
    public static let defaultValue: CGSize = .zero
    public static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

// MARK: - Fluid Modern Aurora Background

public struct FluidAuroraBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animateDrift = false

    public init() {}

    public var body: some View {
        ZStack {
            // Deep base
            LinearGradient(
                colors: [
                    Color(red: 0.040, green: 0.052, blue: 0.085),
                    Color(red: 0.025, green: 0.032, blue: 0.055)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // Electric Cyan Orb (Top-Left)
            RadialGradient(
                colors: [MacClairTheme.cyan.opacity(0.18), Color.clear],
                center: UnitPoint(x: animateDrift ? 0.28 : 0.20, y: animateDrift ? 0.14 : 0.22),
                startRadius: 0,
                endRadius: 580
            )
            .blendMode(.screen)
            .ignoresSafeArea()

            // Cosmic Violet Orb (Bottom-Right)
            RadialGradient(
                colors: [MacClairTheme.violet.opacity(0.16), Color.clear],
                center: UnitPoint(x: animateDrift ? 0.82 : 0.90, y: animateDrift ? 0.76 : 0.85),
                startRadius: 0,
                endRadius: 540
            )
            .blendMode(.screen)
            .ignoresSafeArea()

            // Center Nebula Pulse
            RadialGradient(
                colors: [MacClairTheme.azure.opacity(0.10), Color.clear],
                center: UnitPoint(x: 0.55, y: 0.45),
                startRadius: 0,
                endRadius: 420
            )
            .blendMode(.screen)
            .ignoresSafeArea()

            // Subtle noise/grain texture simulation using grid dots
            GeometryReader { geo in
                Path { path in
                    let step: CGFloat = 40
                    for x in stride(from: 0, to: geo.size.width, by: step) {
                        for y in stride(from: 0, to: geo.size.height, by: step) {
                            path.addEllipse(in: CGRect(x: x, y: y, width: 1.2, height: 1.2))
                        }
                    }
                }
                .fill(Color.white.opacity(0.025))
            }
            .ignoresSafeArea()
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 9.0).repeatForever(autoreverses: true)) {
                animateDrift = true
            }
        }
    }
}

// MARK: - Modern Primary Button

public struct ModernPrimaryButton: ButtonStyle {
    var gradient: LinearGradient = MacClairTheme.gradientHero
    var icon: String? = nil

    public init(gradient: LinearGradient = MacClairTheme.gradientHero, icon: String? = nil) {
        self.gradient = gradient
        self.icon = icon
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundStyle(Color(red: 0.02, green: 0.05, blue: 0.12))
            .padding(.horizontal, 20)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(gradient)
                    .overlay {
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.4), lineWidth: 1)
                    }
                    .shadow(
                        color: MacClairTheme.cyan.opacity(configuration.isPressed ? 0.2 : 0.4),
                        radius: configuration.isPressed ? 6 : 12,
                        y: configuration.isPressed ? 2 : 4
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.88 : 1.0)
            .animation(.spring(response: 0.22, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Circular Ring Gauge Component

public struct ModernRingGauge: View {
    var title: String
    var valueString: String
    var percentage: Double // 0.0 to 1.0
    var icon: String
    var gradient: LinearGradient
    var glowColor: Color

    @State private var animatedTrim: Double = 0.0

    public init(
        title: String,
        valueString: String,
        percentage: Double,
        icon: String,
        gradient: LinearGradient = MacClairTheme.gradientHero,
        glowColor: Color = MacClairTheme.cyan
    ) {
        self.title = title
        self.valueString = valueString
        self.percentage = max(0.0, min(1.0, percentage))
        self.icon = icon
        self.gradient = gradient
        self.glowColor = glowColor
    }

    public var body: some View {
        VStack(spacing: 12) {
            ZStack {
                // Background Track
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 9)
                    .frame(width: 82, height: 82)

                // Animated Progress Ring
                Circle()
                    .trim(from: 0, to: CGFloat(animatedTrim))
                    .stroke(
                        gradient,
                        style: StrokeStyle(lineWidth: 9, lineCap: .round)
                    )
                    .frame(width: 82, height: 82)
                    .rotationEffect(.degrees(-90))
                    .shadow(color: glowColor.opacity(0.5), radius: 6)

                // Icon & mini percentage
                VStack(spacing: 2) {
                    Image(systemName: icon)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(glowColor)
                    Text("\(Int(percentage * 100))%")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(MacClairTheme.textPrimary)
                }
            }

            VStack(spacing: 2) {
                Text(valueString)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(MacClairTheme.textPrimary)
                    .lineLimit(1)
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(MacClairTheme.textSecondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .padding(.horizontal, 14)
        .modifier(ModernGlassPanel(radius: 18))
        .modifier(Pointer3DCard(maxAngle: 8, glowColor: glowColor))
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.75)) {
                animatedTrim = percentage
            }
        }
        .onChange(of: percentage) { _, newPct in
            withAnimation(.spring(response: 0.8, dampingFraction: 0.75)) {
                animatedTrim = newPct
            }
        }
    }
}

// MARK: - Modern Storage Breakdown Bar

public struct StorageBreakdownSegment: Identifiable {
    public let id = UUID()
    public let name: String
    public let bytes: Int64
    public let color: Color
    public let icon: String

    public init(name: String, bytes: Int64, color: Color, icon: String) {
        self.name = name
        self.bytes = bytes
        self.color = color
        self.icon = icon
    }
}

public struct ModernStorageBreakdownBar: View {
    public let totalBytes: Int64
    public let segments: [StorageBreakdownSegment]
    public let freeBytes: Int64

    public init(totalBytes: Int64, segments: [StorageBreakdownSegment], freeBytes: Int64) {
        self.totalBytes = max(1, totalBytes)
        self.segments = segments
        self.freeBytes = freeBytes
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Répartition du stockage", systemImage: "internaldrive.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(MacClairTheme.cyan)
                Spacer()
                Text("Capacité : \(formatBytes(totalBytes))")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(MacClairTheme.textTertiary)
            }

            // Proportional Segmented Bar
            GeometryReader { geo in
                let width = geo.size.width
                HStack(spacing: 2) {
                    ForEach(segments) { segment in
                        let fraction = CGFloat(max(0, segment.bytes)) / CGFloat(totalBytes)
                        let segWidth = max(6, width * fraction)
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(segment.color)
                            .frame(width: segWidth)
                            .overlay {
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .fill(LinearGradient(colors: [Color.white.opacity(0.25), Color.clear],
                                                         startPoint: .top, endPoint: .bottom))
                            }
                            .help("\(segment.name) : \(formatBytes(segment.bytes))")
                    }

                    // Free space
                    let freeFraction = CGFloat(max(0, freeBytes)) / CGFloat(totalBytes)
                    let freeWidth = max(6, width * freeFraction)
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color.white.opacity(0.12))
                        .frame(width: freeWidth)
                        .help("Espace libre : \(formatBytes(freeBytes))")
                }
            }
            .frame(height: 12)
            .background(Color.black.opacity(0.3), in: RoundedRectangle(cornerRadius: 6))
            .clipShape(RoundedRectangle(cornerRadius: 6))

            // Legend
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), alignment: .leading)], spacing: 8) {
                ForEach(segments) { seg in
                    HStack(spacing: 6) {
                        Circle().fill(seg.color).frame(width: 8, height: 8)
                        Text(seg.name).font(.system(size: 11, weight: .medium)).foregroundStyle(MacClairTheme.textSecondary)
                        Spacer(minLength: 2)
                        Text(formatBytes(seg.bytes)).font(.system(size: 11, weight: .semibold, design: .rounded)).foregroundStyle(MacClairTheme.textPrimary)
                    }
                }
                HStack(spacing: 6) {
                    Circle().fill(Color.white.opacity(0.3)).frame(width: 8, height: 8)
                    Text("Libre").font(.system(size: 11, weight: .medium)).foregroundStyle(MacClairTheme.textSecondary)
                    Spacer(minLength: 2)
                    Text(formatBytes(freeBytes)).font(.system(size: 11, weight: .semibold, design: .rounded)).foregroundStyle(MacClairTheme.textPrimary)
                }
            }
        }
        .padding(18)
        .modifier(ModernGlassPanel(radius: 18))
    }

    private func formatBytes(_ b: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: b, countStyle: .file)
    }
}

// MARK: - Modern Animated Radar Scanner Banner

public struct ModernScanRadarBanner: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var radarAngle: Double = 0
    @State private var pulseWave = false

    var title: String = "Analyse approfondie en cours…"
    var detail: String
    var subdetail: String

    public init(detail: String, subdetail: String) {
        self.detail = detail
        self.subdetail = subdetail
    }

    public var body: some View {
        HStack(spacing: 18) {
            // Animated Radar Scanner Circle
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 3)
                    .frame(width: 58, height: 58)

                Circle()
                    .stroke(MacClairTheme.cyan.opacity(0.3), lineWidth: 1.5)
                    .frame(width: 42, height: 42)

                // Expanding pulse wave
                Circle()
                    .stroke(MacClairTheme.cyan.opacity(pulseWave ? 0.0 : 0.6), lineWidth: 2)
                    .scaleEffect(pulseWave ? 1.35 : 0.7)
                    .frame(width: 52, height: 52)

                // Sweep beam
                Circle()
                    .fill(
                        AngularGradient(
                            colors: [MacClairTheme.cyan.opacity(0.7), MacClairTheme.cyan.opacity(0.0)],
                            center: .center,
                            startAngle: .degrees(0),
                            endAngle: .degrees(90)
                        )
                    )
                    .frame(width: 54, height: 54)
                    .rotationEffect(.degrees(radarAngle))

                Circle()
                    .fill(MacClairTheme.cyan)
                    .frame(width: 6, height: 6)
                    .shadow(color: MacClairTheme.cyan, radius: 4)
            }
            .frame(width: 64, height: 64)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(title)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(MacClairTheme.textPrimary)

                    Text("EN COURS")
                        .font(.system(size: 9, weight: .heavy))
                        .tracking(1.2)
                        .foregroundStyle(Color(red: 0.02, green: 0.08, blue: 0.15))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(MacClairTheme.cyan, in: Capsule())
                }

                Text(detail)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(MacClairTheme.textSecondary)

                Text(subdetail)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(MacClairTheme.textTertiary)
            }

            Spacer()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(ModernGlassPanel(radius: 20, glowColor: MacClairTheme.cyan, glowIntensity: 0.3))
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: 1.8).repeatForever(autoreverses: false)) {
                radarAngle = 360
            }
            withAnimation(.easeOut(duration: 1.4).repeatForever(autoreverses: false)) {
                pulseWave = true
            }
        }
    }
}

// MARK: - Living Animated App Icon

public struct LivingAnimatedAppIcon: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var borderAngle: Double = 0
    @State private var innerAngle: Double = 0
    @State private var pulse: Bool = false
    @State private var isHovered: Bool = false

    var size: CGFloat = 40

    public init(size: CGFloat = 40) {
        self.size = size
    }

    public var body: some View {
        ZStack {
            // Dark obsidian squircle base
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.08, green: 0.12, blue: 0.24), Color(red: 0.03, green: 0.05, blue: 0.10)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // Animated spinning border gradient
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .strokeBorder(
                    AngularGradient(
                        colors: [
                            MacClairTheme.cyan,
                            MacClairTheme.violet,
                            MacClairTheme.emerald.opacity(0.8),
                            MacClairTheme.cyan
                        ],
                        center: .center,
                        startAngle: .degrees(0),
                        endAngle: .degrees(360)
                    ),
                    lineWidth: 1.5
                )
                .rotationEffect(.degrees(borderAngle))

            // Kinetic aperture ring (thin segmented track)
            Circle()
                .trim(from: 0.15, to: 0.85)
                .stroke(
                    LinearGradient(
                        colors: [MacClairTheme.cyan, MacClairTheme.cyan.opacity(0.1)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    style: StrokeStyle(lineWidth: 1.5, lineCap: .round)
                )
                .frame(width: size * 0.62, height: size * 0.62)
                .rotationEffect(.degrees(innerAngle))

            // Counter-rotating satellite pip
            Circle()
                .fill(Color.white)
                .frame(width: size * 0.11, height: size * 0.11)
                .shadow(color: MacClairTheme.cyan, radius: 3)
                .offset(y: -size * 0.31)
                .rotationEffect(.degrees(-borderAngle * 1.4))

            // Pulsing living core dot
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.white, MacClairTheme.cyan],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.14
                    )
                )
                .frame(width: size * 0.24, height: size * 0.24)
                .scaleEffect(pulse ? 1.2 : 0.85)
                .shadow(color: MacClairTheme.cyan.opacity(0.9), radius: pulse ? 6 : 2)
        }
        .frame(width: size, height: size)
        .shadow(color: MacClairTheme.cyan.opacity(isHovered ? 0.5 : 0.25), radius: isHovered ? 12 : 7, y: 2)
        .scaleEffect(isHovered ? 1.05 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
        .onHover { isHovered = $0 }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: 4.5).repeatForever(autoreverses: false)) {
                borderAngle = 360
            }
            withAnimation(.linear(duration: 3.0).repeatForever(autoreverses: false)) {
                innerAngle = -360
            }
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}
