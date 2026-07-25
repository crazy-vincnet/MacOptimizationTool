import Foundation
import Testing
@testable import MacOptimizationCore

/// 번역 사전 정합성 테스트.
/// 언어별 키 누락과 포맷 지정자 불일치는 컴파일로 잡히지 않으므로 여기서 고정한다.
@Suite("번역 사전 정합성")
struct TranslationTests {

    private static let languages: [AppLanguage] = [.korean, .english, .chinese, .japanese]

    @Test("모든 언어가 동일한 키 집합을 가진다", arguments: TranslationTests.languages)
    func allLanguagesShareTheSameKeySet(language: AppLanguage) throws {
        let base = Set(try #require(AdditionalTranslations.all[.korean]).keys)
        #expect(!base.isEmpty)

        let keys = Set(try #require(AdditionalTranslations.all[language]).keys)
        #expect(keys == base, "\(language.rawValue) 사전의 키 집합이 한국어와 다르다")
    }

    @Test("빈 번역 값이 없다", arguments: TranslationTests.languages)
    func noEmptyTranslations(language: AppLanguage) throws {
        for (key, value) in try #require(AdditionalTranslations.all[language]) {
            #expect(!value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                    "\(language.rawValue) / \(key) 값이 비어 있다")
        }
    }

    /// 포맷 지정자 개수가 언어별로 다르면 `String(format:)` 이 잘못된 인자를 읽는다.
    @Test("포맷 지정자 개수가 언어별로 같다", arguments: TranslationTests.languages)
    func formatSpecifierCountsMatch(language: AppLanguage) throws {
        let korean = try #require(AdditionalTranslations.all[.korean])
        let target = try #require(AdditionalTranslations.all[language])

        for (key, koValue) in korean {
            guard let value = target[key] else { continue }
            #expect(Self.formatSpecifierCount(value) == Self.formatSpecifierCount(koValue),
                    "\(language.rawValue) / \(key) 의 포맷 지정자 개수가 한국어와 다르다")
        }
    }

    @Test("없는 키는 키 문자열 자체로 폴백한다")
    func translateFallsBackToKeyWhenMissing() {
        #expect(LanguageManager.translate("no.such.key.exists") == "no.such.key.exists")
    }

    @Test("존재하는 키는 번역 값을 돌려준다")
    func translateReturnsValueForKnownKey() {
        let value = LanguageManager.translate("common.cancel")
        #expect(value != "common.cancel")
        #expect(!value.isEmpty)
    }

    @Test("시스템 언어 감지는 지원 언어를 반환한다")
    func systemLanguageDetectionReturnsSupportedLanguage() {
        let detected = AppLanguage.detectSystemLanguage()
        #expect(detected != .system)
        #expect(Self.languages.contains(detected))
    }

    /// 인자를 실제로 소비하는 변환 지정자만 센다.
    /// `%%` 는 리터럴 퍼센트이고, `100% 전수` 처럼 변환 문자가 뒤따르지 않는 `%` 도 인자를 소비하지 않는다.
    private static func formatSpecifierCount(_ text: String) -> Int {
        let flags = Set("-+ #0'")
        let lengthModifiers = Set("hlLqzjt")
        let conversions = Set("@dioux XEefgGaAcCsSpn")

        var count = 0
        var index = text.startIndex

        while index < text.endIndex {
            guard text[index] == "%" else {
                index = text.index(after: index)
                continue
            }

            var cursor = text.index(after: index)
            if cursor < text.endIndex, text[cursor] == "%" {
                index = text.index(after: cursor)   // 리터럴 퍼센트
                continue
            }

            while cursor < text.endIndex, flags.contains(text[cursor]) { cursor = text.index(after: cursor) }
            while cursor < text.endIndex, text[cursor].isNumber { cursor = text.index(after: cursor) }
            if cursor < text.endIndex, text[cursor] == "." {
                cursor = text.index(after: cursor)
                while cursor < text.endIndex, text[cursor].isNumber { cursor = text.index(after: cursor) }
            }
            while cursor < text.endIndex, lengthModifiers.contains(text[cursor]) { cursor = text.index(after: cursor) }

            if cursor < text.endIndex, conversions.contains(text[cursor]) {
                count += 1
                index = text.index(after: cursor)
            } else {
                index = text.index(after: index)    // 변환 문자가 없으면 지정자가 아니다
            }
        }
        return count
    }
}
