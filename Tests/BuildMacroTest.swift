import Foundation
import XCTest

final class BuildMacroTest: XCTestCase {
    func getProcessArch() -> String {
        #if arch(arm64)
            return "arm64"
        #else
            return "x64"
        #endif
    }

    func getSystemName() throws -> String {
        #if os(macOS)
            return "osx"
        #elseif os(iOS)
            return "ios"
        #else
            throw Error("Unsupported target system")
        #endif
    }

    func makeTriplet() throws -> String {
        try "\(getProcessArch())-\(getSystemName())"
    }

    func testHostTriplet() {
        #if os(macOS) && arch(arm64)
            XCTAssertEqual(try makeTriplet(), "arm64-osx")
        #else
            XCTAssertEqual(try makeTriplet(), "x64-osx")
        #endif
    }
}
