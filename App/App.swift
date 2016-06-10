import Foundation
import Mustache
import Vapor
import VaporMustache

private let PurgeInterval = NSTimeInterval(60*60)
private let UserTimeoutInterval = NSTimeInterval(60*60*4)
private let MinQueryLength = 3

class App {
  private let server = Application()
  private let shortDateFormatter = NSDateFormatter()
  private var purgeTimeStamp = NSDate()

  private var _usersBySessionIdentifier = [String: User]()
  private let usersQueue = dispatch_queue_create("usersQueue", DISPATCH_QUEUE_CONCURRENT)!
  
  init() {
    self.shortDateFormatter.dateStyle = .shortStyle
    
    setupRoutes(server: server)
    setupProviders(server: server)
  }
  
  func startServer() {
    self.server.start()
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
      var dict: [String: Any] = ["fetchedCount": fetchedRepoCounts.fetchedCount, "totalCount": fetchedRepoCounts.totalCount]
      
      dict["status"] = {
        switch user.reposState {
          case .notFetched: return "Connecting to GitHub..."
          case .fetching where fetchedRepoCounts.totalCount == 0: return "Getting starred repositories..."
          case .fetching: return "Fetching \(fetchedRepoCounts.totalCount) readmes..."
          case .fetched: return "Fetched readmes"
        }
      }()
      
      if user.reposState == .fetched {
        dict["nextUrl"] = request.session?["nextUrl"] ?? "/search"
      }
      
      return JSON(dict)
    }

    server.get("search") { [unowned self] request in
      guard let user = self.userForRequest(request) else {
        var queryDict = [String: String]()
        
        for queryItem in request.uri.query {
          queryDict[queryItem.key] = queryItem.value.first ?? ""
        }

        if let path = request.uri.path,
               url = NSURLComponents(string: path, queryDict: queryDict)?.url {
          request.session?["nextUrl"] = url.absoluteString
        }
        
        return Response(redirect: "/")
      }
      
      let query = request.data["query"]?.string ?? ""
      let order = RepoQueryResults.SortOrder(rawValue: request.data["order"]?.string ?? "") ?? .count
      let dicts: [[String: Any]]

      if query.characters.count >= MinQueryLength {
        let repoQueryResults =
          user.repos
          .map { repo in self.repoQueryResults(for: query, in: repo) }
          .filter { results in results.count > 0 }
        
        dicts = RepoQueryResults.sorted(results: repoQueryResults, by: order).map { results in
          return [
                   "repoId": results.repo.id,
                   "repoName": results.repo.name,
                   "repoUrl": results.repo.url?.absoluteString ?? "",
                   "ownerId": results.repo.ownerId,
                   "ownerName": results.repo.ownerName,
                   "ownerUrl": results.repo.ownerUrl?.absoluteString ?? "",
                   "forksCount": results.repo.forksCount,
                   "starsCount": results.repo.starsCount,
                   "starredAt": self.shortDateFormatter.string(from: results.repo.starredAt),
                   "matchesCount" : results.count,
                   "lines": results.htmls
                 ]
          }
      }
      else {
        dicts = []
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
                                        "order": order.rawValue,
                                        "repos": dicts,
                                        "status": status
                                      ])
    }

    server.get("admin") { [unowned self] request in
      guard let headerValue = request.headers["Authorization"].values.first where headerValue.starts(with: "Basic "),
            let passwordData = NSData(base64Encoded: headerValue.substring(from: headerValue.index(headerValue.startIndex, offsetBy: 6))),
                password = NSString(data: passwordData, encoding: NSUTF8StringEncoding) where password == ":\(AppAdminPassword)"
      else {
        return Response(status: .unauthorized, headers: ["WWW-Authenticate": "Basic"])
      }

      var users = [User]()
      var usersByRepo = [Repo: [User]]()
      
      dispatch_sync(self.usersQueue, { users = Array(self._usersBySessionIdentifier.values) })

      for user in users {
        for repo in user.repos {
          usersByRepo[repo] = (usersByRepo[repo] ?? []) + [user]
        }
      }

      let userDicts: [[String: Any]] =
        users
        .sorted() { left, right in left.timeStamp.compare(right.timeStamp) == .orderedAscending }
        .map { user in
          return [
                   "timeStamp": user.timeStamp.description,
                   "username": user.username
                 ]
      }
      let repoDicts: [[String: Any]] =
        User.cachedRepos
        .sorted() { left, right in left.timeStamp.compare(right.timeStamp) == .orderedAscending }
        .map { repo in
          return [
                   "timeStamp": repo.timeStamp.description,
                   "id": repo.id,
                   "name": repo.name,
                   "users": (usersByRepo[repo]?.map { user in user.username }) ?? []
                 ]
      }
      
      return try server.view("admin.mustache", context: ["users": userDicts, "repos": repoDicts])
    }
  }
  
  private func setupProviders(server: Application) {
    server.providers.append(Provider(withIncludes: [
                                                     "contact": "Includes/contact.mustache",
                                                     "head": "Includes/head.mustache",
                                                     "header": "Includes/header.mustache"
                                                   ]))
  }

  private func repoQueryResults(for query: String, in repo: Repo) -> RepoQueryResults {
    let lineResults: [(count: Int, html: String)] =
      repo
      .linesMatching(query: query)
      .map { line in
        let ranges = line.ranges(of: query, options: .caseInsensitiveSearch)
        var currentIndex = line.startIndex
        var substrings = [String]()
        
        for range in ranges {
         if (currentIndex != range.lowerBound) {
            substrings.append(escapeHTML(line.substring(with: currentIndex..<range.lowerBound)))
         }
        
         substrings.append("<mark>\(escapeHTML(line.substring(with: range)))</mark>")
        
         currentIndex = range.upperBound
        }
        
        if (currentIndex != line.endIndex) {
          substrings.append(escapeHTML(line.substring(with: currentIndex..<line.endIndex)))
        }
                
        return (count: ranges.count, html: substrings.joined(separator: ""))
      }
  
    let repoResults = lineResults.reduce((count: 0, htmls: [String]())) {
      accum, results in (count: accum.count + results.count, htmls: accum.htmls + [results.html])
    }
      
    return RepoQueryResults(repo: repo, count: repoResults.count, htmls: repoResults.htmls)
  }
  
  private func userForSessionIdentifier(_ sessionIdentifier: String) -> User? {
    var user: User?
    
    dispatch_sync(self.usersQueue, { user = self._usersBySessionIdentifier[sessionIdentifier]})
    
    return user
  }
  
  private func setUser(_ user: User, forSessionIdentifier sessionIdentifier: String) {
    dispatch_barrier_sync(self.usersQueue, { self._usersBySessionIdentifier[sessionIdentifier] = user })
  }

  private func userForRequest(_ request: Request) -> User? {
    self.purgeUsersAndRepos()
    
    guard let sessionIdentifier = request.session?.identifier,
          user = self.userForSessionIdentifier(sessionIdentifier)
    else {
      return nil
    }
    
    user.updateTimeStamp()

    return user
  }
  
  private func purgeUsersAndRepos() {
    let now = NSDate()
    
    // Check if it's time to purge users.
    
    guard now.timeIntervalSince(self.purgeTimeStamp) > PurgeInterval else {
      return
    }

    // With exclusive access, make sure another thread didn't get in before us
    // and update the purge timestamp so nobody tries to get in after us.
    
    dispatch_barrier_sync(self.usersQueue, {
      guard now.timeIntervalSince(self.purgeTimeStamp) > PurgeInterval else {
        return
      }

      self.purgeTimeStamp = now
    
      self._usersBySessionIdentifier
      .filter { _, user in return now.timeIntervalSince(user.timeStamp) > UserTimeoutInterval }
      .forEach { sessionIdentifier, _ in self._usersBySessionIdentifier.removeValue(forKey: sessionIdentifier) }

      User.purgeRepos()
    })
  }
}
