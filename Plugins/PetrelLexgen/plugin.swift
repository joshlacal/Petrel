import Foundation
import PackagePlugin

/// `swift package petrel-lexgen`: generates Swift types and XRPC calls from Lexicon JSON
/// files, for a package that depends on Petrel.
///
/// The generator itself is the Python program at the root of the Petrel checkout
/// (`run.py`, `generator/`). The plugin finds it next to its own source, prepares a private
/// virtual environment with the generator's dependencies in the plugin work directory, and
/// runs it from the package directory, so every path in the manifest is relative to the
/// package that invokes the command.
@main
struct PetrelLexgen: CommandPlugin {
    func performCommand(context: PluginContext, arguments: [String]) throws {
        var options = try Options(arguments)
        if options.showHelp {
            Diagnostics.remark(Options.usage)
            return
        }

        let packageDirectory = context.package.directoryURL
        let manifest = URL(fileURLWithPath: options.manifest, relativeTo: packageDirectory).standardizedFileURL
        guard FileManager.default.fileExists(atPath: manifest.path) else {
            throw LexgenError("no generation manifest at \(manifest.path)\n\n\(Options.usage)")
        }

        // Plugins/PetrelLexgen/plugin.swift -> the Petrel checkout this plugin ships in.
        let petrelRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let generator = petrelRoot.appendingPathComponent("run.py")
        guard FileManager.default.fileExists(atPath: generator.path) else {
            throw LexgenError("the Petrel generator is missing at \(generator.path)")
        }

        let python = try preparePython(
            petrelRoot: petrelRoot,
            workDirectory: context.pluginWorkDirectoryURL,
            basePython: options.python
        )

        try run(
            python.path,
            [generator.path, "--manifest", manifest.path, "--language", "swift"],
            in: packageDirectory,
            quiet: !options.verbose
        )
        options.verbose = false
        Diagnostics.remark("petrel-lexgen: generated Swift sources from \(manifest.lastPathComponent)")
    }

    /// The interpreter of a virtual environment that has the generator's dependencies.
    private func preparePython(petrelRoot: URL, workDirectory: URL, basePython: String?) throws -> URL {
        let environment = workDirectory.appendingPathComponent("lexgen-venv")
        let interpreter = environment.appendingPathComponent("bin/python")
        let stamp = environment.appendingPathComponent(".petrel-lexgen-ready")
        if FileManager.default.fileExists(atPath: stamp.path) {
            return interpreter
        }

        try? FileManager.default.removeItem(at: environment)
        if let basePython {
            try run(basePython, ["-m", "venv", environment.path], in: workDirectory, quiet: true)
        } else {
            try run("/usr/bin/env", ["python3", "-m", "venv", environment.path], in: workDirectory, quiet: true)
        }

        // The hash-pinned lock is built for the interpreter release tooling uses (3.12). On
        // any other Python the three dependencies are installed by name.
        let version = try capture(interpreter.path, ["-c", "import sys; print('%d.%d' % sys.version_info[:2])"])
        let install: [String] = if version == "3.12" {
            ["--require-hashes", "-r", petrelRoot.appendingPathComponent("generator/requirements-release.lock").path]
        } else {
            ["-r", petrelRoot.appendingPathComponent("generator/requirements.txt").path]
        }
        try run(
            interpreter.path,
            ["-m", "pip", "install", "--quiet", "--disable-pip-version-check", "--no-cache-dir"] + install,
            in: workDirectory,
            quiet: true
        )
        try Data().write(to: stamp)
        return interpreter
    }

    private func run(_ executable: String, _ arguments: [String], in directory: URL, quiet: Bool) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.currentDirectoryURL = directory
        var environment = ProcessInfo.processInfo.environment
        // The generator lives in a dependency checkout the plugin may not write to.
        environment["PYTHONDONTWRITEBYTECODE"] = "1"
        process.environment = environment
        let output = Pipe()
        process.standardOutput = output
        process.standardError = output
        try process.run()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let text = String(decoding: data, as: UTF8.self)
        guard process.terminationStatus == 0 else {
            throw LexgenError("\(URL(fileURLWithPath: executable).lastPathComponent) \(arguments.joined(separator: " ")) failed:\n\(text)")
        }
        if !quiet, !text.isEmpty {
            Diagnostics.remark(text)
        }
    }

    private func capture(_ executable: String, _ arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        let output = Pipe()
        process.standardOutput = output
        try process.run()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw LexgenError("\(executable) \(arguments.joined(separator: " ")) failed")
        }
        return String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct Options {
    static let usage = """
    usage: swift package --allow-writing-to-package-directory --allow-network-connections all:443 \\
               petrel-lexgen [--manifest <path>] [--python <path>] [--verbose]

      --manifest <path>   Generation manifest, relative to the package directory.
                          Default: lexgen.json
      --python <path>     Python 3 interpreter used to create the generator's virtual
                          environment. Default: python3 on PATH
      --verbose           Print the generator's output

    Network access is used once, to install the generator's Python dependencies
    (jinja2, aiofiles, orjson) into the plugin's work directory.
    """

    var manifest = "lexgen.json"
    var python: String?
    var verbose = false
    var showHelp = false

    init(_ arguments: [String]) throws {
        var remaining = arguments[...]
        while let argument = remaining.popFirst() {
            switch argument {
            case "--manifest":
                guard let value = remaining.popFirst() else { throw LexgenError("--manifest needs a path") }
                manifest = value
            case "--python":
                guard let value = remaining.popFirst() else { throw LexgenError("--python needs a path") }
                python = value
            case "--verbose":
                verbose = true
            case "--help", "-h":
                showHelp = true
            default:
                throw LexgenError("unknown argument '\(argument)'\n\n\(Options.usage)")
            }
        }
    }
}

private struct LexgenError: Error, CustomStringConvertible {
    let description: String

    init(_ description: String) {
        self.description = description
    }
}
