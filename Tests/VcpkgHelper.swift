import Foundation

func makeRegistryURL(tag: String) -> URL {
    URL(string: "https://github.com/microsoft/vcpkg/archive/refs/tags/\(tag).zip")!
}

func makeToolURL(tag: String) -> URL {
    URL(string: "https://github.com/microsoft/vcpkg-tool/releases/download/\(tag)/vcpkg-macos")!
}

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

enum VcpkgHelperError: Error, CustomStringConvertible {
    case downloadFailed
    case extractFailed
    case entryNotFound

    var description: String {
        switch self {
        case .downloadFailed:
            "Failed to download"
        case .extractFailed:
            "Failed to extract"
        case .entryNotFound:
            "The folder/file doesn't exist"
        }
    }
}

func createFolders(destination: URL) throws -> URL {
    let fm = FileManager.default
    var p = destination.deletingLastPathComponent()
    if destination.hasDirectoryPath {
        p = destination
    }
    if !fm.fileExists(atPath: p.path) {
        try fm.createDirectory(at: p, withIntermediateDirectories: true)
    }
    return p
}

func createFile(folder: URL, name: String) throws -> URL {
    let fm = FileManager.default
    let f = folder.appendingPathComponent(name)
    if fm.fileExists(atPath: f.path) {
        try fm.removeItem(at: f)
    }
    if fm.createFile(atPath: f.path, contents: nil) == false {
        throw VcpkgHelperError.entryNotFound
    }
    return f
}

func overwrite(src: URL, dest: URL) throws {
    let fm = FileManager.default
    if fm.fileExists(atPath: dest.path) {
        try fm.removeItem(at: dest)
    }
    try fm.copyItem(at: src, to: dest)
}

/// Helper function to download a file using URLSession
func downloadFile(from remote: URL, to destination: URL, acceptType: String? = nil) async throws {
    _ = try createFolders(destination: destination)

    // Make request and download
    var request = URLRequest(url: remote)
    if let acceptType {
        request.addValue(acceptType, forHTTPHeaderField: "Accept")
    }
    let session = URLSession(configuration: URLSessionConfiguration.default)
    // Receive the response and check it
    let (local, res) = try await session.download(for: request)
    let response = res as? HTTPURLResponse
    if response?.statusCode != 200 {
        throw VcpkgHelperError.downloadFailed
    }
    try overwrite(src: local, dest: destination)
}

func downloadFile(curl: URL, from source: URL, to destination: URL) throws -> Bool {
    let outputs = try createFolders(destination: destination)

    let process = Process()
    process.executableURL = curl
    // TODO: HTTP GET request, header may contain "Accept" field
    process.arguments = ["-L", source.absoluteString, "--output", destination.path]

    // Connect stdout and stderr directly to the log file
    let logFile = try createFile(folder: outputs, name: "download.log")
    let opipe = try FileHandle(forWritingTo: logFile)
    defer { opipe.closeFile() }
    process.standardOutput = opipe
    process.standardError = opipe

    try process.run()
    process.waitUntilExit()
    return process.terminationStatus == 0
}

/// Helper function to extract a ZIP file using system unzip command
func extractWithUnzip(unzip: URL, from source: URL, to destination: URL) throws -> Bool {
    let outputs = try createFolders(destination: destination)

    let process = Process()
    process.executableURL = unzip
    process.arguments = ["-o", source.path, "-d", destination.path]

    // Connect stdout and stderr directly to the log file
    let logFile = try createFile(folder: outputs, name: "extract.log")
    let opipe = try FileHandle(forWritingTo: logFile)
    defer { opipe.closeFile() }
    process.standardOutput = opipe
    process.standardError = opipe

    try process.run()
    process.waitUntilExit()
    return process.terminationStatus == 0
}

class VcpkgHelper {
    static let defaultRegistryVersion = "2025.04.09"
    static let defaultToolVersion = "2025-04-16"

    let workspace: URL

    init(workspace: URL) {
        self.workspace = workspace
    }

    func installUpstream(unzip: URL, registry: String? = defaultRegistryVersion) async throws -> URL {
        let remote = makeRegistryURL(tag: registry!)
        print("Using registry: \(remote)")
        let vcpkgFolderName = "vcpkg-\(registry!)"
        print("Using folder: \(vcpkgFolderName)")

        let vcpkgRoot = workspace.appending(component: vcpkgFolderName)
        let zipFile = workspace.appending(component: "\(vcpkgFolderName).zip")
        try await downloadFile(from: remote, to: zipFile, acceptType: "application/zip")

        if try extractWithUnzip(unzip: unzip, from: zipFile, to: workspace) == false {
            throw VcpkgHelperError.extractFailed
        }
        return vcpkgRoot
    }

    func installUpstream(unzip: URL, curl: URL, registry: String? = defaultRegistryVersion) throws -> URL {
        let remote = makeRegistryURL(tag: registry!)
        print("Using registry: \(remote)")
        let vcpkgFolderName = "vcpkg-\(registry!)"
        print("Using folder: \(vcpkgFolderName)")

        let vcpkgRoot = workspace.appending(component: vcpkgFolderName)
        let zipFile = workspace.appending(component: "\(vcpkgFolderName).zip")
        if try downloadFile(curl: curl, from: remote, to: zipFile) == false {
            throw VcpkgHelperError.downloadFailed
        }

        if try extractWithUnzip(unzip: unzip, from: zipFile, to: workspace) == false {
            throw VcpkgHelperError.extractFailed
        }
        return vcpkgRoot
    }

    func installTool(vcpkgRoot: URL, tool: String? = defaultToolVersion) async throws -> URL {
        let remote = makeToolURL(tag: tool!)
        print("Using vcpkg-tool: \(remote)")

        let vcpkgTool = vcpkgRoot.appending(component: "vcpkg")
        try await downloadFile(from: remote, to: vcpkgTool, acceptType: "application/octet-stream")
        return vcpkgTool
    }

    func installTool(curl: URL, vcpkgRoot: URL, tool: String? = defaultToolVersion) throws -> URL {
        let remote = makeToolURL(tag: tool!)
        print("Using vcpkg-tool: \(remote)")

        let vcpkgTool = vcpkgRoot.appending(component: "vcpkg")
        if try downloadFile(curl: curl, from: remote, to: vcpkgTool) == false {
            throw VcpkgHelperError.downloadFailed
        }

        let fm = FileManager.default
        // Make sure the tool is executable
        try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: vcpkgTool.path)
        return vcpkgTool
    }

    func install(unzip: URL, registry: String? = defaultRegistryVersion, tool: String? = defaultToolVersion) async throws -> URL {
        let vcpkgRoot: URL = try await installUpstream(unzip: unzip, registry: registry)
        let fm = FileManager.default
        if fm.fileExists(atPath: vcpkgRoot.path) == false {
            throw VcpkgHelperError.entryNotFound
        }
        let vcpkgTool: URL = try await installTool(vcpkgRoot: vcpkgRoot, tool: tool)
        if fm.fileExists(atPath: vcpkgTool.path) == false {
            throw VcpkgHelperError.entryNotFound
        }
        try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: vcpkgTool.path)
        return vcpkgRoot
    }
}
