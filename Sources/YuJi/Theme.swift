import AppKit
import SwiftUI

enum YuJiTheme {
    static let accent = Color(red: 0.08, green: 0.43, blue: 0.95)
    static let softBlue = Color(red: 0.91, green: 0.95, blue: 1.0)
    static let trusted = Color(red: 0.16, green: 0.62, blue: 0.35)
    static let review = Color(red: 0.95, green: 0.57, blue: 0.10)
    static let canvas = Color(nsColor: .controlBackgroundColor).opacity(0.42)
    static let line = Color.primary.opacity(0.09)
}

struct GlassPanel: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    var radius: CGFloat = 20

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content
                .glassEffect(
                    .regular.tint(colorScheme == .dark ? Color.black.opacity(0.10) : Color.white.opacity(0.10)),
                    in: RoundedRectangle(cornerRadius: radius, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .stroke(Color.white.opacity(colorScheme == .dark ? 0.10 : 0.34), lineWidth: 0.7)
                }
                .shadow(color: .black.opacity(colorScheme == .dark ? 0.22 : 0.08), radius: 18, y: 8)
        } else {
            content
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .stroke(colorScheme == .dark ? Color.white.opacity(0.10) : Color.white.opacity(0.52), lineWidth: 0.8)
                }
                .shadow(color: .black.opacity(colorScheme == .dark ? 0.18 : 0.045), radius: 16, y: 7)
        }
    }
}

struct SurfacePanel: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    var radius: CGFloat = 16

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content
                .glassEffect(
                    .clear.tint(colorScheme == .dark ? Color.black.opacity(0.035) : Color.white.opacity(0.035)),
                    in: RoundedRectangle(cornerRadius: radius, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .stroke(Color.primary.opacity(colorScheme == .dark ? 0.10 : 0.065), lineWidth: 0.7)
                }
        } else {
            content
                .background(
                    Color(nsColor: .textBackgroundColor).opacity(colorScheme == .dark ? 0.48 : 0.63),
                    in: RoundedRectangle(cornerRadius: radius, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .stroke(Color.primary.opacity(colorScheme == .dark ? 0.13 : 0.09), lineWidth: 1)
                }
        }
    }
}

private struct LiquidPrimaryButtonModifier: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content.buttonStyle(.glassProminent)
        } else {
            content.buttonStyle(.borderedProminent)
        }
    }
}

private struct LiquidButtonModifier: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content.buttonStyle(.glass)
        } else {
            content.buttonStyle(.bordered)
        }
    }
}

struct YuJiBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            WindowGlassBackground()
            (colorScheme == .dark ? Color.black.opacity(0.07) : Color.white.opacity(0.05))
            LinearGradient(
                colors: colorScheme == .dark
                    ? [Color.black.opacity(0.04), YuJiTheme.accent.opacity(0.045)]
                    : [Color.white.opacity(0.08), YuJiTheme.softBlue.opacity(0.10)],
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )
        }
        .ignoresSafeArea()
    }
}

private final class YuJiVisualEffectView: NSVisualEffectView {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.isOpaque = false
        window?.backgroundColor = .clear
        window?.titlebarAppearsTransparent = true
        window?.appearance = nil
    }
}

private struct WindowGlassBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = YuJiVisualEffectView()
        view.material = .underWindowBackground
        view.blendingMode = .behindWindow
        view.state = .active
        view.isEmphasized = false
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.state = .active
    }
}

extension View {
    func glassPanel(radius: CGFloat = 20) -> some View {
        modifier(GlassPanel(radius: radius))
    }


    func surfacePanel(radius: CGFloat = 16) -> some View {
        modifier(SurfacePanel(radius: radius))
    }

    func liquidPrimaryButtonStyle() -> some View {
        modifier(LiquidPrimaryButtonModifier())
    }

    func liquidButtonStyle() -> some View {
        modifier(LiquidButtonModifier())
    }
}

struct RiskBadge: View {
    let risk: RiskLevel
    let confidence: Int
    var showConfidence = false

    var body: some View {
        HStack(spacing: 5) {
            Text(risk.rawValue)
            if showConfidence { Text("\(confidence)%") }
        }
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(risk == .high ? YuJiTheme.trusted : YuJiTheme.review)
        .padding(.horizontal, 11)
        .padding(.vertical, 6)
        .background((risk == .high ? YuJiTheme.trusted : YuJiTheme.review).opacity(0.12), in: Capsule())
    }
}

struct CleanupKindBadge: View {
    let kind: CleanupKind

    var body: some View {
        Label(kind.rawValue, systemImage: kind.symbol)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(kind == .cache ? YuJiTheme.accent : .secondary)
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .background((kind == .cache ? YuJiTheme.accent : Color.secondary).opacity(0.11), in: Capsule())
    }
}

struct ResidueIcon: View {
    let name: String
    var size: CGFloat = 46

    private var initials: String {
        let words = name.split(whereSeparator: { $0 == " " || $0 == "-" || $0 == "_" })
        if words.count >= 2 { return words.prefix(2).compactMap(\.first).map(String.init).joined().uppercased() }
        return String(name.prefix(2)).uppercased()
    }

    private var hue: Double {
        let value = name.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return Double(value % 360) / 360.0
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.25, style: .continuous)
                .fill(Color(hue: hue, saturation: 0.62, brightness: 0.88))
            RoundedRectangle(cornerRadius: size * 0.25, style: .continuous)
                .stroke(Color.white.opacity(0.5), lineWidth: 1)
            Text(initials)
                .font(.system(size: size * 0.34, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.18), radius: 2, y: 1)
        }
        .frame(width: size, height: size)
    }
}

struct EmptyState: View {
    let symbol: String
    let title: String
    let detail: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 42, weight: .light))
                .foregroundStyle(.secondary)
            Text(title).font(.title3.weight(.semibold))
            Text(detail)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
}
