import Foundation

extension NSURLComponents {
  // TODO: Why can't I declare a failabile initializer version of this?
  
  static func componentsWith(string string: String, queryDict: [String:String]) -> NSURLComponents? {
    guard let components = NSURLComponents(string: string) else { return nil }

    if queryDict.count > 0 {
      components.queryItems = queryDict.map { key, value in
        return NSURLQueryItem(name: key, value: value)
      }
    }
    
    return components
  }
}
