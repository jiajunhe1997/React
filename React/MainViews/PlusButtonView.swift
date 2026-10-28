
import SwiftUI

struct PlusButtonView: View {
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: 170, height: 170)
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.gray)
                        .frame(width: 50, height: 50)
                    Text("+")
                        .font(.largeTitle)
                        .foregroundColor(.white)
                }
            }
        }
        .accessibilityLabel(Text("Add Image"))
    }
}
