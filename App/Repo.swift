import Foundation

// # title
private let TitleRegex = try! NSRegularExpression(pattern: "^#+(.*)$", options: .anchorsMatchLines)

// =======
private let TitleEqualRegex = try! NSRegularExpression(pattern: "^=+ *$", options: .anchorsMatchLines)

// -------
private let TitleUnderlineRegex = try! NSRegularExpression(pattern: "^=+ *$", options: .anchorsMatchLines)

// ```
private let CodeBlockRegex = try! NSRegularExpression(pattern: "^```.*$", options: .anchorsMatchLines)

// [example]: http://example.com
private let FootnoteRegex = try! NSRegularExpression(pattern: "^ *\\[.+?\\]: *.*$", options: .anchorsMatchLines)

// ![example](http://example.com/image.png)
private let ImageRegex = try! NSRegularExpression(pattern: "!\\[(.*?)\\] *\\(.*?\\)", options: .dotMatchesLineSeparators)

// [example](http://example.com)
private let LinkRegex = try! NSRegularExpression(pattern: "\\[(.*?)\\] *\\(.*?\\)", options: .dotMatchesLineSeparators)

// [example][example]
private let FootnoteLinkRegex = try! NSRegularExpression(pattern: "\\[(.+?)\\]\\[.*?\\]", options: .dotMatchesLineSeparators)

// <a href="http://example.com">example</a>
private let AnchorRegex = try! NSRegularExpression(pattern: "<a .*?>(.*?)</a>", options: .dotMatchesLineSeparators)

// <img src="http://example.com/image.png">
private let ImgRegex = try! NSRegularExpression(pattern: "<img .*?/?>", options: .dotMatchesLineSeparators)

// <!-- example -->
private let CommentRegex = try! NSRegularExpression(pattern: "<!--.*?-->", options: .dotMatchesLineSeparators)

// __example__
private let BoldUnderlineRegex = try! NSRegularExpression(pattern: "__([^ ].*?[^ ])__", options: [])

// **example**
private let BoldAsteriskRegex = try! NSRegularExpression(pattern: "\\*\\*([^ ].*?[^ ])\\*\\*", options: [])

// _example_
private let ItalicUnderlineRegex = try! NSRegularExpression(pattern: "_([^ ].*?[^ ])_", options: [])

// *example*
private let ItalicAsteriskRegex = try! NSRegularExpression(pattern: "\\*([^ ].*?[^ ])\\*", options: [])

// `example`
private let CodeRegex = try! NSRegularExpression(pattern: "`(.*?)`", options: [])

class Repo {
  private static let readmeQueue = dispatch_queue_create("readme", DISPATCH_QUEUE_CONCURRENT)

  let id: Int
  let name: String
  let ownerId: Int
  let ownerName: String
  let starredAt: NSDate
  let timeStamp = NSDate()

  private(set) var readme: [String]? {
    get { var value: [String]?; dispatch_sync(Repo.readmeQueue, { value = self._readme }); return value! }
    set { dispatch_barrier_sync(Repo.readmeQueue, { self._readme = newValue }) }
  }
  
  var url: NSURL? {
    get { return NSURL(string: "https://github.com/\(self.ownerName)/\(self.name)") }
  }
  
  var ownerUrl: NSURL? {
    get { return NSURL(string: "https://github.com/\(self.ownerName)") }
  }
  
  var readmeUrl: NSURL? {
    get { return NSURL(string: "https://api.github.com/repos/\(self.ownerName)/\(self.name)/readme") }
  }
  
  private var _readme: [String]?

  init(id: Int, name: String, ownerId: Int, ownerName: String, starredAt: NSDate) {
    self.id = id
    self.name = name
    self.ownerId = ownerId
    self.ownerName = ownerName
    self.starredAt = starredAt
  }

  func linesMatching(query: String) -> [String] {
    return self.readme?.filter { $0.localizedCaseInsensitiveContains(query) } ?? []
  }
  
  func setReadme(withMarkdown markdown: String) {
    self.readme = Repo.stripped(markdown: markdown).components(separatedBy: "\n").filter { !$0.isEmpty }
  }
  
  private static func stripped(markdown: String) -> String {
    var text = markdown
    
    text = TitleRegex.stringByReplacingMatches(in: text, options: [], range: NSRange(location: 0, length: text.characters.count), withTemplate: "$1")

    text = TitleEqualRegex.stringByReplacingMatches(in: text, options: [], range: NSRange(location: 0, length: text.characters.count), withTemplate: "")
    text = TitleUnderlineRegex.stringByReplacingMatches(in: text, options: [], range: NSRange(location: 0, length: text.characters.count), withTemplate: "")
    text = CodeBlockRegex.stringByReplacingMatches(in: text, options: [], range: NSRange(location: 0, length: text.characters.count), withTemplate: "")
    text = FootnoteRegex.stringByReplacingMatches(in: text, options: [], range: NSRange(location: 0, length: text.characters.count), withTemplate: "")

    text = ImageRegex.stringByReplacingMatches(in: text, options: [], range: NSRange(location: 0, length: text.characters.count), withTemplate: "")
    
    text = LinkRegex.stringByReplacingMatches(in: text, options: [], range: NSRange(location: 0, length: text.characters.count), withTemplate: "$1")
    text = FootnoteLinkRegex.stringByReplacingMatches(in: text, options: [], range: NSRange(location: 0, length: text.characters.count), withTemplate: "$1")

    text = AnchorRegex.stringByReplacingMatches(in: text, options: [], range: NSRange(location: 0, length: text.characters.count), withTemplate: "")
    text = ImgRegex.stringByReplacingMatches(in: text, options: [], range: NSRange(location: 0, length: text.characters.count), withTemplate: "")
    text = CommentRegex.stringByReplacingMatches(in: text, options: [], range: NSRange(location: 0, length: text.characters.count), withTemplate: "")
    
    text = BoldUnderlineRegex.stringByReplacingMatches(in: text, options: [], range: NSRange(location: 0, length: text.characters.count), withTemplate: "$1")
    text = BoldAsteriskRegex.stringByReplacingMatches(in: text, options: [], range: NSRange(location: 0, length: text.characters.count), withTemplate: "$1")
    text = ItalicUnderlineRegex.stringByReplacingMatches(in: text, options: [], range: NSRange(location: 0, length: text.characters.count), withTemplate: "$1")
    text = ItalicAsteriskRegex.stringByReplacingMatches(in: text, options: [], range: NSRange(location: 0, length: text.characters.count), withTemplate: "$1")
    text = CodeRegex.stringByReplacingMatches(in: text, options: [], range: NSRange(location: 0, length: text.characters.count), withTemplate: "$1")
    
    return text
  }
}

extension Repo: Hashable {
  var hashValue: Int {
    return self.id
  }
}

func ==(left: Repo, right: Repo) -> Bool {
  return left === right
}
