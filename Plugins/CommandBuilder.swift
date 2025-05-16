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
        .prebuildCommand(
            displayName: "Run: vcpkg version",
            executable: vcpkgToolPath,
            arguments: ["--version"],
            environment: ProcessInfo.processInfo.environment,
            outputFilesDirectory: workspace
        )
    }

    func buildInstall(vcpkgToolPath: URL, vcpkgRoot: URL, manifestRoot: URL, installRoot: URL, triplet: String? = nil) -> Command {
        var args: [String] = ["install", // vcpkg help install
                              "--no-print-usage",
                              "--recurse",
                              "--clean-after-build", // remove files not to disturb plugin caching
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

    func buildClean(remove: URL, targets: [URL]) -> Command {
        var args: [String] = ["-f", "-R"] // remove recursively
        for t in targets {
            args.append(t.path)
        }
        return .prebuildCommand(
            displayName: "Run: rm \(targets.count) items",
            executable: remove,
            arguments: args,
            environment: ProcessInfo.processInfo.environment,
            outputFilesDirectory: workspace
        )
    }
}
