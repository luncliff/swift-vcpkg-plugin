/// @see https://github.com/swiftlang/swift-package-manager/blob/main/Documentation/Plugins.md
import Foundation
import PackagePlugin

/// try find executable `vcpkg` in PATH enviroment variables
func getVcpkgTool() -> String? {
    let paths = ProcessInfo.processInfo.environment["PATH"]?.split(separator: ":")
    let fm = FileManager.default
    let candidate: String.SubSequence? = paths?.first(where: { folder in
        fm.fileExists(atPath: String(folder) + "/vcpkg")
    })
    if candidate == nil {
        return nil
    }
    return String(candidate!)
}

/// try search where ports/ and version/ folders are located
func guessVcpkgRoot() -> URL {
    let vcpkgRoot: String? = ProcessInfo.processInfo.environment["VCPKG_ROOT"]
    if vcpkgRoot != nil {
        return URL(fileURLWithPath: vcpkgRoot!, isDirectory: true)
    }
    print("Warning: VCPKG_ROOT enviroment variable not defined")
    // check the `vcpkg` executable exists and use the folder of the executable
    let vcpkgToolPath = getVcpkgTool()
    if vcpkgToolPath != nil {
        return URL(fileURLWithPath: vcpkgToolPath!).baseURL!
    }
    // We don't have much help, use current `swift` CLI workspace with subfolder
    let fm = FileManager.default
    return URL(fileURLWithPath: fm.currentDirectoryPath.appending("/vcpkg"), isDirectory: true)
}

// vcpkg --version
func vcpkgVersionCheck(vcpkgToolPath: URL) -> Command {
    let vcpkgInstallRoot = URL(fileURLWithPath: "/tmp", isDirectory: true)
    return .prebuildCommand(
        displayName: "Run: vcpkg version",
        executable: vcpkgToolPath,
        arguments: ["--version"],
        environment: ProcessInfo.processInfo.environment,
        outputFilesDirectory: vcpkgInstallRoot
    )
}

// vcpkg install ...
func vcpkgInstall(vcpkgToolPath: URL, manifestRoot: URL, installRoot: URL?, triplet: String? = nil) -> Command {
    let vcpkgInstallRoot = installRoot ?? guessVcpkgRoot()
    let vcpkgOutput = vcpkgInstallRoot.appending(path: "vcpkg/info")
    var args: [String] = ["install", // vcpkg help install
                          "--x-manifest-root", manifestRoot.absoluteString, //
                          "--x-install-root", vcpkgInstallRoot.absoluteString]
    if triplet != nil {
        args.append("--triplet")
        args.append(triplet!)
    }
    return .prebuildCommand(
        displayName: "Run: vcpkg install",
        executable: vcpkgToolPath,
        arguments: args,
        environment: ProcessInfo.processInfo.environment,
        outputFilesDirectory: vcpkgOutput
    )
}

@main
struct swift_vcpkg_plugin: BuildToolPlugin {
    /// Entry point for creating build commands for targets in Swift packages.
    func createBuildCommands(context: PluginContext, target _: Target) async throws -> [Command] {
        let workspace = context.package.directoryURL
        let vcpkgOutput = workspace.appending(path: "vcpkg/info")
        let vcpkgTool = try context.tool(named: "vcpkg")
        return [
            vcpkgVersionCheck(vcpkgToolPath: vcpkgTool.url),
            vcpkgInstall(vcpkgToolPath: vcpkgTool.url, manifestRoot: workspace, installRoot: vcpkgOutput)
        ]
    }
}

#if canImport(XcodeProjectPlugin)
    import XcodeProjectPlugin

    extension swift_vcpkg_plugin: XcodeBuildToolPlugin {
        /// Entry point for creating build commands for targets in Xcode projects.
        func createBuildCommands(context: XcodePluginContext, target _: XcodeTarget) throws -> [Command] {
            let workspace = context.xcodeProject.directoryURL
            let vcpkgTool = try context.tool(named: "vcpkg")
            return [
                vcpkgVersionCheck(vcpkgToolPath: vcpkgTool.url),
                vcpkgInstall(vcpkgToolPath: vcpkgTool.url, manifestRoot: workspace, installRoot: workspace)
            ]
        }
    }
#endif
