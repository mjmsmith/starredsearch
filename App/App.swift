import Foundation
import Mustache
import Vapor
import VaporZewoMustache

private let PurgeInterval = NSTimeInterval(60*60)
private let UserTimeoutInterval = NSTimeInterval(60*60*24)
private let MinQueryLength = 3

class App {
  private let server = Application()
  private let shortDateFormatter = NSDateFormatter()
  private var purgeTimeStamp = NSDate()

  private var _usersBySessionIdentifier = [String:User]()
  private let usersQueue = dispatch_queue_create("usersQueue", DISPATCH_QUEUE_CONCURRENT)
  
  init() {
    self.shortDateFormatter.dateStyle = .shortStyle
    
    setupRoutes(server)
    setupProviders(server)
  }
  
  func startServer() {
#if DEBUG
    self.server.start(port:8080)
#else
    self.server.start()
#endif
  }
  
  private func setupRoutes(server: Application) {
    server.get("/") { [unowned self] request in
      // Redirect if we already have a user.
      
      if let user = self.userForRequest(request) {
        switch user.reposState {
          case .notFetched: break
          case .fetching: return Response(redirect: "/load")
          case .fetched: return Response(redirect: "/search")
        }
      }
      
      request.session?["timeStamp"] = String(NSDate().timeIntervalSinceReferenceDate)
      
      return try server.view("index.mustache",
                             context: ["url": "https://github.com/login/oauth/authorize?client_id=\(GitHubClientID)"])
    }
    
    server.get("oauth", "github") { [unowned self] request in
      guard let sessionIdentifier = request.session?.identifier,
                code = request.data["code"]?.string
      else {
        return Response(redirect: "/")
      }

      let user = User()

      user.initializeWithCode(code)
      self.setUser(user, forSessionIdentifier: sessionIdentifier)
      
      return Response(redirect: "/load")
    }
    
    server.get("load") { [unowned self] request in
      guard let _ = self.userForRequest(request) else {
        return Response(redirect: "/")
      }
      
      return try server.view("load.mustache")
    }
    
    server.get("load", "status") { [unowned self] request in
      guard let user = self.userForRequest(request) else {
        return Response(status: .unauthorized)
      }

      let fetchedRepoCounts = user.fetchedRepoCounts
      var dict:[String:JsonRepresentable] = ["fetchedCount": fetchedRepoCounts.fetchedCount, "totalCount": fetchedRepoCounts.totalCount]
      
      dict["status"] = {
        switch user.reposState {
          case .notFetched: return "Connecting to GitHub..."
          case .fetching where fetchedRepoCounts.totalCount == 0: return "Getting starred repositories..."
          case .fetching: return "Fetching \(fetchedRepoCounts.totalCount) readmes..."
          case .fetched: return "Fetched readmes"
        }
      }()
      
      if user.reposState == .fetched {
        dict["nextUrl"] = "/search"
      }
      
      return Json(dict)
    }
    
    server.get("search") { [unowned self] request in
      guard let user = self.userForRequest(request) else {
        return Response(redirect: "/")
      }
      
      let isOrderedBefore: ([String:Any], [String:Any]) -> Bool = { left, right in
        let leftRepoName = left["repoName"] as! String
        let rightRepoName = right["repoName"] as! String
        
        if leftRepoName == rightRepoName {
          let leftOwnerName = left["ownerName"] as! String
          let rightOwnerName = right["ownerName"] as! String

          return leftOwnerName.lowercased() < rightOwnerName.lowercased()
        }
        else {
          return leftRepoName.lowercased() < rightRepoName.lowercased()
        }
      }

      let _query = request.data["query"]?.string ?? "", // TODO: why does this == "query" when the query string field value is empty?
          query = _query == "query" ? "" : _query
      var dicts = [[String:Any]]()

      if query.characters.count >= MinQueryLength {
        dicts = user.repos.flatMap { repo in
          let repoResults: (count: Int, htmls: [String]) =
            repo.linesMatching(query:query)
              .map { line in self.results(forQuery: query, inLine: line) }
              .reduce((0, [String]())) { total, current in (total.count + current.count, total.htmls + [current.html]) }
          
          if repoResults.count > 0 {
            return [
                     "repoId": repo.id,
                     "repoName": repo.name,
                     "repoUrl": repo.url?.absoluteString ?? "",
                     "ownerId": repo.ownerId,
                     "ownerName": repo.ownerName,
                     "starredAt": self.shortDateFormatter.string(from: repo.starredAt),
                     "count" : repoResults.count,
                     "lines": repoResults.htmls
                   ]
          }
          else {
            return nil
          }
        }
      }

      let status: String = {
        switch (query.characters.count) {
          case 0:
            return ""
          case 1..<MinQueryLength:
            return "Please enter at least \(MinQueryLength) characters."
          default:
            return dicts.count == 0 ? "No results for “\(query)”." : ""
        }
      }()

      return try server.view("search.mustache",
                             context: [
                                        "totalCount": user.repos.count,
                                        "query": query,
                                        "repos": dicts.sorted(isOrderedBefore: isOrderedBefore),
                                        "status": status
                                      ])
    }
    
    server.get("admin") { [unowned self] request in
      var users: [String:User]!
      
      dispatch_sync(self.usersQueue, { users = self._usersBySessionIdentifier })

      let dicts: [[String:Any]] = Array(users.values).map { user in
        return [
                 "timeStamp": user.timeStamp.description,
                 "repos": user.repos.map { repo in
                            return ["name": repo.name]
                          }
               ]
      }
      
      
      return try server.view("admin.mustache", context: ["users": dicts])
    }
  }
  
  private func setupProviders(server: Application) {
    server.providers.append(VaporZewoMustache.Provider(withIncludes: [
                                                                       "head": "Includes/head.mustache",
                                                                       "heading": "Includes/heading.mustache"
                                                                     ]))
  }
  
  func results(forQuery query: String, inLine line: String) -> (count: Int, html: String) {
    let ranges = line.ranges(of: query, options:.caseInsensitiveSearch)
    var currentIndex = line.startIndex
    var substrings = [String]()
    
    for range in ranges {
      if (currentIndex != range.startIndex) {
        substrings.append(escapeHTML(line.substring(with: currentIndex..<range.startIndex)))
      }
      
      substrings.append("<mark>\(escapeHTML(line.substring(with: range)))</mark>")
      
      currentIndex = range.endIndex
    }
    
    if (currentIndex != line.endIndex) {
      substrings.append(escapeHTML(line.substring(with: currentIndex..<line.endIndex)))
    }
    
    return (count: ranges.count, html: substrings.joined(separator: ""))
  }
  
  private func userForSessionIdentifier(sessionIdentifier: String) -> User? {
    var user: User?
    
    dispatch_sync(self.usersQueue, { user = self._usersBySessionIdentifier[sessionIdentifier]})
    
    return user
  }
  
  private func setUser(user: User, forSessionIdentifier sessionIdentifier: String) {
    dispatch_barrier_sync(self.usersQueue, { self._usersBySessionIdentifier[sessionIdentifier] = user })
  }

  private func userForRequest(request: Request) -> User? {
    self.purgeUsers()
    
    guard let sessionIdentifier = request.session?.identifier,
          user = self.userForSessionIdentifier(sessionIdentifier)
    else {
      return nil
    }
    
    user.updateTimeStamp()

    return user
  }
  
  private func purgeUsers() {
    let now = NSDate()
    
    // Check if it's time to purge users.
    
    guard now.timeInterval(since: self.purgeTimeStamp) > PurgeInterval else {
      return
    }

    // With exclusive access, make sure another thread didn't get in before us
    // and update the purge timestamp so nobody tries to get in after us.
    
    dispatch_barrier_sync(self.usersQueue, {
      guard now.timeInterval(since: self.purgeTimeStamp) > PurgeInterval else {
        return
      }

      self.purgeTimeStamp = now
    
      self._usersBySessionIdentifier
        .filter { _, user in return now.timeInterval(since: user.timeStamp) > UserTimeoutInterval }
        .forEach { sessionIdentifier, _ in self._usersBySessionIdentifier.removeValue(forKey: sessionIdentifier) }
    })
  }
}
