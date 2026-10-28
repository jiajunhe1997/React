import SwiftUI
import UniformTypeIdentifiers

struct GridView: View {
    @ObservedObject var viewModel: ContentViewModel
    let boardID: UUID

    private var board: Category? { viewModel.categories.first { $0.id == boardID } }

    var body: some View {
        ScrollView {
            if let board {
                VStack(alignment: .leading, spacing: 12) {
                    Text(LocalizedStringKey(board.isTrash ? "Deleted photos" : "Tap to copy · Hold and drag to rearrange"))
                        .font(.caption).foregroundStyle(.secondary)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 145), spacing: 12)], spacing: 12) {
                        ForEach(board.imagePaths, id: \.self) { path in
                            if let image = viewModel.loadImage(from: path) {
                                photo(image, path: path, board: board)
                            }
                        }
                        if !board.isTrash {
                            PlusButtonView {
                                selectBoard()

                                    viewModel.selectedImageIndex = board.imagePaths.count
                                    viewModel.isImagePickerPresented = true

                            }
                        }
                    }
                }
                .padding(16)
            }
        }
    }

    private func photo(_ image: UIImage, path: String, board: Category) -> some View {
        LongPressImageView(image: image, isInTrash: board.isTrash, onCopy: {
            viewModel.copyImageToClipboard(path)
        }, onReplace: {
            selectBoard()
            viewModel.selectedImageIndex = board.imagePaths.firstIndex(of: path)
            viewModel.isImagePickerPresented = true
        }, onDelete: {
            selectBoard()
            guard let index = board.imagePaths.firstIndex(of: path) else { return }
            if board.isTrash { viewModel.deleteImagePermanently(at: index) }
            else { viewModel.deleteImage(at: index) }
        })
        .onDrag {
            NSItemProvider(object: "\(boardID.uuidString)|\(path)" as NSString)
        }
        .onDrop(of: [UTType.text], isTargeted: nil) { providers in
            guard !board.isTrash, let provider = providers.first else { return false }
            _ = provider.loadObject(ofClass: NSString.self) { object, _ in
                guard let token = object as? String else { return }
                let parts = token.split(separator: "|", maxSplits: 1).map(String.init)
                guard parts.count == 2, parts[0] == boardID.uuidString else { return }
                DispatchQueue.main.async {
                    withAnimation { viewModel.movePhoto(in: boardID, from: parts[1], to: path) }
                }
            }
            return true
        }
        .accessibilityAction(named: Text("Move earlier")) { move(path, in: board, by: -1) }
        .accessibilityAction(named: Text("Move later")) { move(path, in: board, by: 1) }
    }

    private func selectBoard() {
        if let index = viewModel.categories.firstIndex(where: { $0.id == boardID }) {
            viewModel.selectedCategoryIndex = index
        }
    }

    private func move(_ path: String, in board: Category, by offset: Int) {
        guard !board.isTrash, let index = board.imagePaths.firstIndex(of: path),
              board.imagePaths.indices.contains(index + offset) else { return }
        viewModel.movePhoto(in: boardID, from: path, to: board.imagePaths[index + offset])
    }
}
