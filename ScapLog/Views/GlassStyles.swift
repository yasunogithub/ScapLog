//
//  GlassStyles.swift
//  ScapLog
//
//  Liquid Glass UI スタイル定義 (Apple 2025 Design Language)
//

import SwiftUI
import Observation
import AppKit

// MARK: - Liquid Glass Design Constants

struct LiquidGlass {
    // Animation durations (longer for fluid feel)
    static let animationDuration: Double = 0.3
    static let springResponse: Double = 0.35
    static let springDamping: Double = 0.8

    // Corner radii (concentric design)
    static let radiusLarge: CGFloat = 24
    static let radiusMedium: CGFloat = 16
    static let radiusSmall: CGFloat = 10
    static let radiusTiny: CGFloat = 6

    // Spacing (floating elements)
    static let floatPadding: CGFloat = 12
    static let contentPadding: CGFloat = 16

    // Default values (used when settings are not available)
    static let defaultBackgroundOpacity: Double = 0.6
    static let defaultForegroundOpacity: Double = 0.85
    static let defaultBorderOpacity: Double = 0.25
    static let defaultHighlightOpacity: Double = 0.4
    static let defaultShadowOpacity: Double = 0.15
    static let defaultBlurRadius: CGFloat = 20

    // Dynamic values from settings
    static var overlayOpacity: Double {
        AppSettings.shared.glassOverlayOpacity
    }

    static var borderOpacity: Double {
        AppSettings.shared.glassBorderOpacity
    }

    static var shadowOpacity: Double {
        AppSettings.shared.glassShadowOpacity
    }

    static var highlightOpacity: Double {
        AppSettings.shared.glassHighlightOpacity
    }

    static var materialIndex: Int {
        AppSettings.shared.glassMaterialIndex
    }

    /// Get SwiftUI Material based on settings
    static func material() -> AnyShapeStyle {
        switch materialIndex {
        case 0: return AnyShapeStyle(.ultraThinMaterial)
        case 1: return AnyShapeStyle(.thinMaterial)
        case 2: return AnyShapeStyle(.regularMaterial)
        case 3: return AnyShapeStyle(.thickMaterial)
        default: return AnyShapeStyle(.thinMaterial)
        }
    }

    /// Get NSVisualEffectView.Material based on settings
    static var nsMaterial: NSVisualEffectView.Material {
        switch materialIndex {
        case 0: return .hudWindow
        case 1: return .popover
        case 2: return .sidebar
        case 3: return .menu
        default: return .popover
        }
    }
}

// MARK: - Liquid Glass Background Components

/// Panel background with dynamic opacity from settings
struct LiquidGlassPanelBackground: View {
    let cornerRadius: CGFloat
    @Bindable private var settings = AppSettings.shared

    var body: some View {
        ZStack {
            // Base glass layer - dynamic material
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(materialFill)

            // Gradient overlay for depth
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(
                    LinearGradient(
                        colors: [
                            Color("GlassHighlight").opacity(settings.glassOverlayOpacity * 2),
                            Color("GlassHighlight").opacity(settings.glassOverlayOpacity * 0.6),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // Inner highlight (top edge reflection)
            RoundedRectangle(cornerRadius: cornerRadius)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color("GlassHighlight").opacity(settings.glassHighlightOpacity),
                            Color("GlassHighlight").opacity(settings.glassHighlightOpacity * 0.4),
                            Color("GlassHighlight").opacity(settings.glassHighlightOpacity * 0.1)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )
        }
    }

    private var materialFill: AnyShapeStyle {
        switch settings.glassMaterialIndex {
        case 0: return AnyShapeStyle(.ultraThinMaterial)
        case 1: return AnyShapeStyle(.thinMaterial)
        case 2: return AnyShapeStyle(.regularMaterial)
        case 3: return AnyShapeStyle(.thickMaterial)
        default: return AnyShapeStyle(.thinMaterial)
        }
    }
}

/// Card background with dynamic opacity from settings
struct LiquidGlassCardBackground: View {
    let cornerRadius: CGFloat
    @Bindable private var settings = AppSettings.shared

    var body: some View {
        ZStack {
            // Frosted glass base - dynamic material
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(materialFill)

            // Subtle gradient
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(
                    LinearGradient(
                        colors: [
                            Color("GlassHighlight").opacity(settings.glassOverlayOpacity * 1.5),
                            Color("GlassHighlight").opacity(settings.glassOverlayOpacity * 0.5)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // Border with highlight
            RoundedRectangle(cornerRadius: cornerRadius)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color("GlassHighlight").opacity(settings.glassBorderOpacity * 1.4),
                            Color("GlassHighlight").opacity(settings.glassBorderOpacity * 0.4)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
        }
    }

    private var materialFill: AnyShapeStyle {
        switch settings.glassMaterialIndex {
        case 0: return AnyShapeStyle(.ultraThinMaterial)
        case 1:
            return AnyShapeStyle(.thinMaterial)
        case 2: return AnyShapeStyle(.regularMaterial)
        case 3: return AnyShapeStyle(.thickMaterial)
        default: return AnyShapeStyle(.thinMaterial)
        }
    }
}

// MARK: - Liquid Glass View Modifiers

extension View {
    /// Primary Liquid Glass panel - main content containers
    func liquidGlassPanel(cornerRadius: CGFloat = LiquidGlass.radiusLarge) -> some View {
        self
            .background {
                LiquidGlassPanelBackground(cornerRadius: cornerRadius)
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .shadow(color: Color.blue.opacity(LiquidGlass.shadowOpacity * 0.5), radius: 20, x: 0, y: 10)
            .shadow(color: Color("GlassShadow").opacity(LiquidGlass.shadowOpacity * 0.7), radius: 8, x: 0, y: 4)
    }

    /// Floating card with elevation
    func liquidGlassCard(cornerRadius: CGFloat = LiquidGlass.radiusMedium) -> some View {
        self
            .background {
                LiquidGlassCardBackground(cornerRadius: cornerRadius)
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .shadow(color: Color.cyan.opacity(LiquidGlass.shadowOpacity * 0.4), radius: 12, x: 0, y: 6)
            .shadow(color: Color("GlassShadow").opacity(LiquidGlass.shadowOpacity * 0.5), radius: 4, x: 0, y: 2)
    }

    /// Sidebar/navigation pane
    func liquidGlassSidebar(opacity: Double? = nil) -> some View {
        let effectiveOpacity = opacity ?? AppSettings.shared.windowOpacity
        return self
            .background {
                ZStack {
                    // Ultra thin for see-through effect
                    if effectiveOpacity > 0.3 {
                        Rectangle()
                            .fill(Color.white.opacity(0.04))
                            .opacity(effectiveOpacity)
                    }

                    // Vertical gradient for depth
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color("GlassHighlight").opacity(0.08 * effectiveOpacity),
                                    Color.clear,
                                    Color("GlassShadow").opacity(0.02 * effectiveOpacity)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
            }
    }

    /// Header/toolbar with reflection
    func liquidGlassHeader(opacity: Double? = nil) -> some View {
        let effectiveOpacity = opacity ?? AppSettings.shared.windowOpacity
        return self
            .background {
                ZStack {
                    if effectiveOpacity > 0.3 {
                        Rectangle()
                            .fill(.bar)
                            .opacity(effectiveOpacity)
                    }

                    // Top reflection line
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color("GlassHighlight").opacity(0.3 * effectiveOpacity),
                                    Color("GlassHighlight").opacity(0.1 * effectiveOpacity),
                                    Color.clear
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(height: 1)
                        .frame(maxHeight: .infinity, alignment: .top)
                }
            }
    }

    /// Search field with inset glass effect
    func liquidGlassSearchField() -> some View {
        self
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: LiquidGlass.radiusSmall)
                        .fill(Color("GlassShadow").opacity(0.15))

                    RoundedRectangle(cornerRadius: LiquidGlass.radiusSmall)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color("GlassShadow").opacity(0.05),
                                    Color("GlassHighlight").opacity(0.02)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                    RoundedRectangle(cornerRadius: LiquidGlass.radiusSmall)
                        .strokeBorder(Color("GlassHighlight").opacity(0.1), lineWidth: 0.5)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: LiquidGlass.radiusSmall))
    }

    /// Badge with liquid effect
    func liquidGlassBadge(color: Color = .accentColor) -> some View {
        self
            .background {
                ZStack {
                    Capsule()
                        .fill(color.opacity(0.2))

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color("GlassHighlight").opacity(0.3),
                                    Color("GlassHighlight").opacity(0.1)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                    Capsule()
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    color.opacity(0.5),
                                    color.opacity(0.2)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 0.5
                        )
                }
            }
            .clipShape(Capsule())
    }

    /// Alert/notification box
    func liquidGlassAlert(color: Color = .red) -> some View {
        self
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: LiquidGlass.radiusSmall)
                        .fill(color.opacity(0.15))

                    RoundedRectangle(cornerRadius: LiquidGlass.radiusSmall)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color("GlassHighlight").opacity(0.15),
                                    Color.clear
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                    RoundedRectangle(cornerRadius: LiquidGlass.radiusSmall)
                        .strokeBorder(color.opacity(0.3), lineWidth: 0.5)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: LiquidGlass.radiusSmall))
            .shadow(color: color.opacity(0.2), radius: 8, x: 0, y: 4)
    }

    /// Section header with subtle separator
    func liquidGlassSectionHeader(opacity: Double? = nil) -> some View {
        let effectiveOpacity = opacity ?? AppSettings.shared.windowOpacity
        return self
            .background(Color("GlassHighlight").opacity(0.03 * effectiveOpacity))
            .overlay(
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color("GlassHighlight").opacity(0.15 * effectiveOpacity),
                                Color("GlassHighlight").opacity(0.05 * effectiveOpacity),
                                Color.clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 0.5),
                alignment: .bottom
            )
    }

    /// Floating action button
    func liquidGlassFloatingButton() -> some View {
        self
            .background {
                Circle()
                    .fill(Color.white.opacity(0.1))
                    .overlay {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color("GlassHighlight").opacity(0.3),
                                        Color("GlassHighlight").opacity(0.1)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    .overlay {
                        Circle()
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        Color("GlassHighlight").opacity(0.5),
                                        Color("GlassHighlight").opacity(0.15)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.5
                            )
                    }
            }
            .clipShape(Circle())
            .shadow(color: Color.cyan.opacity(0.15), radius: 16, x: 0, y: 8)
            .shadow(color: Color("GlassShadow").opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Liquid Glass Button Styles

struct LiquidGlassButtonStyle: ButtonStyle {
    var isProminent: Bool = false
    var color: Color = .accentColor

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background {
                ZStack {
                    if isProminent {
                        // Prominent button - colored glass
                        RoundedRectangle(cornerRadius: LiquidGlass.radiusTiny)
                            .fill(color.opacity(0.8))

                        RoundedRectangle(cornerRadius: LiquidGlass.radiusTiny)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color("GlassHighlight").opacity(0.35),
                                        Color("GlassHighlight").opacity(0.1),
                                        Color.clear
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )

                        RoundedRectangle(cornerRadius: LiquidGlass.radiusTiny)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        Color("GlassHighlight").opacity(0.5),
                                        color.opacity(0.3)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 0.5
                            )
                    } else {
                        // Standard button - transparent glass
                        RoundedRectangle(cornerRadius: LiquidGlass.radiusTiny)
                            .fill(Color.white.opacity(0.08))

                        RoundedRectangle(cornerRadius: LiquidGlass.radiusTiny)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color("GlassHighlight").opacity(0.15),
                                        Color.clear
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )

                        RoundedRectangle(cornerRadius: LiquidGlass.radiusTiny)
                            .strokeBorder(Color("GlassHighlight").opacity(0.15), lineWidth: 0.5)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: LiquidGlass.radiusTiny))
            .foregroundColor(isProminent ? .white : .primary)
            .shadow(
                color: isProminent ? color.opacity(0.3) : Color("GlassShadow").opacity(0.1),
                radius: configuration.isPressed ? 2 : 6,
                x: 0,
                y: configuration.isPressed ? 1 : 3
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct LiquidGlassMenuButtonStyle: ButtonStyle {
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: LiquidGlass.radiusTiny)
                    .fill(isHovered ? Color("GlassHighlight").opacity(0.12) : Color.clear)
                    .overlay {
                        if isHovered {
                            RoundedRectangle(cornerRadius: LiquidGlass.radiusTiny)
                                .strokeBorder(Color("GlassHighlight").opacity(0.15), lineWidth: 0.5)
                        }
                    }
            }
            .clipShape(RoundedRectangle(cornerRadius: LiquidGlass.radiusTiny))
            .contentShape(Rectangle())
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.8), value: configuration.isPressed)
            .animation(.easeOut(duration: 0.15), value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

struct LiquidGlassIconButtonStyle: ButtonStyle {
    @State private var isHovered = false
    var size: CGFloat = 32

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: size, height: size)
            .background {
                Circle()
                    .fill(isHovered ? Color("GlassHighlight").opacity(0.15) : Color("GlassHighlight").opacity(0.08))
                    .overlay {
                        Circle()
                            .strokeBorder(
                                isHovered ? Color("GlassHighlight").opacity(0.25) : Color("GlassHighlight").opacity(0.1),
                                lineWidth: 0.5
                            )
                    }
            }
            .clipShape(Circle())
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
            .animation(.easeOut(duration: 0.15), value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

// MARK: - Liquid Glass Group Box

struct LiquidGlassGroupBox<Content: View>: View {
    let title: String
    let icon: String
    let content: Content

    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header with icon
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.accentColor, .accentColor.opacity(0.7)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
            }

            // Content
            content
        }
        .padding(LiquidGlass.contentPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .liquidGlassCard(cornerRadius: LiquidGlass.radiusMedium)
    }
}

// MARK: - Liquid Glass Row

struct LiquidGlassRow<Leading: View, Trailing: View>: View {
    let leading: Leading
    let trailing: Trailing

    init(@ViewBuilder leading: () -> Leading, @ViewBuilder trailing: () -> Trailing) {
        self.leading = leading()
        self.trailing = trailing()
    }

    var body: some View {
        HStack {
            leading
            Spacer()
            trailing
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background {
            RoundedRectangle(cornerRadius: LiquidGlass.radiusSmall)
                .fill(Color("GlassHighlight").opacity(0.06))
                .overlay {
                    RoundedRectangle(cornerRadius: LiquidGlass.radiusSmall)
                        .strokeBorder(Color("GlassHighlight").opacity(0.08), lineWidth: 0.5)
                }
        }
    }
}

// MARK: - Visual Effect Views

struct LiquidGlassBackground: View {
    var opacity: Double = 1.0
    private var theme: ColorTheme { AppSettings.shared.colorTheme }

    var body: some View {
        ZStack {
            // Base color with configurable opacity
            Color(NSColor.windowBackgroundColor)
                .opacity(opacity * 0.5)  // Base is semi-transparent

            // Ambient gradient with theme colors
            LinearGradient(
                colors: [
                    theme.backgroundTint.opacity(0.05 * opacity),
                    Color.clear,
                    theme.accent.opacity(0.03 * opacity)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Noise texture simulation (subtle)
            Rectangle()
                .fill(theme.highlight.opacity(0.01 * opacity))
        }
        .ignoresSafeArea()
    }
}

struct LiquidGlassVisualEffect: NSViewRepresentable {
    let material: NSVisualEffectView.Material?
    let blendingMode: NSVisualEffectView.BlendingMode
    let useSettingsMaterial: Bool

    init(
        material: NSVisualEffectView.Material? = nil,
        blendingMode: NSVisualEffectView.BlendingMode = .behindWindow,
        useSettingsMaterial: Bool = true
    ) {
        self.material = material
        self.blendingMode = blendingMode
        self.useSettingsMaterial = useSettingsMaterial
    }

    private var effectiveMaterial: NSVisualEffectView.Material {
        if let material = material {
            return material
        }
        if useSettingsMaterial {
            return LiquidGlass.nsMaterial
        }
        return .hudWindow
    }

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = effectiveMaterial
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = effectiveMaterial
        nsView.blendingMode = blendingMode
    }
}

// MARK: - Window Styling

struct LiquidGlassWindowAccessor: NSViewRepresentable {
    var opacity: Double = 0.85

    func makeNSView(context: Context) -> NSView {
        let view = WindowOpacityObserverView()
        view.updateOpacity(opacity)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if let observerView = nsView as? WindowOpacityObserverView {
            observerView.updateOpacity(opacity)
        }
    }
}

class WindowOpacityObserverView: NSView {
    private var currentOpacity: Double = 0.85

    func updateOpacity(_ opacity: Double) {
        currentOpacity = opacity
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let window = self.window else { return }
            // Use clear background for full transparency control
            window.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(CGFloat(opacity) * 0.3)
            window.isOpaque = false
            window.titlebarAppearsTransparent = true
            window.invalidateShadow()
        }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        updateOpacity(currentOpacity)
    }
}

// MARK: - Legacy Compatibility (deprecated)

extension View {
    @available(*, deprecated, message: "Use liquidGlassSidebar() instead")
    func glassPane() -> some View {
        self.liquidGlassSidebar()
    }

    @available(*, deprecated, message: "Use liquidGlassCard() instead")
    func glassCard(cornerRadius: CGFloat = 12) -> some View {
        self.liquidGlassCard(cornerRadius: cornerRadius)
    }

    @available(*, deprecated, message: "Use liquidGlassCard() instead")
    func solidCard(cornerRadius: CGFloat = 10) -> some View {
        self.liquidGlassCard(cornerRadius: cornerRadius)
    }

    @available(*, deprecated, message: "Use liquidGlassHeader() instead")
    func glassHeader() -> some View {
        self.liquidGlassHeader()
    }

    @available(*, deprecated, message: "Use liquidGlassSearchField() instead")
    func glassSearchField() -> some View {
        self.liquidGlassSearchField()
    }

    @available(*, deprecated, message: "Use liquidGlassSectionHeader() instead")
    func glassSectionHeader() -> some View {
        self.liquidGlassSectionHeader()
    }

    @available(*, deprecated, message: "Use liquidGlassBadge() instead")
    func glassBadge() -> some View {
        self.liquidGlassBadge()
    }

    @available(*, deprecated, message: "Use liquidGlassAlert() instead")
    func glassAlertBox(color: Color = .red) -> some View {
        self.liquidGlassAlert(color: color)
    }
}

// Legacy button style compatibility
typealias GlassButtonStyle = LiquidGlassButtonStyle
typealias GlassMenuButtonStyle = LiquidGlassMenuButtonStyle

// Legacy group box
typealias GlassGroupBox = LiquidGlassGroupBox

// Legacy colors - renamed to avoid conflict with asset catalog generated symbols
extension Color {
    static let legacyGlassBackground = Color(NSColor.windowBackgroundColor).opacity(0.85)
    static let legacyGlassBorder = Color("GlassHighlight").opacity(0.2)
    static let legacyGlassShadow = Color("GlassShadow").opacity(0.1)
}

// Legacy gradient
typealias GlassGradientBackground = LiquidGlassBackground
typealias VisualEffectBlur = LiquidGlassVisualEffect
typealias WindowAccessor = LiquidGlassWindowAccessor
