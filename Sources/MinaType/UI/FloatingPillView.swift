import SwiftUI
import AppKit

public enum HUDMode: Equatable {
    case hidden
    case listening
    case transcribing
    case polishing
    case offline
    case accessibilityNeeded
    case error(message: String)

    public var isSpecialNotice: Bool {
        switch self {
        case .offline, .accessibilityNeeded, .error: return true
        default: return false
        }
    }

    public var isHidden: Bool {
        if case .hidden = self { return true }
        return false
    }
}

public class HUDViewModel: ObservableObject {
    @Published public var mode: HUDMode = .hidden
    @Published public var audioLevel: Float = 0.0
}

public struct FloatingPillView: View {
    @ObservedObject var viewModel: HUDViewModel

    private var isDarkMode: Bool {
        let theme = ConfigManager.shared.config.appTheme
        if theme == "dark" { return true }
        if theme == "light" { return false }
        return NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }

    public var body: some View {
        Group {
            switch viewModel.mode {
            case .hidden:
                EmptyView()

            case .listening:
                // Responsive 7-bar soundwave driven by microphone level (no text)
                HStack(spacing: 3) {
                    AudioWaveBar(index: 0, level: viewModel.audioLevel, baseMultiplier: 0.45)
                    AudioWaveBar(index: 1, level: viewModel.audioLevel, baseMultiplier: 0.75)
                    AudioWaveBar(index: 2, level: viewModel.audioLevel, baseMultiplier: 1.1)
                    AudioWaveBar(index: 3, level: viewModel.audioLevel, baseMultiplier: 1.35)
                    AudioWaveBar(index: 4, level: viewModel.audioLevel, baseMultiplier: 1.1)
                    AudioWaveBar(index: 5, level: viewModel.audioLevel, baseMultiplier: 0.75)
                    AudioWaveBar(index: 6, level: viewModel.audioLevel, baseMultiplier: 0.45)
                }
                .frame(height: 18)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)

            case .transcribing, .polishing:
                // Fluid travelling ripple wave animation (no text, unified format for both transcribing & AI polishing)
                HStack(spacing: 3) {
                    ForEach(0..<7, id: \.self) { i in
                        TranscribingWaveBar(index: i)
                    }
                }
                .frame(height: 18)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)

            case .offline:
                HStack(spacing: 8) {
                    Image(systemName: "wifi.slash")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.orange)
                    Text("Offline")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(isDarkMode ? .white : Color(red: 0.1, green: 0.1, blue: 0.12))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)

            case .accessibilityNeeded:
                HStack(spacing: 8) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.yellow)
                    Text("Accessibility Needed")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(isDarkMode ? .white : Color(red: 0.1, green: 0.1, blue: 0.12))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)

            case .error(let msg):
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.orange)
                    Text(msg)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(isDarkMode ? .white : Color(red: 0.1, green: 0.1, blue: 0.12))
                        .lineLimit(1)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
            }
        }
        .frame(height: 34)
        .background(
            ZStack {
                VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                if isDarkMode {
                    Color(red: 0.08, green: 0.08, blue: 0.10, opacity: 0.94)
                } else {
                    Color.white.opacity(0.94)
                }
                RoundedRectangle(cornerRadius: 17)
                    .stroke(
                        Color(red: 1.0, green: 0.333, blue: 0.0).opacity(isDarkMode ? 0.35 : 0.45),
                        lineWidth: 1
                    )
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 17))
        .shadow(
            color: Color(red: 1.0, green: 0.333, blue: 0.0).opacity(isDarkMode ? 0.25 : 0.18),
            radius: 12, x: 0, y: 4
        )
    }
}

// Fluid travelling soundwave bar for processing/transcribing (harmonic wave ripple)
private struct TranscribingWaveBar: View {
    let index: Int
    @State private var wavePhase: Bool = false

    var body: some View {
        let minH: CGFloat = 4.0
        let maxH: CGFloat = index == 3 ? 19.0 : (index == 2 || index == 4 ? 16.0 : (index == 1 || index == 5 ? 12.0 : 7.0))
        let dynamicHeight = wavePhase ? maxH : minH

        RoundedRectangle(cornerRadius: 1.5)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 1.0, green: 0.62, blue: 0.18),
                        Color(red: 1.0, green: 0.333, blue: 0.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: 2.5, height: dynamicHeight)
            .animation(
                Animation.easeInOut(duration: 0.36)
                    .repeatForever(autoreverses: true)
                    .delay(Double(index) * 0.065),
                value: wavePhase
            )
            .onAppear {
                wavePhase = true
            }
    }
}

// Responsive microphone audio wave bar (live audio bounce)
private struct AudioWaveBar: View {
    let index: Int
    let level: Float
    let baseMultiplier: CGFloat
    @State private var wavePhase: Bool = false

    var body: some View {
        let activeHeight = CGFloat(level) * 26.0 * baseMultiplier
        let ambientHeight: CGFloat = wavePhase ? (6.0 + CGFloat(index % 3) * 3.5) : (4.0 + CGFloat((index + 1) % 3) * 2.0)
        let dynamicHeight = max(4.0, min(19.0, level > 0.02 ? activeHeight : ambientHeight))

        RoundedRectangle(cornerRadius: 1.5)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 1.0, green: 0.62, blue: 0.18),
                        Color(red: 1.0, green: 0.333, blue: 0.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: 2.5, height: dynamicHeight)
            .animation(.spring(response: 0.12, dampingFraction: 0.65, blendDuration: 0), value: dynamicHeight)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.45).repeatForever(autoreverses: true).delay(Double(index) * 0.08)) {
                    wavePhase = true
                }
            }
    }
}

public struct VisualEffectBlur: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode

    public func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    public func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

public class FloatingHUDWindow: NSPanel {
    public static let shared = FloatingHUDWindow()

    public let viewModel = HUDViewModel()

    public override var canBecomeKey: Bool { false }
    public override var canBecomeMain: Bool { false }

    private init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 84, height: 38),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )

        self.isOpaque = false
        self.backgroundColor = .clear
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.isMovableByWindowBackground = false
        self.hasShadow = false

        let hosting = NSHostingView(rootView: FloatingPillView(viewModel: viewModel))
        self.contentView = hosting
        reposition()
    }

    public func reposition() {
        guard let screen = NSScreen.main else { return }
        let screenRect = screen.visibleFrame

        let pillWidth: CGFloat
        switch viewModel.mode {
        case .listening, .transcribing, .polishing:
            pillWidth = 84
        case .offline:
            pillWidth = 118
        case .accessibilityNeeded:
            pillWidth = 195
        case .error:
            pillWidth = 190
        default:
            pillWidth = 148
        }
        let pillHeight: CGFloat = 38
        let x = screenRect.midX - (pillWidth / 2)

        let y: CGFloat
        let safeTop = screen.safeAreaInsets.top

        // Only use top camera notch placement if the screen actually has a physical camera notch!
        if ConfigManager.shared.config.hudStyle == "notch" && safeTop > 0 {
            // Nested directly below the physical MacBook notch bezel
            y = screen.frame.maxY - safeTop - pillHeight + 2
        } else {
            // Signature bottom floating capsule, comfortably above dock
            y = screenRect.minY + 48
        }

        self.setFrame(NSRect(x: x, y: y, width: pillWidth, height: pillHeight), display: true)
    }

    public func setMode(_ mode: HUDMode) {
        DispatchQueue.main.async {
            self.viewModel.mode = mode
            self.reposition()
            if !mode.isHidden && !self.isVisible {
                self.orderFront(nil)
            }
        }
    }

    public func updateAudioLevel(_ level: Float) {
        DispatchQueue.main.async {
            self.viewModel.audioLevel = level
        }
    }

    public func hide(after delay: TimeInterval = 0.0) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            self.orderOut(nil)
            self.viewModel.mode = .hidden
            self.viewModel.audioLevel = 0.0
        }
    }
}
