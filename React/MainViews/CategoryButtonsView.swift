import SwiftUI

struct CategoryButtonsView: View {
    @ObservedObject var viewModel: ContentViewModel

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                BoardGlassContainer {
                    HStack(spacing: 10) {
                        tab(NSLocalizedString("Sound", comment: ""), index: -2)
                        tab(NSLocalizedString("Discover", comment: ""), index: -1)
                        ForEach(viewModel.categories.indices, id: \.self) { index in
                            tab(viewModel.categories[index].name, index: index)
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                }
            }
            .onChange(of: viewModel.selectedCategoryIndex) { _, index in
                withAnimation { proxy.scrollTo(index, anchor: .center) }
            }
            .onAppear { proxy.scrollTo(viewModel.selectedCategoryIndex, anchor: .center) }
        }
    }

    private func tab(_ name: String, index: Int) -> some View {
        CategoryButtonView(text: name, isSelected: viewModel.selectedCategoryIndex == index) {
            withAnimation { viewModel.selectedCategoryIndex = index }
        }
        .id(index)
    }
}
