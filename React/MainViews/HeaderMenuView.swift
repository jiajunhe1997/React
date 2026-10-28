
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
            } else {
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
            
            // Cloud Backup Option Limited to Pro Users
            if viewModel.isFullVersionPurchased {
                Button(action: {
                    viewModel.backupImagesToiCloud()
                }) {
                    if viewModel.isBackingUp {
                        Label(NSLocalizedString("Backing Up...", comment: ""), systemImage: "icloud.and.arrow.up")
                    } else {
                        Label(NSLocalizedString("Upload to iCloud", comment: ""), systemImage: "icloud.and.arrow.up")
                    }
                }
                
                // **Sync Button**
                Button(action: {
                    viewModel.syncWithiCloud()
                }) {
                    Label(NSLocalizedString("Download from iCloud", comment: ""), systemImage: "icloud.and.arrow.down")
                }
                
                Button(action: {
                    viewModel.isStorageUsagePresented = true
                }) {
                    Label(NSLocalizedString("Storage Usage", comment: ""), systemImage: "externaldrive")
                }
                
            }
            
            Button(action: {
                if viewModel.isFullVersionPurchased {
                    viewModel.showToastMessage(NSLocalizedString("Thank you for supporting React", comment: ""))
                } else {
                    viewModel.showPurchasePrompt = true
                }
            }) {
                Label(
                    viewModel.isFullVersionPurchased ? NSLocalizedString("Pro Activated", comment: "") : NSLocalizedString("Upgrade to Pro", comment: ""),
                    systemImage: "crown.fill"
                )
                .foregroundStyle(.yellow, .primary)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
            }
            
            if viewModel.isFullVersionPurchased == false {
                Button(action: {
                    Task {
                        await StoreManager.shared.restorePurchases()
                        if StoreManager.shared.isFullVersionPurchased {
                            viewModel.showToastMessage(NSLocalizedString("Purchases restored successfully.", comment: ""))
                        } else {
                            viewModel.showToastMessage(NSLocalizedString("No purchases to restore.", comment: ""))
                        }
                    }
                }) {
                    Label(NSLocalizedString("Restore Purchases", comment: ""), systemImage: "arrow.uturn.backward.circle")
                }
            }
            
        } label: {
            Image(systemName: "line.horizontal.3")
                .font(.title2)
                .foregroundColor(.gray)
                .padding(15)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(Text("Menu"))
    }
}
