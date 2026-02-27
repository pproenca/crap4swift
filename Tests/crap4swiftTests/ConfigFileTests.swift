import Foundation
import XCTest
import Yams
@testable import crap4swift

final class ConfigFileTests: XCTestCase {

    // MARK: - YAML Parsing

    func testLoadsFullConfig() throws {
        let yaml = """
        paths:
          - Sources
          - Modules/Core
        xcresult: .build/tests.xcresult
        threshold: 30
        filter:
          - viewDidLoad
        exclude-path:
          - /GeneratedSources/
        exclude-generated: true
        json: true
        """
        let config = try decode(yaml)

        XCTAssertEqual(config.paths, ["Sources", "Modules/Core"])
        XCTAssertEqual(config.xcresult, ".build/tests.xcresult")
        XCTAssertEqual(config.threshold, 30)
        XCTAssertEqual(config.filter, ["viewDidLoad"])
        XCTAssertEqual(config.excludePath, ["/GeneratedSources/"])
        XCTAssertEqual(config.excludeGenerated, true)
        XCTAssertEqual(config.json, true)
    }

    func testLoadsMinimalConfig() throws {
        let yaml = """
        paths:
          - Sources
        """
        let config = try decode(yaml)

        XCTAssertEqual(config.paths, ["Sources"])
        XCTAssertNil(config.xcresult)
        XCTAssertNil(config.profdata)
        XCTAssertNil(config.binary)
        XCTAssertNil(config.threshold)
        XCTAssertNil(config.filter)
        XCTAssertNil(config.excludePath)
        XCTAssertNil(config.excludeGenerated)
        XCTAssertNil(config.json)
    }

    func testLoadsLLVMCoverageConfig() throws {
        let yaml = """
        profdata: default.profdata
        binary: .build/debug/MyApp
        """
        let config = try decode(yaml)

        XCTAssertEqual(config.profdata, "default.profdata")
        XCTAssertEqual(config.binary, ".build/debug/MyApp")
        XCTAssertNil(config.xcresult)
    }

    func testLoadReturnsNilForMissingFile() {
        let config = ConfigFile.load(from: "/nonexistent/path")
        XCTAssertNil(config)
    }

    func testLoadReturnsNilForMalformedYAML() throws {
        let tempDir = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let configURL = tempDir.appendingPathComponent(".crap4swift.yml")
        try "{{{{not yaml".write(to: configURL, atomically: true, encoding: .utf8)

        let config = ConfigFile.load(from: tempDir.path)
        XCTAssertNil(config)
    }

    func testLoadFromDirectory() throws {
        let tempDir = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let yaml = "paths:\n  - Sources\nthreshold: 25\n"
        let configURL = tempDir.appendingPathComponent(".crap4swift.yml")
        try yaml.write(to: configURL, atomically: true, encoding: .utf8)

        let config = ConfigFile.load(from: tempDir.path)
        XCTAssertNotNil(config)
        XCTAssertEqual(config?.paths, ["Sources"])
        XCTAssertEqual(config?.threshold, 25)
    }

    // MARK: - Config Merging (applyConfig)

    func testConfigFillsEmptyCommand() throws {
        var command = try parseCommand([])
        let config = try decode("""
        paths:
          - Sources
        threshold: 30
        json: true
        exclude-generated: true
        """)

        command.applyConfig(config)

        XCTAssertEqual(command.paths, ["Sources"])
        XCTAssertEqual(command.threshold, 30)
        XCTAssertEqual(command.json, true)
        XCTAssertEqual(command.excludeGenerated, true)
    }

    func testCLIArgsTakePrecedenceOverConfig() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("crap4swift-cfg-test-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        var command = try parseCommand([tempDir.path, "--threshold", "50", "--json"])
        let config = try decode("""
        paths:
          - OtherDir
        threshold: 10
        json: false
        """)

        command.applyConfig(config)

        // CLI args win
        XCTAssertEqual(command.paths, [tempDir.path])
        XCTAssertEqual(command.threshold, 50)
        XCTAssertEqual(command.json, true)
    }

    func testConfigExcludePathsAppendToCliExcludePaths() throws {
        var command = try parseCommand(["--exclude-path", "/Vendor/"])
        let config = try decode("""
        exclude-path:
          - /GeneratedSources/
        """)

        command.applyConfig(config)

        XCTAssertEqual(command.excludePath, ["/Vendor/", "/GeneratedSources/"])
    }

    func testCLIFilterTakesPrecedenceOverConfig() throws {
        var command = try parseCommand(["--filter", "viewDidLoad"])
        let config = try decode("""
        filter:
          - init
          - deinit
        """)

        command.applyConfig(config)

        XCTAssertEqual(command.filter, ["viewDidLoad"])
    }

    func testConfigFilterAppliedWhenCLIFilterEmpty() throws {
        var command = try parseCommand([])
        let config = try decode("""
        filter:
          - setup
        """)

        command.applyConfig(config)

        XCTAssertEqual(command.filter, ["setup"])
    }

    func testCLIExcludeGeneratedTakesPrecedenceOverConfig() throws {
        var command = try parseCommand(["--exclude-generated"])
        let config = try decode("""
        exclude-generated: false
        """)

        command.applyConfig(config)

        XCTAssertTrue(command.excludeGenerated)
    }

    func testConfigCoverageIgnoredWhenCLIProvidesCoverage() throws {
        let tempDir = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let xcresultPath = tempDir.appendingPathComponent("tests.xcresult")
        try FileManager.default.createDirectory(at: xcresultPath, withIntermediateDirectories: true)

        var command = try parseCommand(["--xcresult", xcresultPath.path])
        let config = try decode("""
        profdata: other.profdata
        binary: other-binary
        """)

        command.applyConfig(config)

        // CLI xcresult wins; config llvm-cov ignored
        XCTAssertEqual(command.xcresult, xcresultPath.path)
        XCTAssertNil(command.profdata)
        XCTAssertNil(command.binary)
    }

    // MARK: - Helpers

    private func decode(_ yaml: String) throws -> ConfigFile {
        let data = Data(yaml.utf8)
        return try YAMLDecoder().decode(ConfigFile.self, from: data)
    }

    private func parseCommand(_ arguments: [String]) throws -> Crap4Swift {
        let parsed = try Crap4Swift.parseAsRoot(arguments)
        guard let command = parsed as? Crap4Swift else {
            throw ConfigTestError.unexpectedCommandType
        }
        return command
    }

    private func makeTemporaryDirectory() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("crap4swift-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        return tempDir
    }
}

private enum ConfigTestError: Error {
    case unexpectedCommandType
}
