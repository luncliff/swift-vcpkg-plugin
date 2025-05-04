import Foundation
import XCTest

final class EnvironmentVariableTest: XCTestCase {
    func test_vcpkg_in_PATH() {
        let paths = ProcessInfo.processInfo.environment["PATH"]?.split(separator: ":")
        XCTAssertNotNil(paths)
        XCTAssertNotEqual(0, paths!.count)
        let fm = FileManager.default
        let candidate: String.SubSequence? = paths?.first(where: { folder in
            fm.fileExists(atPath: String(folder) + "/vcpkg")
        })
        // expect the XCTest sandbox doesn't contain vcpkg executable
        if candidate != nil {
            print(candidate!)
        }
        // XCTAssertNil(candidate)
    }
}

final class EnvironmentChangeTest: XCTestCase {
    let workspace: URL = .init(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
    let curlPath = URL(fileURLWithPath: "/usr/bin/curl")
    let unzipPath = URL(fileURLWithPath: "/usr/bin/unzip")

    /// Remove all subfolders under "\(workspace)/vcpkg"
    func cleanupVcpkgRoot() throws {
        let vcpkgRoot = workspace.appending(path: "vcpkg-2025.04.09")
        let fm = FileManager.default
        if !fm.fileExists(atPath: vcpkgRoot.path) {
            return
        }
        try fm.removeItem(atPath: vcpkgRoot.path)
    }

    override func setUp() {
        let fm = FileManager.default
        XCTAssertTrue(fm.fileExists(atPath: unzipPath.path))
        XCTAssertTrue(fm.fileExists(atPath: curlPath.path))
        try! cleanupVcpkgRoot()
    }

    func test_install_tool() async throws {
        let helper = VcpkgHelper(workspace: workspace)
        // the vcpkg-tool executable should be located under the vcpkg root
        let vcpkgRoot = workspace.appending(path: "vcpkg-2025.04.09")
        let output = try await helper.installTool(vcpkgRoot: vcpkgRoot)
        XCTAssertTrue(FileManager.default.fileExists(atPath: output.path))
        // the downloaded file must be renamed to 'vcpkg'
        XCTAssertEqual(output.lastPathComponent, "vcpkg")
    }

    func test_install_tool_curl() throws {
        let helper = VcpkgHelper(workspace: workspace)
        // the vcpkg-tool executable should be located under the vcpkg root
        let vcpkgRoot = workspace.appending(path: "vcpkg-2025.04.09")

        let output = try helper.installTool(curl: curlPath, vcpkgRoot: vcpkgRoot)
        let fm = FileManager.default
        XCTAssertTrue(fm.fileExists(atPath: output.path))
        // the downloaded file must be renamed to 'vcpkg'
        XCTAssertEqual(output.lastPathComponent, "vcpkg")

        // Check if download.log was created in the same directory as the vcpkg tool
        let logFile = vcpkgRoot.appendingPathComponent("download.log")
        XCTAssertTrue(fm.fileExists(atPath: logFile.path))
    }

    func test_install_registry() async throws {
        let helper = VcpkgHelper(workspace: workspace)
        let vcpkgRoot = try await helper.installUpstream(unzip: unzipPath)
        XCTAssertTrue(vcpkgRoot.lastPathComponent.contains("vcpkg-")) // ex) vcpkg-2025.04.09
        let fm = FileManager.default
        XCTAssertTrue(fm.fileExists(atPath: vcpkgRoot.path))
    }

    func test_install_registry_curl() async throws {
        let helper = VcpkgHelper(workspace: workspace)
        let vcpkgRoot = try helper.installUpstream(unzip: unzipPath, curl: curlPath)
        XCTAssertTrue(vcpkgRoot.lastPathComponent.contains("vcpkg-")) // ex) vcpkg-2025.04.09
        let fm = FileManager.default
        XCTAssertTrue(fm.fileExists(atPath: vcpkgRoot.path))
    }
}
