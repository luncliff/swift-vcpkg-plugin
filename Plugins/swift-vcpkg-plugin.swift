/// @see https://github.com/swiftlang/swift-package-manager/blob/main/Documentation/Plugins.md
import Foundation
import PackagePlugin

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

/// Search the executable in the context and system
func findProgram(context: PluginContext, name: String) throws -> URL {
    do {
        let program = try context.tool(named: name)
        return program.url
    } catch {
        // if we can't find the tool, can't advance. throw another error
        return findProgramInSystem(name: name)!
    }
}

@main
struct swift_vcpkg_plugin: BuildToolPlugin {
    /// Entry point for creating build commands for targets in Swift packages.
    /// @todo: reduce work time when caches are ready. currently, we consider it's a clean build
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
        let vcpkgInstallRoot = context.package.directoryURL.appending(path: ".build/artifacts")

        var commands: [Command] = []
        let fm = FileManager.default
        // if the vcpkg folder doesn't exist, download and extract it
        if !fm.fileExists(atPath: vcpkgRoot.path) {
            commands.append(builder.buildDownload(curl: curl, source: registrySource, destination: registryZipFile))
            commands.append(builder.buildExtract(unzip: unzip, zipFile: registryZipFile, destination: context.pluginWorkDirectoryURL))
        }
        // if the vcpkg tool doesn't exist, download it
        if !fm.fileExists(atPath: vcpkgToolPath.path) {
            commands.append(builder.buildDownload(curl: curl, source: toolSource, destination: vcpkgToolPath))
        }
        commands.append(contentsOf: [
            // vcpkg tool is not executable. we need to change the file mode
            builder.buildChangeFileMode(chmod: chmod, target: vcpkgToolPath, mode: "+x"),
            // run several commands. check the version for build log, and run install command
            builder.buildVersionCheck(vcpkgToolPath: vcpkgToolPath),
            builder.buildInstall(vcpkgToolPath: vcpkgToolPath, vcpkgRoot: vcpkgRoot, manifestRoot: context.package.directoryURL, installRoot: vcpkgInstallRoot),
            // note: for some reason --x--x--x causes plugin cache generation error
            // TODO: need more investigation for the error messages
            builder.buildChangeFileMode(chmod: chmod, target: vcpkgToolPath, mode: "-x")
        ])
        return commands
    }
}

#if canImport(XcodeProjectPlugin)
    import XcodeProjectPlugin

    /// Search the executable in the context and system
    func findProgram(context: XcodePluginContext, name: String) throws -> URL {
        do {
            let program = try context.tool(named: name)
            return program.url
        } catch {
            // if we can't find the tool, can't advance. throw another error
            return findProgramInSystem(name: name)!
        }
    }

    extension swift_vcpkg_plugin: XcodeBuildToolPlugin {
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
            let vcpkgInstallRoot = context.xcodeProject.directoryURL.appending(path: ".build/artifacts")

            // same step with the createBuildCommands above
            var commands: [Command] = []
            let fm = FileManager.default
            if !fm.fileExists(atPath: vcpkgRoot.path) {
                commands.append(builder.buildDownload(curl: curl, source: registrySource, destination: registryZipFile))
                commands.append(builder.buildExtract(unzip: unzip, zipFile: registryZipFile, destination: context.pluginWorkDirectoryURL))
            }
            if !fm.fileExists(atPath: vcpkgToolPath.path) {
                commands.append(builder.buildDownload(curl: curl, source: toolSource, destination: vcpkgToolPath))
            }
            commands.append(contentsOf: [
                builder.buildChangeFileMode(chmod: chmod, target: vcpkgToolPath, mode: "+x"),
                builder.buildVersionCheck(vcpkgToolPath: vcpkgToolPath),
                builder.buildInstall(vcpkgToolPath: vcpkgToolPath, vcpkgRoot: vcpkgRoot, manifestRoot: context.xcodeProject.directoryURL, installRoot: vcpkgInstallRoot),
                builder.buildChangeFileMode(chmod: chmod, target: vcpkgToolPath, mode: "-x")
            ])
            return commands
        }
    }
#endif
