import Foundation
import PackagePlugin

enum PetrelCodegenPluginError: Error, CustomStringConvertible {
    case missingGeneratorRuntime(String)
    case commandFailed(executable: String, arguments: [String], status: Int32)

    var description: String {
        switch self {
        case .missingGeneratorRuntime(let detail):
            return """
            PetrelCodegenPlugin could not locate `petrel-gen` or a Python 3 environment with `jinja2`, `aiofiles`, and `orjson`.
            \(detail)

            Install `petrel-gen` once and re-run:
              uv tool install "git+https://github.com/joshlacal/Petrel.git@2.0.0"
              # or: pipx install "git+https://github.com/joshlacal/Petrel.git@2.0.0"
            """
        case .commandFailed(let executable, let arguments, let status):
            let rendered = ([executable] + arguments).joined(separator: " ")
            return "PetrelCodegenPlugin failed (exit \(status)): \(rendered)"
        }
    }
}

@main
struct PetrelCodegenPlugin: CommandPlugin {
    func performCommand(context: PluginContext, arguments: [String]) async throws {
        try runCodegen(in: context.package.directoryURL, rawArguments: arguments)
    }

    private func runCodegen(in packageDirectoryURL: URL, rawArguments: [String]) throws {
        var extractor = ArgumentExtractor(rawArguments)
        _ = extractor.extractOption(named: "target")
        let forwarded = extractor.remainingArguments

        let cliArguments = Self.buildCLIArguments(
            packageDirectoryURL: packageDirectoryURL,
            forwardedArguments: forwarded
        )
        let invocation = try Self.resolveGeneratorInvocation()

        let process = Process()
        process.executableURL = invocation.executableURL
        process.arguments = invocation.prefixArguments + cliArguments
        process.currentDirectoryURL = packageDirectoryURL
        process.standardOutput = FileHandle.standardOutput
        process.standardError = FileHandle.standardError

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw PetrelCodegenPluginError.commandFailed(
                executable: invocation.executableURL.path,
                arguments: process.arguments ?? [],
                status: process.terminationStatus
            )
        }
    }

    private static func buildCLIArguments(
        packageDirectoryURL: URL,
        forwardedArguments: [String]
    ) -> [String] {
        let knownSubcommands: Set<String> = [
            "generate", "init", "inspect", "info", "--help", "-h", "--version",
        ]
        if let first = forwardedArguments.first, knownSubcommands.contains(first) {
            return forwardedArguments
        }

        var built = ["generate"]
        if !forwardedArguments.contains(where: { $0 == "--manifest" || $0.hasPrefix("--manifest=") }) {
            let defaultManifest = packageDirectoryURL.appendingPathComponent("petrel-manifest.json")
            built.append(contentsOf: ["--manifest", defaultManifest.path])
        }
        built.append(contentsOf: forwardedArguments)
        return built
    }

    private struct GeneratorInvocation {
        let executableURL: URL
        let prefixArguments: [String]
    }

    private static func resolveGeneratorInvocation() throws -> GeneratorInvocation {
        let env = ProcessInfo.processInfo.environment
        let fileManager = FileManager.default

        if let explicitCLI = env["PETREL_GEN"], !explicitCLI.isEmpty {
            let url = URL(fileURLWithPath: explicitCLI)
            if fileManager.isExecutableFile(atPath: url.path) {
                return GeneratorInvocation(executableURL: url, prefixArguments: [])
            }
        }

        if let cliOnPath = findExecutableOnPATH(named: "petrel-gen", environment: env) {
            return GeneratorInvocation(executableURL: cliOnPath, prefixArguments: [])
        }

        let pluginFileURL = URL(fileURLWithPath: #filePath)
        let petrelPackageRootURL = pluginFileURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let bundledCLIURL = petrelPackageRootURL
            .appendingPathComponent("generator")
            .appendingPathComponent("cli.py")

        if fileManager.isReadableFile(atPath: bundledCLIURL.path) {
            if let explicitPython = env["PETREL_PYTHON"],
               !explicitPython.isEmpty,
               fileManager.isExecutableFile(atPath: explicitPython)
            {
                return GeneratorInvocation(
                    executableURL: URL(fileURLWithPath: explicitPython),
                    prefixArguments: [bundledCLIURL.path]
                )
            }

            if let pythonURL = findExecutableOnPATH(named: "python3", environment: env),
               pythonHasGeneratorDependencies(pythonURL: pythonURL)
            {
                return GeneratorInvocation(
                    executableURL: pythonURL,
                    prefixArguments: [bundledCLIURL.path]
                )
            }
        }

        throw PetrelCodegenPluginError.missingGeneratorRuntime(
            "Checked PETREL_GEN, PATH (`petrel-gen`), PETREL_PYTHON, and ambient `python3`."
        )
    }

    private static func findExecutableOnPATH(
        named name: String,
        environment: [String: String]
    ) -> URL? {
        guard let pathValue = environment["PATH"] else {
            return nil
        }
        let fileManager = FileManager.default
        for directory in pathValue.split(separator: ":") where !directory.isEmpty {
            let candidate = URL(fileURLWithPath: String(directory)).appendingPathComponent(name)
            if fileManager.isExecutableFile(atPath: candidate.path) {
                return candidate
            }
        }
        return nil
    }

    private static func pythonHasGeneratorDependencies(pythonURL: URL) -> Bool {
        let probe = Process()
        probe.executableURL = pythonURL
        probe.arguments = ["-c", "import jinja2, aiofiles, orjson"]
        probe.standardOutput = FileHandle.nullDevice
        probe.standardError = FileHandle.nullDevice
        do {
            try probe.run()
            probe.waitUntilExit()
            return probe.terminationStatus == 0
        } catch {
            return false
        }
    }
}

#if canImport(XcodeProjectPlugin)
import XcodeProjectPlugin

extension PetrelCodegenPlugin: XcodeCommandPlugin {
    func performCommand(context: XcodePluginContext, arguments: [String]) throws {
        try runCodegen(in: context.xcodeProject.directoryURL, rawArguments: arguments)
    }
}
#endif
