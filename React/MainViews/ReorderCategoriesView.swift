import SwiftUI

struct ReorderCategoriesView: View {
    @ObservedObject var viewModel: ContentViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var boards: [Category] = []

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(boards) { board in
                        Label(board.name, systemImage: "rectangle.stack")
                            .padding(.vertical, 8)
                            .accessibilityAction(named: Text("Move Up")) { move(board, by: -1) }
                            .accessibilityAction(named: Text("Move Down")) { move(board, by: 1) }
                    }
                    .onMove { boards.move(fromOffsets: $0, toOffset: $1) }
                } header: {
                    Text("Your Boards")
                } footer: {
                    Text("Drag the handles to arrange your boards. Trash stays at the end.")
                }
            }
            .environment(\.editMode, .constant(.active))
            .navigationTitle("Rearrange Boards")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        viewModel.reorderBoards(ids: boards.map(\.id))
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear { boards = viewModel.categories.filter { !$0.isTrash } }
        .presentationDragIndicator(.visible)
    }

    private func move(_ board: Category, by offset: Int) {
        guard let index = boards.firstIndex(where: { $0.id == board.id }),
              boards.indices.contains(index + offset) else { return }
        boards.swapAt(index, index + offset)
    }
}
