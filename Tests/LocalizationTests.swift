import XCTest
@testable import MacACGuard

final class LocalizationTests: XCTestCase {
    func testEveryLocalizationKeyHasRussianAndEnglishValue() {
        for key in L10nKey.allCases {
            XCTAssertFalse(L10n.text(key, .ru).hasPrefix("missing_key."), "Missing RU value for \(key)")
            XCTAssertFalse(L10n.text(key, .en).hasPrefix("missing_key."), "Missing EN value for \(key)")
        }
    }

    func testMainStatusLabelsAreLocalized() {
        XCTAssertEqual(L10n.text(.workFromAdapter, .ru), "Работа от сети")
        XCTAssertEqual(L10n.text(.workFromAdapter, .en), "Work from power adapter")
        XCTAssertEqual(L10n.text(.adapterDisconnectedStopped, .ru), "Адаптер отключён. Режим от сети остановлен.")
        XCTAssertEqual(L10n.text(.adapterDisconnectedStopped, .en), "Power adapter disconnected. AC Guard stopped.")
        XCTAssertEqual(L10n.text(.configuredCheckingPower, .ru), "Режим настроен. Проверяем состояние питания…")
        XCTAssertEqual(L10n.text(.configuredCheckingPower, .en), "Mode configured. Checking power state…")
        XCTAssertEqual(L10n.text(.adapterConnectedEnableAgain, .ru), "Адаптер подключён. Можно снова включить режим от сети.")
        XCTAssertEqual(L10n.text(.adapterConnectedEnableAgain, .en), "Adapter connected. You can enable AC Guard again.")
        XCTAssertEqual(L10n.text(.powerStabilizing, .ru), "Питание стабилизируется…")
        XCTAssertEqual(L10n.text(.powerStabilizing, .en), "Power state stabilizing…")
        XCTAssertEqual(L10n.text(.adapterInsufficient, .ru), "Адаптер не покрывает текущую нагрузку. Аккумулятор устойчиво участвует в питании.")
        XCTAssertEqual(L10n.text(.adapterInsufficient, .en), "Adapter may not cover the current load. Battery is steadily participating in power delivery.")
    }

    func testLanguageSelectionPersists() {
        let suiteName = "LocalizationTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set(AppLanguage.en.rawValue, forKey: AppLanguage.defaultsKey)
        XCTAssertEqual(AppLanguage.persisted(in: defaults), .en)
        defaults.set(AppLanguage.ru.rawValue, forKey: AppLanguage.defaultsKey)
        XCTAssertEqual(AppLanguage.persisted(in: defaults), .ru)
    }

    func testKeyLabelsDoNotMixLanguages() {
        XCTAssertFalse(L10n.text(.battery, .ru).contains("Battery"))
        XCTAssertFalse(L10n.text(.battery, .en).contains("Аккумулятор"))
        XCTAssertFalse(L10n.text(.permissionRequired, .ru).contains("Permission"))
        XCTAssertFalse(L10n.text(.permissionRequired, .en).contains("разрешение"))
    }
}
