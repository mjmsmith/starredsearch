import Foundation

extension URLComponents {
  init?(string: String, queryDict: [String: String]) {
    self.init(string: string)

    if queryDict.count > 0 {
      self.queryItems = queryDict.map { key, value in
        return URLQueryItem(name: key, value: value)
      }
    }
  }
}
