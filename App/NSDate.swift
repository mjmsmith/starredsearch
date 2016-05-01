import Foundation

// Objective-C class extensions don't support static properties.

private let IsoDateFormatter: NSDateFormatter = {
  let dateFormatter = NSDateFormatter()
  
  dateFormatter.locale = NSLocale(localeIdentifier: "en_US_POSIX")
  dateFormatter.timeZone = NSTimeZone(forSecondsFromGMT: 0)
  dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
  
  return dateFormatter
}()

extension NSDate {
  static func date(fromIsoString string: String) -> NSDate? {
    return IsoDateFormatter.date(from: string)
  }
}