import Foundation

class Repo {
  private static let title1Regex = try! NSRegularExpression(pattern: "^#+ +", options: .anchorsMatchLines)
  private static let title2Regex = try! NSRegularExpression(pattern: "^=+$", options: .anchorsMatchLines)
  private static let codeBlockRegex = try! NSRegularExpression(pattern: "^```.*$", options: .anchorsMatchLines)

  private static let imageRegex = try! NSRegularExpression(pattern: "!\\[(.*?)\\] ?\\(.*?\\)", options: .dotMatchesLineSeparators)
  private static let linkRegex = try! NSRegularExpression(pattern: "\\[(.*?)\\] ?\\(.*?\\)", options: .dotMatchesLineSeparators)

  private static let anchorRegex = try! NSRegularExpression(pattern: "<a .*?>(.*?)</a>", options: .dotMatchesLineSeparators)
  private static let imgRegex = try! NSRegularExpression(pattern: "<img .*?/?>", options: .dotMatchesLineSeparators)
  private static let commentRegex = try! NSRegularExpression(pattern: "<!--.*?-->", options: .dotMatchesLineSeparators)
  
  private static let bold1Regex = try! NSRegularExpression(pattern: "__(.+?)__", options: [])
  private static let bold2Regex = try! NSRegularExpression(pattern: "\\*\\*(.+?)\\*\\*", options: [])
  private static let italic1Regex = try! NSRegularExpression(pattern: "_(.+?)_", options: [])
  private static let italic2Regex = try! NSRegularExpression(pattern: "\\*(.+?)\\*", options: [])
  private static let codeRegex = try! NSRegularExpression(pattern: "`(.*?)`", options: [])
  
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

  func linesMatching(query query: String) -> [String] {
    return self.readme?.filter { $0.localizedCaseInsensitiveContains(query) } ?? []
  }
  
  func setReadme(withMarkdown markdown: String) {
    self.readme = Repo.stripped(markdown: markdown).componentsSeparated(by: "\n").filter { !$0.isEmpty }
  }
  
  private static func stripped(markdown markdown: String) -> String {
    var text = markdown
    
    text = self.title1Regex.stringByReplacingMatches(in: text, options: [], range: NSRange(location: 0, length: text.characters.count), withTemplate: "")
    text = self.title2Regex.stringByReplacingMatches(in: text, options: [], range: NSRange(location: 0, length: text.characters.count), withTemplate: "")
    text = self.codeBlockRegex.stringByReplacingMatches(in: text, options: [], range: NSRange(location: 0, length: text.characters.count), withTemplate: "")

    text = self.imageRegex.stringByReplacingMatches(in: text, options: [], range: NSRange(location: 0, length: text.characters.count), withTemplate: "")
    text = self.linkRegex.stringByReplacingMatches(in: text, options: [], range: NSRange(location: 0, length: text.characters.count), withTemplate: "$1")

    text = self.anchorRegex.stringByReplacingMatches(in: text, options: [], range: NSRange(location: 0, length: text.characters.count), withTemplate: "")
    text = self.imgRegex.stringByReplacingMatches(in: text, options: [], range: NSRange(location: 0, length: text.characters.count), withTemplate: "")
    text = self.commentRegex.stringByReplacingMatches(in: text, options: [], range: NSRange(location: 0, length: text.characters.count), withTemplate: "")
    
    text = self.bold1Regex.stringByReplacingMatches(in: text, options: [], range: NSRange(location: 0, length: text.characters.count), withTemplate: "$1")
    text = self.bold2Regex.stringByReplacingMatches(in: text, options: [], range: NSRange(location: 0, length: text.characters.count), withTemplate: "$1")
    text = self.italic1Regex.stringByReplacingMatches(in: text, options: [], range: NSRange(location: 0, length: text.characters.count), withTemplate: "$1")
    text = self.italic2Regex.stringByReplacingMatches(in: text, options: [], range: NSRange(location: 0, length: text.characters.count), withTemplate: "$1")
    text = self.codeRegex.stringByReplacingMatches(in: text, options: [], range: NSRange(location: 0, length: text.characters.count), withTemplate: "$1")
    
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
