import Foundation

extension String {
  func ranges(of searchString: String, options: NSStringCompareOptions = [], searchRange: Range<Index>? = nil) -> [Range<Index>] {
    guard let range = self.range(of: searchString, options: options, range: searchRange) else {
      return []
    }
    
    return [range] + self.ranges(of: searchString, searchRange: range.endIndex..<self.endIndex)
  }

  func truncated(length: Int, trailing: String? = "...") -> String {
    guard self.characters.count > length else {
      return self
    }

    return self.substring(to: self.startIndex.advanced(by: length)) + (trailing ?? "")
  }
}
