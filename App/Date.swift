import Foundation

// Objective-C class extensions don't support static properties.

private let IsoDateFormatter: DateFormatter = {
  let dateFormatter = DateFormatter()
  
  dateFormatter.locale = Locale(identifier: "en_US_POSIX")
  dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
  dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
  
  return dateFormatter
}()

extension Date {
  static func date(fromIsoString string: String) -> Date? {
    return IsoDateFormatter.date(from: string)
  }
}
