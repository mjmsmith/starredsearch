import Foundation
import Dispatch

extension URLSession {
  func synchronousDataTask(with url: URL, headers: [String: String] = [:]) -> (Data?, URLResponse?, Error?) {
    var request = URLRequest(url: url)

    for (name, value) in headers {
      request.addValue(value, forHTTPHeaderField: name)
    }
    
    var returnValue: (Data?, URLResponse?, Error?)
    let semaphore = DispatchSemaphore(value: 0)

    self.dataTask(with: request) {
      returnValue = ($0, $1, $2)
      semaphore.signal()
    }.resume()
    
    semaphore.wait()
    
    return returnValue
  }
}
