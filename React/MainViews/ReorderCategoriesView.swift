import SwiftUI

// MARK: - Reorder Categories View
struct ReorderCategoriesView: View {
    @ObservedObject var viewModel: ContentViewModel
    @Environment(\.presentationMode) var presentationMode
    @State private var editMode = EditMode.active // Start in edit mode
    @State private var categoriesToReorder: [Category] = []

    var body: some View {
        NavigationView {
            List {
                ForEach(categoriesToReorder) { category in
                    Text(category.name)
                }
                .onMove(perform: move)
            }
            .environment(\.editMode, $editMode)
            .navigationBarTitle(NSLocalizedString("Rearrange Boards", comment: ""), displayMode: .inline)
            .navigationBarItems(
                leading: Button(NSLocalizedString("Cancel", comment: "Cancel board rearrangemet")) {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button(NSLocalizedString("Done", comment: "Save board rearrangement")) {
                    saveReorderedCategories()
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
        .onAppear {
            // Initialize categoriesToReorder excluding the Trash category
            self.categoriesToReorder = viewModel.categories.filter { !$0.isTrash }
        }
    }

    func move(from source: IndexSet, to destination: Int) {
        categoriesToReorder.move(fromOffsets: source, toOffset: destination)
    }

    func saveReorderedCategories() {
        // Update the viewModel.categories with the new order
        if let trashCategory = viewModel.categories.first(where: { $0.isTrash }) {
            viewModel.categories = categoriesToReorder + [trashCategory]
        } else {
            viewModel.categories = categoriesToReorder
        }

        // Update selectedCategoryIndex
        if let selectedCategory = viewModel.categories.element(at: viewModel.selectedCategoryIndex),
           let newIndex = viewModel.categories.firstIndex(where: { $0.id == selectedCategory.id }) {
            viewModel.selectedCategoryIndex = newIndex
        } else {
            viewModel.selectedCategoryIndex = 0
        }
    }
}
