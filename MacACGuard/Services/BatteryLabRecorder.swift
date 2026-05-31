import Foundation

enum BatteryLabRecorderError: LocalizedError {
    case testAlreadyRunning

    var errorDescription: String? {
        switch self {
        case .testAlreadyRunning:
            "Test is already running."
        }
    }
}

@MainActor
final class BatteryLabRecorder: ObservableObject {
    @Published private(set) var activeTest: BatteryLabTest?
    @Published private(set) var samples: [BatteryLabSample] = []
    @Published private(set) var lastReport: BatteryLabReport?
    @Published private(set) var completedReports: [BatteryLabReport] = []
    @Published private(set) var lastCSVURL: URL?
    @Published private(set) var lastJSONURL: URL?
    @Published private(set) var lastComparison: BatteryLabComparison?
    @Published private(set) var isRecording = false
    @Published var lastError: String?

    private let monitor: any PowerSnapshotProviding
    private let reportGenerator: ReportGenerator
    private let csvExporter: CSVExporter
    private let jsonExporter: JSONExporter
    private let logger: EventLogger
    private var task: Task<Void, Never>?

    init(
        monitor: any PowerSnapshotProviding,
        reportGenerator: ReportGenerator = ReportGenerator(),
        csvExporter: CSVExporter = CSVExporter(),
        jsonExporter: JSONExporter = JSONExporter(),
        logger: EventLogger
    ) {
        self.monitor = monitor
        self.reportGenerator = reportGenerator
        self.csvExporter = csvExporter
        self.jsonExporter = jsonExporter
        self.logger = logger
    }

    func start(
        mode: BatteryLabMode,
        durationSeconds: TimeInterval?,
        gameProcessName: String?,
        selectedChargeLimit: Int?,
        selectedLowerLimitDelta: Int?,
        backendName: String,
        appModeActiveProvider: @escaping @MainActor () -> Bool,
        backendStatusProvider: @escaping @MainActor () -> ChargeBackendStatus
    ) throws {
        guard activeTest == nil, !isRecording else {
            lastError = BatteryLabRecorderError.testAlreadyRunning.localizedDescription
            throw BatteryLabRecorderError.testAlreadyRunning
        }

        let test = BatteryLabTest(
            mode: mode,
            plannedDurationSeconds: durationSeconds,
            gameProcessName: gameProcessName,
            selectedChargeLimit: selectedChargeLimit,
            selectedLowerLimitDelta: selectedLowerLimitDelta,
            backendName: backendName
        )

        activeTest = test
        samples = []
        lastReport = nil
        lastCSVURL = nil
        lastJSONURL = nil
        lastComparison = nil
        lastError = nil
        isRecording = true
        let durationDescription = durationSeconds.map { "\(Int($0))s" } ?? "infinite"
        logger.log(.batteryLabTestStarted, "Battery Lab test started: \(mode.rawValue), duration \(durationDescription).")

        task = Task { [weak self] in
            guard let self else { return }
            let startedAt = Date()

            while !Task.isCancelled {
                let now = Date()
                let elapsed = now.timeIntervalSince(startedAt)
                self.recordSample(
                    test: test,
                    elapsedSeconds: elapsed,
                    appModeActive: appModeActiveProvider(),
                    backendStatus: backendStatusProvider()
                )

                if let durationSeconds, elapsed >= durationSeconds {
                    self.finish(save: true)
                    return
                }
                
                do {
                    try await Task.sleep(for: .seconds(5))
                } catch {
                    return
                }
            }
        }
    }

    func stop(save: Bool = true) {
        task?.cancel()
        task = nil
        if save, isRecording {
            finish(save: true)
        } else {
            isRecording = false
            activeTest = nil
        }
    }

    func compareLatestGuardedToBaseline() -> BatteryLabComparison? {
        guard let guarded = latestReport(mode: .acGuardGameTest),
              let baseline = latestReport(mode: .batteryOnlyGameTest) ?? latestReport(mode: .normalChargingGameTest) else {
            lastError = "Need one BatteryOnlyGameTest or NormalChargingGameTest JSON and one ACGuardGameTest JSON to compare."
            return nil
        }
        let comparison = reportGenerator.compare(normal: baseline, guarded: guarded)
        lastComparison = comparison
        lastReport = reportGenerator.reportByComparing(guarded, baseline: baseline)
        lastError = nil
        return comparison
    }

    private func recordSample(
        test: BatteryLabTest,
        elapsedSeconds: TimeInterval,
        appModeActive: Bool,
        backendStatus: ChargeBackendStatus
    ) {
        let snapshot = monitor.snapshot()
        let sample = BatteryLabSample(
            test: test,
            snapshot: snapshot,
            elapsedSeconds: elapsedSeconds,
            appModeActive: appModeActive,
            backendStatus: backendStatus,
            actualGuardActive: GuardActivityEvaluator.isActualGuardActive(snapshot: snapshot, backendStatus: backendStatus),
            cpuLoad: nil,
            gpuLoad: nil,
            gameProcessCPU: nil,
            notes: snapshot.notes.joined(separator: "; ").nilIfEmpty
        )
        samples.append(sample)
    }

    private func finish(save: Bool) {
        guard let test = activeTest else { return }
        task?.cancel()
        task = nil
        isRecording = false
        activeTest = nil

        let report = reportGenerator.generate(samples: samples)
        lastReport = report
        completedReports.append(report)

        guard save else { return }

        do {
            let directory = AppPaths.batteryLabDirectory
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
            let basename = "\(test.mode.rawValue)-\(stamp)"
            let csvURL = directory.appendingPathComponent("\(basename).csv")
            let jsonURL = directory.appendingPathComponent("\(basename).json")
            try csvExporter.write(samples: samples, to: csvURL)
            try jsonExporter.write(bundle: BatteryLabExportBundle(test: test, samples: samples, report: report), to: jsonURL)
            lastCSVURL = csvURL
            lastJSONURL = jsonURL
            logger.log(.batteryLabTestFinished, "Battery Lab test finished: \(test.mode.rawValue). CSV: \(csvURL.path), JSON: \(jsonURL.path)")
        } catch {
            lastError = error.localizedDescription
            logger.log(.error, "Battery Lab export failed: \(error.localizedDescription)")
        }
    }

    private func latestReport(mode: BatteryLabMode) -> BatteryLabReport? {
        if let urls = try? FileManager.default.contentsOfDirectory(
            at: AppPaths.batteryLabDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) {
            let matching = urls
                .filter { $0.pathExtension == "json" && $0.lastPathComponent.hasPrefix(mode.rawValue) }
                .sorted { lhs, rhs in
                    modificationDate(lhs) > modificationDate(rhs)
                }

            for url in matching {
                if let report = decodeReport(from: url), report.testMode == mode {
                    return report
                }
            }
        }

        return completedReports.last(where: { $0.testMode == mode })
    }

    private func decodeReport(from url: URL) -> BatteryLabReport? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let bundle = try? decoder.decode(BatteryLabExportBundle.self, from: data) {
            return bundle.report
        }
        return try? decoder.decode(BatteryLabReport.self, from: data)
    }

    private func modificationDate(_ url: URL) -> Date {
        let values = try? url.resourceValues(forKeys: [.contentModificationDateKey])
        return values?.contentModificationDate ?? .distantPast
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
