import Foundation
import XCTest

final class BuildMacroTest: XCTestCase {
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
