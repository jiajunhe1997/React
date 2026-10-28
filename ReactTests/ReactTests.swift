import XCTest
@testable import React

final class ReactTests: XCTestCase {
    func testRequestedMarketResourcesAreShippedInEveryBundle() throws {
        let plugins = try XCTUnwrap(Bundle.main.builtInPlugInsURL)
        let keyboard = try XCTUnwrap(Bundle(url: plugins.appendingPathComponent("Keyboard.appex")))
        let share = try XCTUnwrap(Bundle(url: plugins.appendingPathComponent("React Share.appex")))
        XCTAssertEqual(keyboard.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String, "React Keyboard")
        XCTAssertEqual(keyboard.object(forInfoDictionaryKey: "UIDeviceFamily") as? [Int], [1, 2])
        for bundle in [Bundle.main, keyboard, share] {
            for locale in ["hi", "fr", "es", "es-419", "ja", "id", "en-IN"] {
                let url = try XCTUnwrap(bundle.url(forResource: locale, withExtension: "lproj"))
                let localized = try XCTUnwrap(Bundle(url: url))
                let title = localized.localizedString(forKey: "Add Board", value: nil, table: nil)
                XCTAssertFalse(title.isEmpty)
                if locale != "en-IN" { XCTAssertNotEqual(title, "Add Board", "\(bundle.bundleURL.lastPathComponent): \(locale)") }
            }
        }
    }

    func testPhotoMovesInBothDirectionsAndRejectsStalePaths() {
        XCTAssertEqual(PhotoOrdering.move("a", to: "c", in: ["a", "b", "c"]), ["b", "c", "a"])
        XCTAssertEqual(PhotoOrdering.move("c", to: "a", in: ["a", "b", "c"]), ["c", "a", "b"])
        XCTAssertEqual(PhotoOrdering.move("deleted", to: "b", in: ["a", "b"]), ["a", "b"])
        XCTAssertEqual(PhotoOrdering.move("a", to: "a", in: ["a", "b"]), ["a", "b"])
    }

    func testReorderingRetainsBoardIdentityContentsAndTrash() {
        let first = Category(name: "First", imagePaths: ["photo.png"])
        let second = Category(name: "Second")
        let trash = Category(name: "Trash", isTrash: true)
        let result = BoardOrdering.apply([second.id, first.id], to: [first, trash, second])
        XCTAssertEqual(result.map(\.id), [second.id, first.id, trash.id])
        XCTAssertEqual(result[1].imagePaths, ["photo.png"])
    }

    func testStaleAndDuplicateIDsKeepNewBoardsWithoutResurrectingDeletedBoards() {
        let first = Category(name: "First")
        let added = Category(name: "Added while editing")
        let result = BoardOrdering.apply([UUID(), first.id, first.id], to: [first, added])
        XCTAssertEqual(result.map(\.id), [first.id, added.id])
        XCTAssertTrue(BoardOrdering.apply([], to: []).isEmpty)
    }
}
