import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case ru
    case en

    static let defaultsKey = "MacACGuard.AppLanguage"

    var id: String { rawValue }

    static func persisted(in defaults: UserDefaults = .standard) -> AppLanguage {
        defaults.string(forKey: defaultsKey).flatMap(AppLanguage.init(rawValue:)) ?? .ru
    }
}

enum L10nKey: String, CaseIterable {
    case status
    case batteryLab
    case settings
    case monitoring
    case active
    case inactive
    case permissionRequired
    case grantPermission
    case adapterDisconnected
    case workFromAdapter
    case autoGuardHelper
    case battery
    case source
    case adapter
    case limit
    case range
    case mode
    case manualChargeLimit
    case delta
    case hysteresisRange
    case applySelectedLimit
    case disableLimit
    case refreshStatus
    case openBatteryLab
    case exportLogs
    case configuredCheckingPower
    case connectAdapter
    case adapterDisconnectedStopped
    case adapterConnectedEnableAgain
    case powerStabilizing
    case failedApplyLimit
    case reserveBelowSafe
    case adapterInsufficient
    case monitorOnly
    case physicalDisclaimer
    case permissionSetup
    case permissionExplanation
    case passwordNeverStored
    case macOSHandlesAuthorization
    case helperPackagingUnavailable
    case useTerminalSetupInstead
    case copySetupCommands
    case terminalInstructions
    case setupCommandsCopied
    case diagnostics
    case language
    case russian
    case english
    case readBackend
    case writeBackend
    case authorizationState
    case authorizationUnknown
    case authorizationNotRequired
    case authorizationRequired
    case authorizationAuthorized
    case authorizationDenied
    case helperMissing
    case helperNeedsInstall
    case helperOutdated
    case authorizationFailed
    case directBatt
    case privilegedHelper
    case manualSetupRequired
    case monitorOnlyBackend
    case battPath
    case daemonAvailable
    case allowNonRoot
    case actualUpper
    case actualLower
    case actualDelta
    case actualGuardActive
    case battDisabled
    case manualSelectedLimit
    case autoSelectedLimit
    case requestedMode
    case lastAutoLimit
    case lastAutoDelta
    case configuredPending
    case userRequestedAutoGuard
    case lastStopReason
    case batteryCurrent
    case batteryPower
    case adapterLoadAssessment
    case stable
    case sustainedBatteryDischarge
    case rawBattStatus
    case lastWriteError
    case lastBattResponse
    case appSupportDirectory
    case batteryLabDirectory
    case available
    case yes
    case no
    case unknown
    case safety
    case noSIP
    case noSMC
    case noPassword
    case monitorFallback
    case backendSetupNote
    case test
    case duration
    case customDuration
    case minutes
    case gameProcessOptional
    case startTest
    case stopTest
    case liveMetrics
    case samples
    case elapsed
    case current
    case compareTests
    case exportCSVJSON
    case comparison
    case lessBatteryParticipation
    case versus
    case observedRange
    case throughput
    case movement
    case targetResult
    case energyIn
    case energyOut
    case reduction
    case unavailable
    case summary
    case startCharge
    case finalCharge
    case percentDelta
    case participationIndex
    case quality
    case uiModeActive
    case actualBackendLimit
    case maxBatteryTemp
    case avgBatteryPower
    case avgCurrent
    case batteryOnly
    case normalCharging
    case acGuardMode
    case clean
    case informative
    case dirty
    case charging
    case charged
    case notCharging
    case batterySource
    case adapterSource
    case openMacACGuard
    case quitMacACGuard
    case modeAuto
    case modeManual
    case modeNone
    case stoppedAdapterDisconnected
}

struct L10n {
    static func text(_ key: L10nKey, _ language: AppLanguage) -> String {
        translations[language]?[key] ?? "missing_key.\(key.rawValue)"
    }

    static func format(_ key: L10nKey, _ language: AppLanguage, _ arguments: CVarArg...) -> String {
        String(format: text(key, language), locale: locale(for: language), arguments: arguments)
    }

    private static func locale(for language: AppLanguage) -> Locale {
        Locale(identifier: language == .ru ? "ru_RU" : "en_US")
    }

    private static let translations: [AppLanguage: [L10nKey: String]] = [
        .ru: [
            .status: "Статус", .batteryLab: "Battery Lab", .settings: "Настройки",
            .monitoring: "Мониторинг", .active: "Активно", .inactive: "Неактивно",
            .permissionRequired: "Требуется разрешение", .grantPermission: "Дать разрешение", .adapterDisconnected: "Адаптер не подключён",
            .workFromAdapter: "Работа от сети", .autoGuardHelper: "Автоматически подберёт лимит рядом с текущим зарядом.",
            .battery: "Аккумулятор", .source: "Источник", .adapter: "Адаптер", .limit: "Лимит",
            .range: "Диапазон", .mode: "Режим", .manualChargeLimit: "Ручной лимит заряда",
            .delta: "Дельта", .hysteresisRange: "Диапазон гистерезиса",
            .applySelectedLimit: "Применить выбранный лимит", .disableLimit: "Отключить лимит",
            .refreshStatus: "Обновить статус", .openBatteryLab: "Открыть Battery Lab", .exportLogs: "Экспорт логов",
            .configuredCheckingPower: "Режим настроен. Проверяем состояние питания…",
            .connectAdapter: "Подключите адаптер питания.", .adapterDisconnectedStopped: "Адаптер отключён. Режим от сети остановлен.",
            .adapterConnectedEnableAgain: "Адаптер подключён. Можно снова включить режим от сети.",
            .powerStabilizing: "Питание стабилизируется…",
            .failedApplyLimit: "Не удалось применить лимит.", .reserveBelowSafe: "Резерв аккумулятора ниже безопасного уровня.",
            .adapterInsufficient: "Адаптер не покрывает текущую нагрузку. Аккумулятор устойчиво участвует в питании.",
            .monitorOnly: "На этом Mac доступен только мониторинг. Безопасное управление лимитом недоступно.",
            .physicalDisclaimer: "Mac AC Guard не отключает аккумулятор физически. Он задаёт лимит зарядки и отслеживает участие аккумулятора.",
            .permissionSetup: "Настройка разрешений", .permissionExplanation: "Mac AC Guard должен получить разрешение на управление лимитами batt.",
            .passwordNeverStored: "Приложение не хранит ваш пароль.", .macOSHandlesAuthorization: "Авторизация выполняется средствами macOS.",
            .helperPackagingUnavailable: "Signed helper ещё не упакован в этой Swift Package сборке. Пока используйте безопасную ручную настройку.",
            .useTerminalSetupInstead: "Ручная настройка", .copySetupCommands: "Скопировать команды настройки",
            .terminalInstructions: "Инструкция для Terminal", .setupCommandsCopied: "Команды скопированы. Выполните их в Terminal и обновите статус.",
            .diagnostics: "Диагностика", .language: "Язык", .russian: "Русский", .english: "English",
            .readBackend: "Backend чтения", .writeBackend: "Backend записи", .authorizationState: "Состояние авторизации",
            .authorizationUnknown: "Неизвестно", .authorizationNotRequired: "Не требуется", .authorizationRequired: "Требуется разрешение",
            .authorizationAuthorized: "Разрешено", .authorizationDenied: "Отказано", .helperMissing: "Helper отсутствует",
            .helperNeedsInstall: "Helper требует установки", .helperOutdated: "Helper устарел", .authorizationFailed: "Ошибка",
            .directBatt: "прямой batt", .privilegedHelper: "privileged helper", .manualSetupRequired: "требуется ручная настройка",
            .monitorOnlyBackend: "только мониторинг", .battPath: "Путь batt",
            .daemonAvailable: "Доступность batt daemon", .allowNonRoot: "Доступ non-root users", .actualUpper: "Actual upper",
            .actualLower: "Actual lower", .actualDelta: "Actual delta", .actualGuardActive: "actualGuardActive",
            .battDisabled: "battDisabled", .manualSelectedLimit: "Выбранный ручной лимит", .autoSelectedLimit: "Автоматически выбранный лимит",
            .requestedMode: "Запрошенный режим", .lastAutoLimit: "Последний Auto Guard лимит", .lastAutoDelta: "Последняя Auto Guard дельта",
            .configuredPending: "configuredPending", .userRequestedAutoGuard: "Auto Guard запрошен пользователем", .lastStopReason: "Последняя причина остановки", .batteryCurrent: "Ток аккумулятора",
            .batteryPower: "Мощность аккумулятора", .adapterLoadAssessment: "Оценка нагрузки адаптера", .stable: "Стабильно",
            .sustainedBatteryDischarge: "Устойчивый разряд аккумулятора", .rawBattStatus: "Сырой статус batt", .lastWriteError: "Последняя ошибка записи",
            .lastBattResponse: "Последний ответ batt", .appSupportDirectory: "Папка данных приложения", .batteryLabDirectory: "Папка Battery Lab",
            .available: "Доступно", .yes: "Да", .no: "Нет", .unknown: "Неизвестно", .safety: "Безопасность",
            .noSIP: "Отключение SIP не требуется.", .noSMC: "SMC и firmware не изменяются.", .noPassword: "Пароли не хранятся, самодельных sudo-окон нет.",
            .monitorFallback: "Если batt недоступен, приложение остаётся в режиме мониторинга.",
            .backendSetupNote: "Запись выполняется только разрешёнными операциями batt. Если нужны права администратора, приложение покажет безопасную ручную настройку.",
            .test: "Тест", .duration: "Длительность", .customDuration: "Своя длительность", .minutes: "%d мин",
            .gameProcessOptional: "Имя процесса игры, необязательно", .startTest: "Начать тест", .stopTest: "Остановить тест",
            .liveMetrics: "Текущие метрики", .samples: "Замеры", .elapsed: "Прошло", .current: "Ток",
            .compareTests: "Сравнить тесты", .exportCSVJSON: "Экспорт CSV/JSON", .comparison: "Сравнение",
            .lessBatteryParticipation: "меньше участия аккумулятора", .versus: "против", .observedRange: "Наблюдаемый диапазон",
            .throughput: "Участие аккумулятора", .movement: "Изменение заряда", .targetResult: "Результат лимита",
            .energyIn: "Энергия в аккумулятор", .energyOut: "Энергия из аккумулятора", .reduction: "Снижение",
            .unavailable: "Недоступно", .summary: "Сводка", .startCharge: "Начальный заряд", .finalCharge: "Финальный заряд",
            .percentDelta: "Изменение процента", .participationIndex: "Индекс участия аккумулятора", .quality: "Качество",
            .uiModeActive: "Режим UI активен", .actualBackendLimit: "Фактический лимит backend", .maxBatteryTemp: "Макс. температура аккумулятора",
            .avgBatteryPower: "Средняя мощность аккумулятора", .avgCurrent: "Средний ток", .batteryOnly: "Только от батареи",
            .normalCharging: "Обычная зарядка", .acGuardMode: "Режим AC Guard", .clean: "Чистый", .informative: "Информативный",
            .dirty: "Грязный", .charging: "Заряжается", .charged: "Заряжен", .notCharging: "Не заряжается",
            .batterySource: "Батарея", .adapterSource: "Адаптер", .openMacACGuard: "Открыть Mac AC Guard",
            .quitMacACGuard: "Закрыть Mac AC Guard", .modeAuto: "Auto Guard", .modeManual: "Ручной", .modeNone: "Нет",
            .stoppedAdapterDisconnected: "Адаптер отключён"
        ],
        .en: [
            .status: "Status", .batteryLab: "Battery Lab", .settings: "Settings",
            .monitoring: "Monitoring", .active: "Active", .inactive: "Inactive",
            .permissionRequired: "Permission required", .grantPermission: "Grant permission", .adapterDisconnected: "Adapter disconnected",
            .workFromAdapter: "Work from power adapter", .autoGuardHelper: "Automatically chooses a limit near the current battery level.",
            .battery: "Battery", .source: "Source", .adapter: "Adapter", .limit: "Limit",
            .range: "Range", .mode: "Mode", .manualChargeLimit: "Manual charge limit",
            .delta: "Delta", .hysteresisRange: "Hysteresis range",
            .applySelectedLimit: "Apply selected limit", .disableLimit: "Disable limit",
            .refreshStatus: "Refresh status", .openBatteryLab: "Open Battery Lab", .exportLogs: "Export logs",
            .configuredCheckingPower: "Mode configured. Checking power state…",
            .connectAdapter: "Connect the power adapter.", .adapterDisconnectedStopped: "Power adapter disconnected. AC Guard stopped.",
            .adapterConnectedEnableAgain: "Adapter connected. You can enable AC Guard again.",
            .powerStabilizing: "Power state stabilizing…",
            .failedApplyLimit: "Failed to apply limit.", .reserveBelowSafe: "Battery reserve is below the safe level.",
            .adapterInsufficient: "Adapter may not cover the current load. Battery is steadily participating in power delivery.",
            .monitorOnly: "Only monitoring is available on this Mac. Safe charge-limit control is unavailable.",
            .physicalDisclaimer: "Mac AC Guard does not physically disconnect the battery. It sets a charging limit and monitors battery participation.",
            .permissionSetup: "Permission setup", .permissionExplanation: "Mac AC Guard needs permission to manage batt charge limits.",
            .passwordNeverStored: "The app never stores your password.", .macOSHandlesAuthorization: "macOS handles authorization.",
            .helperPackagingUnavailable: "The signed helper is not packaged in this Swift Package build yet. Use the safe manual setup for now.",
            .useTerminalSetupInstead: "Manual setup", .copySetupCommands: "Copy setup commands",
            .terminalInstructions: "Terminal instructions", .setupCommandsCopied: "Commands copied. Run them in Terminal and refresh status.",
            .diagnostics: "Diagnostics", .language: "Language", .russian: "Russian", .english: "English",
            .readBackend: "Read backend", .writeBackend: "Write backend", .authorizationState: "Authorization state",
            .authorizationUnknown: "Unknown", .authorizationNotRequired: "Not required", .authorizationRequired: "Permission required",
            .authorizationAuthorized: "Authorized", .authorizationDenied: "Denied", .helperMissing: "Helper missing",
            .helperNeedsInstall: "Helper needs install", .helperOutdated: "Helper outdated", .authorizationFailed: "Failed",
            .directBatt: "direct batt", .privilegedHelper: "privileged helper", .manualSetupRequired: "manual setup required",
            .monitorOnlyBackend: "monitor only", .battPath: "batt path",
            .daemonAvailable: "batt daemon availability", .allowNonRoot: "Allow non-root users", .actualUpper: "Actual upper",
            .actualLower: "Actual lower", .actualDelta: "Actual delta", .actualGuardActive: "actualGuardActive",
            .battDisabled: "battDisabled", .manualSelectedLimit: "Manual selected limit", .autoSelectedLimit: "Auto selected limit",
            .requestedMode: "Requested mode", .lastAutoLimit: "Last Auto Guard limit", .lastAutoDelta: "Last Auto Guard delta",
            .configuredPending: "configuredPending", .userRequestedAutoGuard: "Auto Guard requested by user", .lastStopReason: "Last stop reason", .batteryCurrent: "Battery current",
            .batteryPower: "Battery power", .adapterLoadAssessment: "Adapter load assessment", .stable: "Stable",
            .sustainedBatteryDischarge: "Sustained battery discharge", .rawBattStatus: "Raw batt status", .lastWriteError: "Last write error",
            .lastBattResponse: "Last batt response", .appSupportDirectory: "App support directory", .batteryLabDirectory: "Battery Lab directory",
            .available: "Available", .yes: "Yes", .no: "No", .unknown: "Unknown", .safety: "Safety",
            .noSIP: "No SIP disabling.", .noSMC: "No SMC or firmware mutation.", .noPassword: "No password storage or custom sudo prompt.",
            .monitorFallback: "If batt is unavailable, the app stays in monitor-only mode.",
            .backendSetupNote: "Writes use allowlisted batt operations only. If administrator rights are required, the app shows the safe manual setup.",
            .test: "Test", .duration: "Duration", .customDuration: "Custom duration", .minutes: "%d min",
            .gameProcessOptional: "Game process name, optional", .startTest: "Start test", .stopTest: "Stop test",
            .liveMetrics: "Live metrics", .samples: "Samples", .elapsed: "Elapsed", .current: "Current",
            .compareTests: "Compare tests", .exportCSVJSON: "Export CSV/JSON", .comparison: "Comparison",
            .lessBatteryParticipation: "less battery participation", .versus: "vs", .observedRange: "Observed range",
            .throughput: "Battery participation", .movement: "Charge movement", .targetResult: "Target result",
            .energyIn: "Energy in", .energyOut: "Energy out", .reduction: "Reduction",
            .unavailable: "Unavailable", .summary: "Summary", .startCharge: "Start charge", .finalCharge: "Final charge",
            .percentDelta: "Percent delta", .participationIndex: "Battery Participation Index", .quality: "Quality",
            .uiModeActive: "UI mode active", .actualBackendLimit: "Actual backend limit", .maxBatteryTemp: "Max battery temp",
            .avgBatteryPower: "Avg battery power", .avgCurrent: "Avg current", .batteryOnly: "Battery only",
            .normalCharging: "Normal charging", .acGuardMode: "AC Guard mode", .clean: "Clean", .informative: "Informative",
            .dirty: "Dirty", .charging: "Charging", .charged: "Charged", .notCharging: "Not charging",
            .batterySource: "Battery", .adapterSource: "Adapter", .openMacACGuard: "Open Mac AC Guard",
            .quitMacACGuard: "Quit Mac AC Guard", .modeAuto: "Auto Guard", .modeManual: "Manual", .modeNone: "None",
            .stoppedAdapterDisconnected: "Adapter disconnected"
        ]
    ]
}
