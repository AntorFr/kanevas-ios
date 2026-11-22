import XCTest
@testable import KanevasCore

final class NavigationPolicyTests: XCTestCase {
    private let hosts: Set<String> = ["kanevas.berard.me", "auth.berard.me"]

    private func decide(_ s: String?, blank: Bool = false, hosts: Set<String>? = nil) -> NavigationDecision {
        NavigationPolicy.decide(url: s.flatMap(URL.init(string:)), targetIsNewWindow: blank, allowedHosts: hosts ?? self.hosts)
    }

    func testAllowedHostsStayInView() {
        XCTAssertEqual(decide("https://kanevas.berard.me/boards/1"), .allowInView)
        XCTAssertEqual(decide("https://auth.berard.me/?rd=x"), .allowInView)
    }

    func testOtherHostGoesToSystem() {
        XCTAssertEqual(decide("https://example.org/"), .openExternally)
    }

    func testBlankToAllowedHostLoadsInView() {
        XCTAssertEqual(decide("https://kanevas.berard.me/next", blank: true), .loadInView)
    }

    func testBlankToOtherHostGoesToSystem() {
        XCTAssertEqual(decide("https://example.org/", blank: true), .openExternally)
    }

    func testHostMatchIsExactAndCaseInsensitive() {
        XCTAssertEqual(decide("https://KANEVAS.berard.me/"), .allowInView)
        XCTAssertEqual(decide("https://evil.kanevas.berard.me/"), .openExternally)
        XCTAssertEqual(decide("https://kanevas.berard.me.evil.org/"), .openExternally)
        XCTAssertEqual(decide("https://kanevas.berard.me@evil.org/"), .openExternally)
        XCTAssertEqual(decide("https://evil.org/?u=kanevas.berard.me"), .openExternally)
        XCTAssertEqual(decide("https://berard.me/"), .openExternally)
    }

    func testPlainHttpOnlyForLoopback() {
        XCTAssertEqual(decide("http://kanevas.berard.me/"), .openExternally)
        XCTAssertEqual(decide("http://127.0.0.1:3100/", hosts: ["127.0.0.1"]), .allowInView)
        XCTAssertEqual(decide("http://localhost:3100/", hosts: ["localhost"]), .allowInView)
    }

    func testNoHostOrOddSchemeNeverStaysInView() {
        XCTAssertEqual(decide(nil), .openExternally)
        XCTAssertEqual(decide("about:blank"), .openExternally)
        XCTAssertEqual(decide("mailto:a@kanevas.berard.me"), .openExternally)
        XCTAssertEqual(decide("javascript:alert(1)"), .openExternally)
        XCTAssertEqual(decide("file:///etc/passwd"), .openExternally)
        XCTAssertEqual(decide("tel:123", blank: true), .openExternally)
    }

    func testEmptyAllowedSetSendsEverythingOut() {
        XCTAssertEqual(decide("https://kanevas.berard.me/", hosts: []), .openExternally)
    }

    func testAllowedHostsArgumentOverridesPlistAndBaseHostAlwaysIn() {
        let plist: [String: Any] = ["KanevasAllowedHosts": "kanevas.berard.me, auth.berard.me"]
        let base = URL(string: "http://127.0.0.1:3100")
        XCTAssertEqual(NavigationPolicy.allowedHosts(arguments: ["app"], infoDictionary: plist, baseURL: nil),
                       ["kanevas.berard.me", "auth.berard.me"])
        XCTAssertEqual(NavigationPolicy.allowedHosts(arguments: ["app", "-KANEVAS_ALLOWED_HOSTS", "A.test,,b.test"],
                                                     infoDictionary: plist, baseURL: base),
                       ["a.test", "b.test", "127.0.0.1"])
        XCTAssertEqual(NavigationPolicy.allowedHosts(arguments: ["app"], infoDictionary: nil, baseURL: base), ["127.0.0.1"])
        XCTAssertEqual(NavigationPolicy.allowedHosts(arguments: ["app", "-KANEVAS_ALLOWED_HOSTS"], infoDictionary: plist, baseURL: nil),
                       ["kanevas.berard.me", "auth.berard.me"])
    }
}
