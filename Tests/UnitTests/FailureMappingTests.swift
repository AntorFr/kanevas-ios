import XCTest
@testable import KanevasCore

/// AD-reseau-1: the pure mapping of errors and HTTP codes to E-2.
final class FailureMappingTests: XCTestCase {
    private func urlError(_ code: Int) -> NSError { NSError(domain: NSURLErrorDomain, code: code) }

    func testConnectivityErrorsAreUnreachable() {
        let codes = [NSURLErrorNotConnectedToInternet, NSURLErrorCannotConnectToHost, NSURLErrorCannotFindHost,
                     NSURLErrorTimedOut, NSURLErrorNetworkConnectionLost, NSURLErrorDNSLookupFailed,
                     NSURLErrorSecureConnectionFailed, NSURLErrorServerCertificateUntrusted,
                     NSURLErrorInternationalRoamingOff, NSURLErrorDataNotAllowed]
        for code in codes {
            XCTAssertEqual(FailureMapping.state(forError: urlError(code)), .unreachable, "code \(code)")
        }
    }

    func testAnyOtherURLErrorIsUnreachable() {
        XCTAssertEqual(FailureMapping.state(forError: urlError(-1)), .unreachable)
        XCTAssertEqual(FailureMapping.state(forError: urlError(NSURLErrorBadURL)), .unreachable)
    }

    func testCancellationIsNeverAFailure() {
        XCTAssertEqual(FailureMapping.state(forError: urlError(NSURLErrorCancelled)), .ok)
        XCTAssertEqual(FailureMapping.state(forError: URLError(.cancelled)), .ok)
    }

    func testWebKitFrameLoadInterruptedIsNotAFailure() {
        let error = NSError(domain: "WebKitErrorDomain", code: 102)
        XCTAssertEqual(FailureMapping.state(forError: error), .ok)
    }

    func testForeignDomainsAreNotFailures() {
        XCTAssertEqual(FailureMapping.state(forError: NSError(domain: NSCocoaErrorDomain, code: 4)), .ok)
        XCTAssertEqual(FailureMapping.state(forError: NSError(domain: "WebKitErrorDomain", code: 101)), .ok)
        // A cancelled code number in another domain is not NSURLErrorCancelled.
        XCTAssertEqual(FailureMapping.state(forError: NSError(domain: "Other", code: NSURLErrorTimedOut)), .ok)
    }

    func testURLErrorStructBridges() {
        XCTAssertEqual(FailureMapping.state(forError: URLError(.notConnectedToInternet)), .unreachable)
        XCTAssertEqual(FailureMapping.state(forError: URLError(.cannotConnectToHost)), .unreachable)
    }

    func testServerErrorsAreUnreachable() {
        for status in [500, 501, 502, 503, 504, 520, 599] {
            XCTAssertEqual(FailureMapping.state(forHTTPStatus: status), .unreachable, "\(status)")
        }
    }

    func testOtherStatusesStayInTheView() {
        for status in [100, 200, 204, 301, 302, 304, 400, 401, 403, 404, 429, 499, 600, 0, -1] {
            XCTAssertEqual(FailureMapping.state(forHTTPStatus: status), .ok, "\(status)")
        }
    }
}
