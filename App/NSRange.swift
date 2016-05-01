 import Foundation
 
extension NSRange {
  func asStringRange(in string: String) -> Range<String.Index> {
    return string.startIndex.advanced(by: self.location)..<string.startIndex.advanced(by: self.location + self.length)
  }
}
