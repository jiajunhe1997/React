import SwiftUI

struct PlusButtonView: View {
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(systemName: "plus")
                    .font(.title2.weight(.semibold))
                    .frame(width: 56, height: 56)
                    .modifier(ReactGlass())
                Text("Add Image").font(.caption.weight(.medium))
            }
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, minHeight: 145)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add Image")
    }
}
