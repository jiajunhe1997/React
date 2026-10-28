
import Foundation
import SwiftUI

struct HeaderMenuView: View {
    @ObservedObject var viewModel: ContentViewModel
    
    var body: some View {
        Menu {
            if viewModel.categories.indices.contains(viewModel.selectedCategoryIndex) && viewModel.categories[viewModel.selectedCategoryIndex].isTrash {
                Button(action: {
                    viewModel.clearTrash()
                }) {
                    Label(NSLocalizedString("Clear Trash", comment: ""), systemImage: "trash")
                }
            } else if viewModel.categories.indices.contains(viewModel.selectedCategoryIndex) {
                Button(action: {
                    viewModel.initiateRenameCategory(for: viewModel.selectedCategoryIndex)
                }) {
                    Label(NSLocalizedString("Rename Board", comment: ""), systemImage: "pencil")
                }
                Button(action: {
                    viewModel.deleteCategory()
                }) {
                    Label(NSLocalizedString("Delete Board", comment: ""), systemImage: "trash")
                }
            }
            
            Button(action: {
                viewModel.isReorderCategoriesPresented = true
            }) {
                Label(NSLocalizedString("Rearrange Boards", comment: ""), systemImage: "arrow.up.arrow.down")
            }
            
            Divider()
            Button { viewModel.backupImagesToiCloud() } label: {
                Label(LocalizedStringKey(viewModel.isBackingUp ? "Backing Up..." : "Upload to iCloud"), systemImage: "icloud.and.arrow.up")
            }
            .disabled(viewModel.isBackingUp)
            Button { viewModel.syncWithiCloud() } label: {
                Label("Download from iCloud", systemImage: "icloud.and.arrow.down")
            }
            Button { viewModel.isStorageUsagePresented = true } label: {
                Label("Storage Usage", systemImage: "externaldrive")
            }
        } label: {
            Image(systemName: "line.horizontal.3")
                .font(.title2)
                .foregroundStyle(.primary)
                .frame(width: 44, height: 44)
                .modifier(ReactGlass())
                .contentShape(Rectangle())
        }
        .buttonStyle(ToolbarIconStyle())
        .clipShape(Circle())
        .accessibilityLabel(Text("Menu"))
    }
}
