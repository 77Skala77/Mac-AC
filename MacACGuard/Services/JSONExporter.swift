import Foundation

struct JSONExporter {
    private var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    func write(bundle: BatteryLabExportBundle, to url: URL) throws {
        let data = try encoder.encode(bundle)
        try data.write(to: url, options: .atomic)
    }

    func write(report: BatteryLabReport, to url: URL) throws {
        let data = try encoder.encode(report)
        try data.write(to: url, options: .atomic)
    }
}
