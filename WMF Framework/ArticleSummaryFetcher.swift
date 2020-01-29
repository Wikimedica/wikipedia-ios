import Foundation

@objc(WMFArticleSummaryImage)
class ArticleSummaryImage: NSObject, Codable {
    let source: String
    let width: Int
    let height: Int
    var url: URL? {
        return URL(string: source)
    }
}

@objc(WMFArticleSummaryURLs)
class ArticleSummaryURLs: NSObject, Codable {
    let page: String?
    let revisions: String?
    let edit: String?
    let talk: String?
}

@objc(WMFArticleSummaryContentURLs)
class ArticleSummaryContentURLs: NSObject, Codable {
    let desktop: ArticleSummaryURLs?
    let mobile: ArticleSummaryURLs?
}

@objc(WMFArticleSummaryCoordinates)
class ArticleSummaryCoordinates: NSObject, Codable {
    @objc let lat: Double
    @objc let lon: Double
}

@objc(WMFArticleSummary)
public class ArticleSummary: NSObject, Codable {
    @objc public class Namespace: NSObject, Codable {
        let id: Int?
        let text: String?

        @objc public var number: NSNumber? {
            guard let id = id else {
                return nil
            }
            return NSNumber(value: id)
        }
    }
    let id: Int64?
    let revision: String?
    let timestamp: String?
    let index: Int?
    @objc let namespace: Namespace?
    let title: String?
    let displayTitle: String?
    let articleDescription: String?
    let extract: String?
    let extractHTML: String?
    let thumbnail: ArticleSummaryImage?
    let original: ArticleSummaryImage?
    @objc let coordinates: ArticleSummaryCoordinates?
    
    enum CodingKeys: String, CodingKey {
        case id = "pageid"
        case revision
        case index
        case namespace
        case title
        case timestamp
        case displayTitle = "displaytitle"
        case articleDescription = "description"
        case extract
        case extractHTML = "extract_html"
        case thumbnail
        case original = "originalimage"
        case coordinates
        case contentURLs = "content_urls"
    }
    
    let contentURLs: ArticleSummaryContentURLs
    
    var articleURL: URL? {
        guard let urlString = contentURLs.desktop?.page else {
            return nil
        }
        return URL(string: urlString)
    }
    
    var key: String? {
        return articleURL?.wmf_databaseKey // don't use contentURLs.desktop?.page directly as it needs to be standardized
    }
}


@objc(WMFArticleSummaryFetcher)
public class ArticleSummaryFetcher: Fetcher {
    @discardableResult public func fetchArticleSummaryResponsesForArticles(withKeys articleKeys: [String], priority: Float = URLSessionTask.defaultPriority, completion: @escaping ([String: ArticleSummary]) -> Void) -> [String] {
        
        var cancellationKeys: [String] = []
        articleKeys.asyncMapToDictionary(block: { (articleKey, asyncMapCompletion) in
            let key = fetchSummaryForArticle(with: articleKey, priority: priority, completion: { (result, response) in
                switch result {
                case .success(let summary):
                    asyncMapCompletion(articleKey, summary)
                case .failure:
                    asyncMapCompletion(articleKey, nil)
                }
            })
            if let key = key {
                cancellationKeys.append(key)
            }
        }, completion: completion)
        
        return cancellationKeys
    }
    
    @discardableResult public func fetchSummaryForArticle(with articleKey: String, priority: Float = URLSessionTask.defaultPriority, completion: @escaping (Result<ArticleSummary, Error>, URLResponse?) -> Swift.Void) -> CancellationKey? {
        guard
            let articleURL = URL(string: articleKey),
            let title = articleURL.percentEncodedPageTitleForPathComponents
        else {
            completion(.failure(Fetcher.invalidParametersError), nil)
            return nil
        }
        
        let pathComponents = ["page", "summary", title]
        let key = performMobileAppsServicesGET(for: articleURL, pathComponents: pathComponents, priority: priority, cancellationKey: articleKey, completionHandler: completion)
        return key
    }
}

