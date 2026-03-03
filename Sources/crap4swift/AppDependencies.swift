import Dependencies
import Foundation

struct DataLoader {
    var load: @Sendable (URL) throws -> Data
}

extension DataLoader: DependencyKey {
    static var liveValue: Self {
        Self(load: { url in
            try Data(contentsOf: url)
        })
    }

    static var testValue: Self {
        liveValue
    }
}

extension DependencyValues {
    var dataLoader: DataLoader {
        get { self[DataLoader.self] }
        set { self[DataLoader.self] = newValue }
    }
}

struct ProcessResult: Sendable {
    let terminationStatus: Int32
    let output: Data
}

struct ProcessClient {
    var run: @Sendable (_ executableURL: URL, _ arguments: [String]) throws -> ProcessResult
}

extension ProcessClient: DependencyKey {
    static var liveValue: Self {
        Self(run: { executableURL, arguments in
            let process = Process()
            let pipe = Pipe()
            process.executableURL = executableURL
            process.arguments = arguments
            process.standardOutput = pipe
            process.standardError = pipe
            try process.run()
            let output = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            return ProcessResult(terminationStatus: process.terminationStatus, output: output)
        })
    }

    static var testValue: Self {
        liveValue
    }
}

extension DependencyValues {
    var processClient: ProcessClient {
        get { self[ProcessClient.self] }
        set { self[ProcessClient.self] = newValue }
    }
}
