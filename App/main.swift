import Foundation
import Vapor

private func config() -> (String, String, String) {
  let workdir: String? = {
    for arg in CommandLine.arguments {
      let components = arg.components(separatedBy: "=")
      
      if components.count == 2 && components[0] == "--workdir" {
        return components[1]
      }
    }
    
    return nil
  }()
  
  if let workdir = workdir,
     let data = try? Data(contentsOf: URL(fileURLWithPath: "\(workdir)/debug.json")),
     let json = try? JSON(bytes: data.withUnsafeBytes { [UInt8](UnsafeBufferPointer(start: $0, count: data.count)) }),
     let dict = json.node.nodeObject {
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

let (GitHubClientID, GitHubClientSecret, AppAdminPassword) = config()

App().startServer()
