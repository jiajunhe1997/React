import SwiftUI

struct RenameCategoryModal: View {
    @Binding var newCategoryName: String
    var onSave: () -> Void
    
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        NavigationStack {
            VStack {
                TextField(NSLocalizedString("New Board Name", comment: "text field hint in rename board dialogue"), text: $newCategoryName)
                    .padding()
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .accessibilityLabel(Text("New Board Name"))
                    .focused($isTextFieldFocused)
                
                Button(action: onSave) {
                    Text(NSLocalizedString("Save", comment: "save new board name and rename it"))
                        .padding()
                        .foregroundColor(.white)
                        .background(Color.accentColor)
                        .cornerRadius(8)
                }
                .padding()
                .accessibilityLabel(Text("Save", comment: ""))
                
                Spacer()
            }
            .navigationBarTitle(NSLocalizedString("Rename Board", comment: ""), displayMode: .inline)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now()) {
                    self.isTextFieldFocused = true
                }
            }
        }
    }
}
