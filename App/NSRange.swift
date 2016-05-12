import Foundation
 
extension NSRange {
  func asStringRange(in string: String) -> Range<String.Index> {
    return string.index(string.startIndex, offsetBy: self.location)..<string.index(string.startIndex, offsetBy: self.location + self.length)
  }
}
