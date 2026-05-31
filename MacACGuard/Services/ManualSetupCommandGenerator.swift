import Foundation

struct ManualSetupCommandGenerator {
    func directCommands(limit: Int, delta: Int) throws -> [String] {
        try validate(limit: limit, delta: delta)
        return [
            "batt limit \(limit)",
            "batt lower-limit-delta \(delta)",
            "batt adapter enable",
            "batt status"
        ]
    }

    func sudoCommands(limit: Int, delta: Int) throws -> [String] {
        try directCommands(limit: limit, delta: delta).map { command in
            command == "batt status" ? command : "sudo \(command)"
        }
    }

    func instructions(limit: Int, delta: Int) throws -> String {
        let direct = try directCommands(limit: limit, delta: delta).joined(separator: "\n")
        let sudo = try sudoCommands(limit: limit, delta: delta).joined(separator: "\n")
        return """
        # Preferred: use batt directly when daemon permissions allow it
        \(direct)

        # If batt reports that administrator authorization is required
        \(sudo)
        """
    }

    private func validate(limit: Int, delta: Int) throws {
        guard (5...100).contains(limit) else {
            throw ChargeLimitError.invalidLimit(limit)
        }

        guard [1, 2, 5, 10].contains(delta) else {
            throw ChargeLimitError.invalidDelta(delta)
        }
    }
}
