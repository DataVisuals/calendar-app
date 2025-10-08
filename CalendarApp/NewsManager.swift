import Foundation
import Combine

struct NewsArticle: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let source: String
    let url: URL
    let pubDate: Date?
}

class NewsManager: ObservableObject {
    @Published var headlines: [NewsArticle] = []
    @Published var isLoading = false

    private let rssSources = [
        ("BBC", "https://feeds.bbci.co.uk/news/rss.xml"),
        ("Reuters", "https://www.reutersagency.com/feed/?taxonomy=best-topics&post_type=best"),
        ("CNN", "http://rss.cnn.com/rss/cnn_topstories.rss"),
        ("The Guardian", "https://www.theguardian.com/world/rss"),
        ("NPR", "https://feeds.npr.org/1001/rss.xml")
    ]

    func fetchHeadlines() {
        isLoading = true
        headlines = []

        let group = DispatchGroup()
        var allArticles: [NewsArticle] = []
        let articlesLock = NSLock()

        for (source, urlString) in rssSources {
            group.enter()

            guard let url = URL(string: urlString) else {
                group.leave()
                continue
            }

            let task = URLSession.shared.dataTask(with: url) { data, response, error in
                defer { group.leave() }

                guard let data = data, error == nil else {
                    print("Error fetching \(source): \(error?.localizedDescription ?? "Unknown error")")
                    return
                }

                let parser = RSSParser(source: source)
                if parser.parse(data: data) {
                    articlesLock.lock()
                    allArticles.append(contentsOf: parser.articles)
                    articlesLock.unlock()
                }
            }
            task.resume()
        }

        group.notify(queue: .main) { [weak self] in
            // Sort by publication date (most recent first) and take top 5
            let sortedArticles = allArticles
                .sorted { ($0.pubDate ?? Date.distantPast) > ($1.pubDate ?? Date.distantPast) }
                .prefix(5)

            self?.headlines = Array(sortedArticles)
            self?.isLoading = false
        }
    }
}

class RSSParser: NSObject, XMLParserDelegate {
    let source: String
    var articles: [NewsArticle] = []

    private var currentElement = ""
    private var currentTitle = ""
    private var currentLink = ""
    private var currentPubDate = ""
    private var insideItem = false

    init(source: String) {
        self.source = source
    }

    func parse(data: Data) -> Bool {
        let parser = XMLParser(data: data)
        parser.delegate = self
        return parser.parse()
    }

    // XMLParserDelegate methods
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentElement = elementName

        if elementName == "item" {
            insideItem = true
            currentTitle = ""
            currentLink = ""
            currentPubDate = ""
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, insideItem else { return }

        switch currentElement {
        case "title":
            currentTitle += trimmed
        case "link":
            currentLink += trimmed
        case "pubDate":
            currentPubDate += trimmed
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "item" {
            insideItem = false

            // Create article if we have required data
            if !currentTitle.isEmpty, !currentLink.isEmpty,
               let url = URL(string: currentLink) {
                let pubDate = parseDate(currentPubDate)
                let article = NewsArticle(
                    title: currentTitle,
                    source: source,
                    url: url,
                    pubDate: pubDate
                )
                articles.append(article)
            }
        }
    }

    private func parseDate(_ dateString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")

        // Try RFC 822 format (most common for RSS)
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        if let date = formatter.date(from: dateString) {
            return date
        }

        // Try ISO 8601 format
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        if let date = formatter.date(from: dateString) {
            return date
        }

        return nil
    }
}
