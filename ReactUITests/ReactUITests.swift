import XCTest

final class ReactUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    func testRequestedMarketNavigation() {
        for locale in ["hi", "fr", "es", "ja", "id", "en-IN"] {
            checkNavigation(locale)
        }
    }

    func testFrenchNavigationOnPhone() { checkNavigation("fr") }

    func testFrenchNavigationOnTablet() { checkNavigation("fr") }

    private func checkNavigation(_ locale: String) {
        let words: [String: [String]] = [
            "hi": ["बोर्ड जोड़ें", "ध्वनि", "खोजें", "मेन्यू", "बोर्ड का क्रम बदलें", "हो गया"],
            "fr": ["Ajouter un tableau", "Sons", "Découvrir", "Menu", "Réorganiser les tableaux", "Terminé"],
            "es": ["Añadir tablero", "Sonidos", "Descubrir", "Menú", "Reorganizar tableros", "Listo"],
            "ja": ["ボードを追加", "サウンド", "見つける", "メニュー", "ボードを並べ替え", "完了"],
            "id": ["Tambah papan", "Suara", "Jelajahi", "Menu", "Atur ulang papan", "Selesai"],
            "en-IN": ["Add Board", "Sound", "Discover", "Menu", "Rearrange Boards", "Done"]
        ]
        let labels = words[locale]!
        let app = XCUIApplication()
        app.launchArguments = ["-shouldShowTutorial", "NO", "-AppleLanguages", "(\(locale))", "-AppleLocale", locale]
        app.launch()
        XCTAssertTrue(app.buttons[labels[0]].waitForExistence(timeout: 15), locale)
        app.buttons[labels[1]].tap()
        XCTAssertTrue(app.buttons[labels[1]].isSelected, locale)
        // Wait for the animated page transition to actually expose Sound's search field.
        expectation(for: NSPredicate(format: "hittable == true"), evaluatedWith: app.textFields["sound.search"])
        waitForExpectations(timeout: 10)
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.45))
        start.press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.45)))
        let selected = NSPredicate(format: "selected == true")
        expectation(for: selected, evaluatedWith: app.buttons[labels[2]])
        waitForExpectations(timeout: 5)
        app.buttons[labels[3]].tap()
        XCTAssertTrue(app.buttons[labels[4]].waitForExistence(timeout: 5), locale)
        app.buttons[labels[4]].tap()
        XCTAssertTrue(app.buttons[labels[5]].waitForExistence(timeout: 5), locale)
        app.buttons[labels[5]].tap()
        app.terminate()
    }
}
