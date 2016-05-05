import Foundation

extension NSURLComponents {
  convenience init?(string: String, queryDict: [String:String]) {
    self.init(string: string)

    if queryDict.count > 0 {
      self.queryItems = queryDict.map { key, value in
        return NSURLQueryItem(name: key, value: value)
      }
    }
  }
}
