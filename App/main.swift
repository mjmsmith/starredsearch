import Foundation
import Vapor

private func config() -> (String, String, String) {
  if let data = try? Data(contentsOf: URL(fileURLWithPath: "\(app.droplet.config.workDir)/debug.json")),
     let json = try? JSON(bytes: data.withUnsafeBytes { [UInt8](UnsafeBufferPointer(start: $0, count: data.count)) }),
     let dict = json.object {
    return (
      dict["GITHUB_CLIENT_ID"]!.string!,
      dict["GITHUB_CLIENT_SECRET"]!.string!,
      dict["APP_ADMIN_PASSWORD"]!.string!
    )
  }
  else {
    return (
      ProcessInfo.processInfo.environment["GITHUB_CLIENT_ID"]!,
      ProcessInfo.processInfo.environment["GITHUB_CLIENT_SECRET"]!,
      ProcessInfo.processInfo.environment["APP_ADMIN_PASSWORD"]!
    )
  }
}

let app = try App()
let (GitHubClientID, GitHubClientSecret, AppAdminPassword) = config()

try app.startServer()
