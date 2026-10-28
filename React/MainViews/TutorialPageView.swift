import SwiftUI

struct TutorialPageView: View {
    let page: TutorialPage

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
            Image(page.imageName)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 300)
                .padding()

            Text(page.title)
                .font(.title)
                .bold()
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Text(page.description)
                .font(.body)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            }
            .frame(maxWidth: 600)
            .frame(maxWidth: .infinity)
        }
    }
}

let tutorialPages = [
    TutorialPage(
        imageName: "features",
        title: NSLocalizedString("Welcome to React", comment: "Tutorial"),
        description: NSLocalizedString("Start Reacting with your pictures and memes!", comment: "Tutorial: App Store Slogan")
    ),
    TutorialPage(
        imageName: "keyboard_access",
        title: NSLocalizedString("React KeyBoard", comment: "Tutorial"),
        description: NSLocalizedString("Access your pictures from the keyboard! Enable full access for the React Keyboard in Settings > General > Keyboard > Keyboards > React Keyboard > Allow Full Access.", comment: "Tutorial")
    ),
    TutorialPage(
        imageName: "features",
        title: NSLocalizedString("Add Images", comment: "Tutorial"),
        description: NSLocalizedString("Pick and add multiple pictures to a board.", comment: "Tutorial")
    ),
    TutorialPage(
        imageName: "features",
        title: NSLocalizedString("Copy Pics", comment: "Tutorial"),
        description: NSLocalizedString("Tap to copy a picture", comment: "Tutorial")
    ),
    TutorialPage(
        imageName: "image",
        title: NSLocalizedString("Paste Anywhere", comment: ""),
        description: NSLocalizedString("Paste in any text messenger. Send.", comment: "Tutorial")
    ),
    TutorialPage(
        imageName: "features",
        title: NSLocalizedString("Editing Boards", comment: "Tutorial"),
        description: NSLocalizedString("Edit, rearrange, and delete boards.", comment: "Tutorial")
    ),
    TutorialPage(
        imageName: "features",
        title: NSLocalizedString("Everything Included", comment: ""),
        description: NSLocalizedString("Unlimited boards, unlimited photos, and iCloud backup. Free, with no ads.", comment: "Tutorial")
    ),
    TutorialPage(
        imageName: "pictobrowse",
        title: NSLocalizedString("Explore React Sounds!", comment: ""),
        description: NSLocalizedString("Browse and add trending sounds and SFX directly from the app! Play and share any sounds with your friend.", comment: "Tutorial")
    )
]


struct TutorialView: View {
    @Binding var shouldShowTutorial: Bool
    @State private var currentPage = 0

    var body: some View {
        VStack {
            TabView(selection: $currentPage) {
                ForEach(Array(tutorialPages.enumerated()), id: \.offset) { index, page in
                    TutorialPageView(page: page)
                        .tag(index)
                }
            }
            .tabViewStyle(PageTabViewStyle())
            .animation(.easeInOut, value: currentPage)
            .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .always))

            Button(action: {
                if currentPage < tutorialPages.count - 1 {
                    currentPage += 1
                } else {
                    shouldShowTutorial = false
                    UserDefaults.standard.set(false, forKey: "shouldShowTutorial")
                }
            }) {
                Text(currentPage < tutorialPages.count - 1 ? NSLocalizedString("Next", comment: "Button label for moving to the next tutorial page") : NSLocalizedString("Get Started", comment: "Button label for finishing the tutorial and starting the app"))
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.accentColor)
                    .cornerRadius(10)
                    .padding()
            }
        }
    }
}
