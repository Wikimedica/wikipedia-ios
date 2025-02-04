import Foundation

struct Wikipedia: Codable {
    let languageCode: String
    let languageName: String
    let localName: String
}

struct WikipediaLanguageVariant: Codable {
    let languageCode: String
    let languageVariantCode: String
    let languageName: String
    let localName: String
}
