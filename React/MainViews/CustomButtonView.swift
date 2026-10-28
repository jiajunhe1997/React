import SwiftUI

/// Glass belongs to navigation and controls, leaving image content unobscured.
struct ReactGlass: ViewModifier {
    var selected = false
    var cornerRadius: CGFloat = 24
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        if reduceTransparency {
            content.background(selected ? Color.accentColor : Color(uiColor: .secondarySystemBackground),
                               in: RoundedRectangle(cornerRadius: cornerRadius))
        } else if #available(iOS 26.0, *) {
            content.glassEffect(.regular.tint(selected ? Color.accentColor : nil).interactive(),
                                in: .rect(cornerRadius: cornerRadius))
        } else {
            content.background(.regularMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
                .background(selected ? Color.accentColor.opacity(0.25) : Color.clear,
                            in: RoundedRectangle(cornerRadius: cornerRadius))
                .overlay(RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(Color.primary.opacity(selected ? 0.25 : 0.1), lineWidth: 0.5))
        }
    }
}

struct BoardGlassContainer<Content: View>: View {
    @ViewBuilder var content: () -> Content
    var body: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: 8) { content() }
        } else {
            content()
        }
    }
}

struct CategoryButtonView: View {
    var text: String
    var isSelected = false
    var action: () -> Void

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            Text(text)
                .font(.subheadline.weight(isSelected ? .semibold : .medium))
                .padding(.horizontal, 18)
                .frame(minHeight: 44)
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .modifier(ReactGlass(selected: isSelected))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// A transparent pressed state avoids the default rectangular toolbar highlight.
struct ToolbarIconStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Circle())
            .opacity(configuration.isPressed ? 0.6 : 1)
            .clipShape(Circle())
    }
}
