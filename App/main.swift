import Foundation
import Vapor

#if DEBUG
  private let EnvDict:[String:Node] = {
    let path = Process.valueFor(argument: "workDir")! + "/debug.json"
    let data = NSData(contentsOfFile: path)!
    let json = try! Json(Data(data.arrayOfBytes()))
    return json.object!
  }()
    
  let GitHubClientID = EnvDict["GITHUB_CLIENT_ID"]!.string!
  let GitHubClientSecret = EnvDict["GITHUB_CLIENT_SECRET"]!.string!
  let AppAdminPassword = EnvDict["APP_ADMIN_PASSWORD"]!.string!
#else
  let GitHubClientID = NSProcessInfo.processInfo().environment["GITHUB_CLIENT_ID"]!
  let GitHubClientSecret = NSProcessInfo.processInfo().environment["GITHUB_CLIENT_SECRET"]!
  let AppAdminPassword = NSProcessInfo.processInfo().environment["APP_ADMIN_PASSWORD"]!
#endif

App().startServer()