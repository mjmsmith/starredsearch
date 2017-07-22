import Foundation
import Dispatch
import HTTP
import LeafProvider
import Vapor

private let PurgeInterval = TimeInterval(60*60)
private let UserTimeoutInterval = TimeInterval(60*60*4)
private let MinQueryLength = 3

class App {
  public let droplet: Droplet
  private let shortDateFormatter = DateFormatter()
  private var purgeTimeStamp = Date()

  private var usersBySessionIdentifier = [String: User]()
  private let usersQueue = DispatchQueue(label: "usersQueue")
  
  init() throws {
    self.shortDateFormatter.dateStyle = .short

    let config = try Config()

    try config.addProvider(LeafProvider.Provider.self)

    self.droplet = try Droplet(config: config)

    self.setupRoutes()
  }
  
  func startServer() throws {
    try self.droplet.run()
  }
  
  private func setupRoutes() {
    self.droplet.get("/") { request in
      // Redirect if we already have a user.
      
      if let user = self.userForRequest(request) {
        switch user.reposState {
          case .notFetched: break
          case .fetching: return Response(redirect: "/load")
          case .fetched: return Response(redirect: "/search")
        }
      }
      
      request.session?.data["timeStamp"] = Node(String(Date().timeIntervalSinceReferenceDate))
      
      return try self.droplet.view.make("index",
                                        ["url": Node("https://github.com/login/oauth/authorize?client_id=\(GitHubClientID)")])
    }
    
    self.droplet.get("oauth", "github") { request in
      guard let sessionIdentifier = request.session?.identifier,
            let code = request.data["code"]?.string
      else {
        return Response(redirect: "/")
      }

      let user = User()

      user.initializeWithCode(code)
      self.setUser(user, forSessionIdentifier: sessionIdentifier)
      
      return Response(redirect: "/load")
    }
    
    self.droplet.get("load") { request in
      guard let _ = self.userForRequest(request) else {
        return Response(redirect: "/")
      }
      
      return try self.droplet.view.make("load")
    }
    
    self.droplet.get("load", "status") { request in
      guard let user = self.userForRequest(request) else {
        return Response(status: .unauthorized)
      }

      let fetchedRepoCounts = user.fetchedRepoCounts
      var dict: [String: Node] = [
        "fetchedCount": Node(fetchedRepoCounts.fetchedCount),
        "totalCount": Node(fetchedRepoCounts.totalCount)
      ]
      
      dict["status"] = {
        switch user.reposState {
          case .notFetched: return Node("Connecting to GitHub...")
          case .fetching where fetchedRepoCounts.totalCount == 0: return Node("Getting starred repositories...")
          case .fetching: return Node("Fetching \(fetchedRepoCounts.totalCount) readmes...")
          case .fetched: return Node("Fetched readmes")
        }
      }()
      
      if user.reposState == .fetched {
        dict["nextUrl"] = Node(request.session?.data["nextUrl"] ?? "/search")
      }
      
      return try JSON(node: dict)
    }

    self.droplet.get("search") { request in
      guard let user = self.userForRequest(request) else {
        var urlComponents = URLComponents()
        
        urlComponents.path = request.uri.path
        urlComponents.query = request.uri.query
        
        if let url = urlComponents.url {
          request.session?.data["nextUrl"] = Node(url.absoluteString)
        }
        
        return Response(redirect: "/")
      }
      
      let query = request.data["query"]?.string ?? ""
      let order = RepoQueryResults.SortOrder(rawValue: request.data["order"]?.string ?? "") ?? .count
      var dicts: [Node]

      if query.characters.count >= MinQueryLength {
        var repoQueryResults =
          user.repos
          .map { repo in self.repoQueryResults(for: query, in: repo) }
          .filter { results in results.count > 0 }
        repoQueryResults = RepoQueryResults.sorted(results: repoQueryResults, by: order)
        
        dicts = repoQueryResults.map { results in
          let repoUrl = results.repo.url?.absoluteString ?? ""
          let ownerUrl = results.repo.ownerUrl?.absoluteString ?? ""
          
          return [
            "repoId": Node(results.repo.id),
            "repoName": Node(results.repo.name),
            "repoUrl": Node(repoUrl),
            "ownerId": Node(results.repo.ownerId),
            "ownerName": Node(results.repo.ownerName),
            "ownerUrl": Node(ownerUrl),
            "forksCount": Node(results.repo.forksCount),
            "starsCount": Node(results.repo.starsCount),
            "starredAt": Node(self.shortDateFormatter.string(from: results.repo.starredAt)),
            "matchesCount": Node(results.count),
            "lines": Node(results.htmls.map { Node($0) })
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

      return try self.droplet.view.make("search", [
                                        "totalCount": Node(user.repos.count),
                                        "reposCount": Node(String(dicts.count)),
                                        "query": Node(query),
                                        "order": Node(order.rawValue),
                                        "repos": Node(dicts),
                                        "status": Node(status)
                                      ])
    }

    self.droplet.get("admin") { request in
      guard let headerValue = request.headers[HeaderKey("Authorization")], headerValue.hasPrefix("Basic "),
            let passwordData = Data(base64Encoded: headerValue.substring(from: headerValue.index(headerValue.startIndex, offsetBy: 6))),
            let password = String(data: passwordData, encoding: .utf8), password == ":\(AppAdminPassword)"
      else {
        return Response(status: .unauthorized, headers: ["WWW-Authenticate": "Basic"])
      }

      var users = [User]()
      var usersByRepo = [Repo: [User]]()
      
      self.usersQueue.sync() { users = Array(self.usersBySessionIdentifier.values) }

      for user in users {
        for repo in user.repos {
          usersByRepo[repo] = (usersByRepo[repo] ?? []) + [user]
        }
      }

      let userDicts: [Node] =
        users
        .sorted() { left, right in left.timeStamp.compare(right.timeStamp) == .orderedAscending }
        .map { user in
          return [
            "timeStamp": Node(user.timeStamp.description),
            "username": Node(user.username)
          ]
      }
      let repoDicts: [Node] =
        User.cachedRepos
        .sorted() { left, right in left.timeStamp.compare(right.timeStamp) == .orderedAscending }
        .map { repo in
          return [
            "timeStamp": Node(repo.timeStamp.description),
            "id": Node(repo.id),
            "name": Node(repo.name),
            "users": Node((usersByRepo[repo] ?? []).map { user in Node(user.username) })
          ]
      }
      
      return try self.droplet.view.make("admin", ["users": Node(userDicts), "repos": Node(repoDicts)])
    }
  }
  
  private func repoQueryResults(for query: String, in repo: Repo) -> RepoQueryResults {
    let lineResults: [(count: Int, html: String)] =
      repo
      .linesMatching(query: query)
      .map { line in
        let ranges = line.ranges(of: query, options: .caseInsensitive)
        var currentIndex = line.startIndex
        var substrings = [String]()
        
        for range in ranges {
         if (currentIndex != range.lowerBound) {
            substrings.append(self.escapeHTML(line.substring(with: currentIndex..<range.lowerBound)))
         }
        
         substrings.append("<mark>\(self.escapeHTML(line.substring(with: range)))</mark>")
        
         currentIndex = range.upperBound
        }
        
        if currentIndex != line.endIndex {
          substrings.append(self.escapeHTML(line.substring(with: currentIndex..<line.endIndex)))
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
    
    self.usersQueue.sync() { user = self.usersBySessionIdentifier[sessionIdentifier]}
    
    return user
  }
  
  private func setUser(_ user: User, forSessionIdentifier sessionIdentifier: String) {
    self.usersQueue.sync(flags: .barrier) { self.usersBySessionIdentifier[sessionIdentifier] = user }
  }

  private func userForRequest(_ request: Request) -> User? {
    self.purgeUsersAndRepos()
    
    guard let sessionIdentifier = request.session?.identifier,
          let user = self.userForSessionIdentifier(sessionIdentifier)
    else {
      return nil
    }
    
    user.updateTimeStamp()

    return user
  }
  
  private func purgeUsersAndRepos() {
    let now = Date()
    
    // Check if it's time to purge users.
    
    guard now.timeIntervalSince(self.purgeTimeStamp) > PurgeInterval else {
      return
    }

    // With exclusive access, make sure another thread didn't get in before us,
    // and update the purge timestamp so nobody tries to get in after us.
    
    self.usersQueue.sync(flags: .barrier) {
      guard now.timeIntervalSince(self.purgeTimeStamp) > PurgeInterval else {
        return
      }

      self.purgeTimeStamp = now
    
      self.usersBySessionIdentifier
          .filter { _, user in return now.timeIntervalSince(user.timeStamp as Date) > UserTimeoutInterval }
          .forEach { sessionIdentifier, _ in self.usersBySessionIdentifier.removeValue(forKey: sessionIdentifier) }

      User.purgeRepos()
    }
  }

  private func escapeHTML(_ string: String) -> String {
    let escapeTable: [Character: String] = [
      "<": "&lt;",
      ">": "&gt;",
      "&": "&amp;",
      "'": "&apos;",
      "\"": "&quot;",
      ]
    var escaped = ""
    
    for c in string.characters {
      if let escapedString = escapeTable[c] {
        escaped += escapedString
      }
      else {
        escaped.append(c)
      }
    }
    return escaped
  }
}
