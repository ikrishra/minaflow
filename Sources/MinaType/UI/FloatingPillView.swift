import SwiftUI
import AppKit

public enum HUDMode: Equatable {
    case hidden
    case listening
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
    @State private var pulseRecordDot = false

    public var body: some View {
        Group {
            switch viewModel.mode {
            case .hidden:
                EmptyView()

            case .listening:
                HStack(spacing: 8) {
                    // Pulsing orange live recording dot
                    ZStack {
                        Circle()
                            .fill(Color(red: 1.0, green: 0.333, blue: 0.0).opacity(0.35))
                            .frame(width: 14, height: 14)
                            .scaleEffect(pulseRecordDot ? 1.3 : 0.9)
                            .animation(Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: pulseRecordDot)

                        Circle()
                            .fill(Color(red: 1.0, green: 0.333, blue: 0.0))
                            .frame(width: 7, height: 7)
                    }
                    .onAppear { pulseRecordDot = true }

                    // Responsive 6-bar soundwave
                    HStack(spacing: 2.5) {
                        AudioWaveBar(index: 0, level: viewModel.audioLevel, baseMultiplier: 0.45)
                        AudioWaveBar(index: 1, level: viewModel.audioLevel, baseMultiplier: 0.8)
                        AudioWaveBar(index: 2, level: viewModel.audioLevel, baseMultiplier: 1.2)
                        AudioWaveBar(index: 3, level: viewModel.audioLevel, baseMultiplier: 1.0)
                        AudioWaveBar(index: 4, level: viewModel.audioLevel, baseMultiplier: 0.75)
                        AudioWaveBar(index: 5, level: viewModel.audioLevel, baseMultiplier: 0.45)
                    }
                    .frame(height: 18)

                    Text("Listening")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)

            case .polishing:
                HStack(spacing: 8) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Color(red: 1.0, green: 0.45, blue: 0.1)))
                        .scaleEffect(0.65)
                        .frame(width: 14, height: 14)

                    Text("Polishing...")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(Color.white.opacity(0.95))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)

            case .offline:
                HStack(spacing: 8) {
                    Image(systemName: "wifi.slash")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.orange)
                    Text("Offline")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
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
                        .foregroundColor(.white)
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
                        .foregroundColor(.white)
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
                Color(red: 0.08, green: 0.08, blue: 0.10, opacity: 0.94)
                RoundedRectangle(cornerRadius: 17)
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 17))
        .shadow(color: Color.black.opacity(0.45), radius: 14, x: 0, y: 5)
    }
}

// Fluid spring audio wave bar
private struct AudioWaveBar: View {
    let index: Int
    let level: Float
    let baseMultiplier: CGFloat

    var body: some View {
        let dynamicHeight = max(5.0, min(18.0, CGFloat(level) * 26.0 * baseMultiplier))

        RoundedRectangle(cornerRadius: 1.5)
            .fill(
                LinearGradient(
                    colors: [Color.white, Color(red: 1.0, green: 0.85, blue: 0.7)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: 2.5, height: dynamicHeight)
            .animation(.spring(response: 0.12, dampingFraction: 0.65, blendDuration: 0), value: dynamicHeight)
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
            contentRect: NSRect(x: 0, y: 0, width: 150, height: 38),
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
        case .listening:
            pillWidth = 148
        case .polishing:
            pillWidth = 126
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
            // Signature bottom floating capsule (Wispr Flow style), above dock, clear of all window headers
            y = screenRect.minY + 84
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
