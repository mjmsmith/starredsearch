import Foundation
import Vapor

private func config() -> (String, String, String) {
  if let workDir = Process.valueFor(argument: "workDir"),
     let data = NSData(contentsOfFile: "\(workDir)/debug.json"),
     let json = try? JSON(Data(data.byteArray)),
     let dict: [String: JSON] = json.object {
    return (
      dict["GITHUB_CLIENT_ID"]!.string!,
      dict["GITHUB_CLIENT_SECRET"]!.string!,
      dict["APP_ADMIN_PASSWORD"]!.string!
    )
  }
  else {
    return (
      NSProcessInfo.processInfo().environment["GITHUB_CLIENT_ID"]!,
      NSProcessInfo.processInfo().environment["GITHUB_CLIENT_SECRET"]!,
      NSProcessInfo.processInfo().environment["APP_ADMIN_PASSWORD"]!
    )
  }
}

let (GitHubClientID, GitHubClientSecret, AppAdminPassword) = config()

App().startServer()