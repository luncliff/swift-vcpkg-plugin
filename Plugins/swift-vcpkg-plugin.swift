/// @see https://github.com/swiftlang/swift-package-manager/blob/main/Documentation/Plugins.md
import Foundation
import PackagePlugin

class CommandBuilder {
    let workspace: URL

    init(workspace: URL) {
        self.workspace = workspace
    }

    func makeRegistryURL(tag: String) -> URL {
        URL(string: "https://github.com/microsoft/vcpkg/archive/refs/tags/\(tag).zip")!
    }

    func makeToolURL(tag: String) -> URL {
        URL(string: "https://github.com/microsoft/vcpkg-tool/releases/download/\(tag)/vcpkg-macos")!
    }

    func buildExtract(unzip: URL, zipFile: URL, destination: URL) -> Command {
        .prebuildCommand(
            displayName: "Run: unzip \(zipFile)",
            executable: unzip,
            arguments: ["-o", zipFile.path, "-d", destination.path],
            environment: ProcessInfo.processInfo.environment,
            outputFilesDirectory: destination
        )
    }

    func buildDownload(curl: URL, source: URL, destination: URL) -> Command {
        .prebuildCommand(
            displayName: "Run: curl \(source)",
            executable: curl,
            arguments: ["-L", source.absoluteString, "--output", destination.path],
            environment: ProcessInfo.processInfo.environment,
            outputFilesDirectory: destination
        )
    }

    func buildVersionCheck(vcpkgToolPath: URL) -> Command {
        let vcpkgRoot = URL(fileURLWithPath: "/tmp", isDirectory: true)
        return .prebuildCommand(
            displayName: "Run: vcpkg version",
            executable: vcpkgToolPath,
            arguments: ["--version"],
            environment: ProcessInfo.processInfo.environment,
            outputFilesDirectory: vcpkgRoot
        )
    }

    func buildInstall(vcpkgToolPath: URL, vcpkgRoot: URL, manifestRoot: URL, installRoot: URL, triplet: String? = nil) -> Command {
        // let vcpkgOutput = installRoot.appending(path: "vcpkg_installed")
        var args: [String] = ["install", // vcpkg help install
                              "--no-print-usage",
                              "--recurse",
                              "--vcpkg-root", vcpkgRoot.path, //
                              "--x-manifest-root", manifestRoot.path, //
                              "--x-install-root", installRoot.path]
        if triplet != nil {
            args.append("--triplet")
            args.append(triplet!)
        }
        var env = ProcessInfo.processInfo.environment
        env.removeValue(forKey: "VCPKG_ROOT")
        return .prebuildCommand(
            displayName: "Run: vcpkg install",
            executable: vcpkgToolPath,
            arguments: args,
            environment: env,
            outputFilesDirectory: installRoot
        )
    }

    func buildChangeFileMode(chmod: URL, target: URL, mode: String) -> Command {
        .prebuildCommand(
            displayName: "Run: chmod",
            executable: chmod,
            arguments: [mode, target.path],
            environment: ProcessInfo.processInfo.environment,
            outputFilesDirectory: target.deletingLastPathComponent()
        )
    }
}

let defaultRegistryVersion = "2025.04.09"
let defaultToolVersion = "2025-04-16"

/// Search the executable in the known system paths
func findProgramInSystem(name: String) -> URL? {
    let systemPaths = ["/opt/homebrew/bin", "/usr/local/bin", "/usr/bin", "/bin"]
    for path in systemPaths {
        let folder = URL(fileURLWithPath: path, isDirectory: true)
        let candidate = folder.appending(component: name)
        if FileManager.default.fileExists(atPath: candidate.path) {
            return candidate
        }
    }
    return nil
}

@main
struct swift_vcpkg_plugin: BuildToolPlugin {
    /// Search the executable in the context and system
    func findProgram(context: PluginContext, name: String) throws -> URL {
        do {
            let program = try context.tool(named: name)
            return program.url
        } catch {
            return findProgramInSystem(name: name)!
        }
    }

    /// Entry point for creating build commands for targets in Swift packages.
    func createBuildCommands(context: PluginContext, target _: Target) throws -> [Command] {
        let curl = try findProgram(context: context, name: "curl")
        let unzip = try findProgram(context: context, name: "unzip")
        let chmod = try findProgram(context: context, name: "chmod")

        let builder = CommandBuilder(workspace: context.pluginWorkDirectoryURL)
        let registrySource = builder.makeRegistryURL(tag: defaultRegistryVersion)
        let toolSource = builder.makeToolURL(tag: defaultToolVersion)

        let vcpkgFolderName = "vcpkg-\(defaultRegistryVersion)"
        let registryZipFile = context.pluginWorkDirectoryURL.appending(path: "\(vcpkgFolderName).zip")
        let vcpkgRoot = context.pluginWorkDirectoryURL.appending(path: vcpkgFolderName)
        let vcpkgToolPath: URL = vcpkgRoot.appending(path: "vcpkg")
        let vcpkgInstalled = context.pluginWorkDirectoryURL.appending(path: "vcpkg_installed")
        return [
            builder.buildDownload(curl: curl, source: registrySource, destination: registryZipFile),
            builder.buildExtract(unzip: unzip, zipFile: registryZipFile, destination: context.pluginWorkDirectoryURL),
            builder.buildDownload(curl: curl, source: toolSource, destination: vcpkgToolPath),
            builder.buildChangeFileMode(chmod: chmod, target: vcpkgToolPath, mode: "0755"),
            builder.buildVersionCheck(vcpkgToolPath: vcpkgToolPath),
            builder.buildInstall(vcpkgToolPath: vcpkgToolPath, vcpkgRoot: vcpkgRoot, manifestRoot: context.package.directoryURL, installRoot: vcpkgInstalled)
        ]
    }
}

#if canImport(XcodeProjectPlugin)
    import XcodeProjectPlugin

    extension swift_vcpkg_plugin: XcodeBuildToolPlugin {
        /// Search the executable in the context and system
        func findProgram(context: XcodePluginContext, name: String) throws -> URL {
            do {
                let program = try context.tool(named: name)
                return program.url
            } catch {
                return findProgramInSystem(name: name)!
            }
        }

        /// Entry point for creating build commands for targets in Xcode projects.
        func createBuildCommands(context: XcodePluginContext, target _: XcodeTarget) throws -> [Command] {
            let curl = try findProgram(context: context, name: "curl")
            let unzip = try findProgram(context: context, name: "unzip")
            let chmod = try findProgram(context: context, name: "chmod")

            let builder = CommandBuilder(workspace: context.pluginWorkDirectoryURL)
            let registrySource = builder.makeRegistryURL(tag: defaultRegistryVersion)
            let toolSource = builder.makeToolURL(tag: defaultToolVersion)

            let vcpkgFolderName = "vcpkg-\(defaultRegistryVersion)"
            let registryZipFile = context.pluginWorkDirectoryURL.appending(path: "\(vcpkgFolderName).zip")
            let vcpkgRoot = context.pluginWorkDirectoryURL.appending(path: vcpkgFolderName)
            let vcpkgToolPath: URL = vcpkgRoot.appending(path: "vcpkg")
            let vcpkgInstalled = context.pluginWorkDirectoryURL.appending(path: "vcpkg_installed")
            return [
                builder.buildDownload(curl: curl, source: registrySource, destination: registryZipFile),
                builder.buildExtract(unzip: unzip, zipFile: registryZipFile, destination: context.pluginWorkDirectoryURL),
                builder.buildDownload(curl: curl, source: toolSource, destination: vcpkgToolPath),
                builder.buildChangeFileMode(chmod: chmod, target: vcpkgToolPath, mode: "0755"),
                builder.buildVersionCheck(vcpkgToolPath: vcpkgToolPath),
                builder.buildInstall(vcpkgToolPath: vcpkgToolPath, vcpkgRoot: vcpkgRoot, manifestRoot: context.xcodeProject.directoryURL, installRoot: vcpkgInstalled)
            ]
        }
    }
#endif
