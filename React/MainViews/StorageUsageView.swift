
import SwiftUI

struct StorageUsageView: View {
    @ObservedObject var viewModel: ContentViewModel
    
    var body: some View {
        VStack(spacing: 20) {
            Text(NSLocalizedString("Storage Usage", comment: ""))
                .font(.title)
                .padding()
            
            Text(String(format: NSLocalizedString("Total Storage Used: %@", comment: ""), viewModel.totalStorageUsed))
                .font(.headline)
            
            List {
                ForEach(viewModel.categories, id: \.id) { category in
                    if !category.isTrash {
                        Text("\(category.name): \(viewModel.storageUsedByCategory(category))")
                    }
                }
            }
            
            Spacer()
            
            Button(action: {
                viewModel.isStorageUsagePresented = false
            }) {
                Text(NSLocalizedString("Close", comment: "Close storage usage dialogue"))
                    .padding()
                    .foregroundColor(.white)
                    .background(Color.accentColor)
                    .cornerRadius(8)
            }
            .padding(.bottom)
            .accessibilityLabel(Text(NSLocalizedString("Close", comment: "")))
        }
    }
}
