import XCTest
@testable import KanevasCore

final class BaseURLTests: XCTestCase {
    private let plist: [String: Any] = ["KanevasBaseURL": "https://kanevas.berard.me"]

    func testLaunchArgumentWinsOverInfoPlist() {
        let url = BaseURL.resolve(arguments: ["app", "-KANEVAS_URL", "http://127.0.0.1:3100"], infoDictionary: plist)
        XCTAssertEqual(url?.absoluteString, "http://127.0.0.1:3100")
    }

    func testInfoPlistUsedWithoutArgument() {
        let url = BaseURL.resolve(arguments: ["app"], infoDictionary: plist)
        XCTAssertEqual(url?.absoluteString, "https://kanevas.berard.me")
    }

    func testNilWhenNeitherSource() {
        XCTAssertNil(BaseURL.resolve(arguments: ["app"], infoDictionary: nil))
        XCTAssertNil(BaseURL.resolve(arguments: ["app"], infoDictionary: [:]))
    }

    func testArgumentWithoutValueFallsBackToInfoPlist() {
        let url = BaseURL.resolve(arguments: ["app", "-KANEVAS_URL"], infoDictionary: plist)
        XCTAssertEqual(url?.absoluteString, "https://kanevas.berard.me")
    }

    func testInvalidArgumentFallsBackToInfoPlist() {
        for bad in ["not a url", "ftp://host/x", "", "http://", "javascript:alert(1)"] {
            let url = BaseURL.resolve(arguments: ["app", "-KANEVAS_URL", bad], infoDictionary: plist)
            XCTAssertEqual(url?.absoluteString, "https://kanevas.berard.me", "bad: \(bad)")
        }
    }

    func testInvalidInfoPlistGivesNil() {
        XCTAssertNil(BaseURL.resolve(arguments: ["app"], infoDictionary: ["KanevasBaseURL": "nope"]))
        XCTAssertNil(BaseURL.resolve(arguments: ["app"], infoDictionary: ["KanevasBaseURL": 42]))
    }

    func testWhitespaceTrimmedAndSchemeCaseInsensitive() {
        let url = BaseURL.resolve(arguments: ["app", "-KANEVAS_URL", "  HTTP://localhost:3100  "], infoDictionary: plist)
        XCTAssertEqual(url?.host, "localhost")
        XCTAssertEqual(url?.port, 3100)
    }

    func testKeyWithoutDashIsNotALaunchArgument() {
        let url = BaseURL.resolve(arguments: ["app", "KANEVAS_URL", "http://evil.test"], infoDictionary: plist)
        XCTAssertEqual(url?.absoluteString, "https://kanevas.berard.me")
    }
}
