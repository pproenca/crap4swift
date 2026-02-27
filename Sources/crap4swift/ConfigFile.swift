import Foundation
import Yams

struct ConfigFile: Decodable {
    var paths: [String]?
    var xcresult: String?
    var profdata: String?
    var binary: String?
    var threshold: Double?
    var filter: [String]?
    var excludePath: [String]?
    var excludeGenerated: Bool?
    var json: Bool?

    enum CodingKeys: String, CodingKey {
        case paths
        case xcresult
        case profdata
        case binary
        case threshold
        case filter
        case excludePath = "exclude-path"
        case excludeGenerated = "exclude-generated"
        case json
    }

    /// Loads `.crap4swift.yml` from the given directory, returning `nil` if not found.
    static func load(from directory: String = ".") -> ConfigFile? {
        let url = URL(fileURLWithPath: directory)
            .appendingPathComponent(".crap4swift.yml")
        guard let data = try? Data(contentsOf: url) else {
            return nil
        }
        return try? YAMLDecoder().decode(ConfigFile.self, from: data)
    }
}
