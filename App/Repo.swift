import Foundation

class Repo {
  let id: Int
  let name: String
  let ownerId: Int
  let ownerName: String
  let starredAt: NSDate
  
  private var readme: [String]?
  
  private static let title1Regex = try! NSRegularExpression(pattern: "^#+ +", options: .anchorsMatchLines)
  private static let title2Regex = try! NSRegularExpression(pattern: "^=+$", options: .anchorsMatchLines)
  private static let codeBlockRegex = try! NSRegularExpression(pattern: "^```.*$", options: .anchorsMatchLines)
  
  private static let anchorRegex = try! NSRegularExpression(pattern: "<a .*?>(.*?)</a>", options: .dotMatchesLineSeparators)
  private static let imgRegex = try! NSRegularExpression(pattern: "<img .*?/?>", options: .dotMatchesLineSeparators)
  private static let commentRegex = try! NSRegularExpression(pattern: "<!--.*?-->", options: .dotMatchesLineSeparators)
  
  private static let linkRegex = try! NSRegularExpression(pattern: "!?\\[(.*?)\\] ?\\(.*?\\)", options: [])
  private static let bold1Regex = try! NSRegularExpression(pattern: "__(.+?)__", options: [])
  private static let bold2Regex = try! NSRegularExpression(pattern: "\\*\\*(.+?)\\*\\*", options: [])
  private static let italic1Regex = try! NSRegularExpression(pattern: "_(.+?)_", options: [])
  private static let italic2Regex = try! NSRegularExpression(pattern: "\\*(.+?)\\*", options: [])
  private static let codeRegex = try! NSRegularExpression(pattern: "`(.*?)`", options: [])

  init(id: Int, name: String, ownerId: Int, ownerName: String, starredAt: NSDate) {
    self.id = id
    self.name = name
    self.ownerId = ownerId
    self.ownerName = ownerName
    self.starredAt = starredAt
  }

  var url: NSURL? {
    get {
      return NSURL(string: "https://github.com/\(self.ownerName)/\(self.name)")
    }
  }
  
  var readmeUrl: NSURL? {
    get {
      return NSURL(string: "https://api.github.com/repos/\(self.ownerName)/\(self.name)/readme")
    }
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
    
    text = self.anchorRegex.stringByReplacingMatches(in: text, options: [], range: NSRange(location: 0, length: text.characters.count), withTemplate: "")
    text = self.imgRegex.stringByReplacingMatches(in: text, options: [], range: NSRange(location: 0, length: text.characters.count), withTemplate: "")
    text = self.commentRegex.stringByReplacingMatches(in: text, options: [], range: NSRange(location: 0, length: text.characters.count), withTemplate: "")
    
    text = self.linkRegex.stringByReplacingMatches(in: text, options: [], range: NSRange(location: 0, length: text.characters.count), withTemplate: "$1")
    text = self.bold1Regex.stringByReplacingMatches(in: text, options: [], range: NSRange(location: 0, length: text.characters.count), withTemplate: "$1")
    text = self.bold2Regex.stringByReplacingMatches(in: text, options: [], range: NSRange(location: 0, length: text.characters.count), withTemplate: "$1")
    text = self.italic1Regex.stringByReplacingMatches(in: text, options: [], range: NSRange(location: 0, length: text.characters.count), withTemplate: "$1")
    text = self.italic2Regex.stringByReplacingMatches(in: text, options: [], range: NSRange(location: 0, length: text.characters.count), withTemplate: "$1")
    text = self.codeRegex.stringByReplacingMatches(in: text, options: [], range: NSRange(location: 0, length: text.characters.count), withTemplate: "$1")
    
    return text
  }
}
