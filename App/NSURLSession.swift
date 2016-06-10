import Foundation

extension NSURLSession {
  func synchronousDataTask(with url: NSURL, headers: [String: String] = [:]) -> (NSData?, NSURLResponse?, NSError?) {
    let request = NSMutableURLRequest(url: url)

    for (name, value) in headers {
      request.addValue(value, forHTTPHeaderField: name)
    }
    
    var returnValue: (NSData?, NSURLResponse?, NSError?)
    let semaphore = dispatch_semaphore_create(0)!

    self.dataTask(with: request) {
      returnValue = ($0, $1, $2)
      dispatch_semaphore_signal(semaphore)
    }.resume()
    
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER)
    
    return returnValue
  }
}
