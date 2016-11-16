import Foundation
import Vapor

private let MaxRepoCount = 5000
private let MaxConcurrentSlowFetchOperations = 50
private let MaxConcurrentFastFetchOperations = 10
private let RepoTimeoutInterval = TimeInterval(60*60*24)

class User {
  private static var reposById = [Int: Repo]()
  private static let reposByIdQueue = DispatchQueue(label: "ReposById", attributes: .concurrent)
  
  private static func cachedRepo(id: Int) -> Repo? {
    var cachedRepo: Repo?
    self.reposByIdQueue.sync() { cachedRepo = self.reposById[id] }
    return cachedRepo
  }

  static var cachedRepos: [Repo] {
    get {
      var cachedRepos = [Repo]()
      self.reposByIdQueue.sync { cachedRepos = Array(self.reposById.values) }
      return cachedRepos
    }
  }
  
  private static func cacheRepo(repo: Repo) {
    self.reposByIdQueue.sync(flags: .barrier) { self.reposById[repo.id] = repo }
  }

  private static let usernameQueue = DispatchQueue(label: "username", attributes: .concurrent)
  private static let timeStampQueue = DispatchQueue(label: "timeStamp", attributes: .concurrent)
  private static let reposQueue = DispatchQueue(label: "repos", attributes: .concurrent)
  private static let reposStateQueue = DispatchQueue(label: "reposState", attributes: .concurrent)
  private static let fetchedRepoCountsQueue = DispatchQueue(label: "fetchRepoCounts", attributes: .concurrent)
  
  static func purgeRepos() {
    self.reposByIdQueue.sync(flags: .barrier) {
      let now = Date()
      
      self.reposById
      .filter { _, repo in return now.timeIntervalSince(repo.timeStamp) > RepoTimeoutInterval }
      .forEach { id, _ in self.reposById.removeValue(forKey: id) }
    }
  }
  
  private static let fetchQueue = DispatchQueue(label: "fetch", attributes: .concurrent)

  private static let fastFetchOperationQueue: OperationQueue = {
    let operationQueue = OperationQueue()
    
    operationQueue.maxConcurrentOperationCount = MaxConcurrentFastFetchOperations
    operationQueue.qualityOfService = .userInitiated
    
    return operationQueue
  }()
  
  private static let slowFetchOperationQueue: OperationQueue = {
    let operationQueue = OperationQueue()

    operationQueue.maxConcurrentOperationCount = MaxConcurrentSlowFetchOperations
    operationQueue.qualityOfService = .utility
    
    return operationQueue
  }()

  enum ReposState {
    case notFetched
    case fetching
    case fetched
  }
  
  private var accessToken: String?
  private var _username = ""
  private var _timeStamp = Date()
  private var _repos = [Repo]()
  private var _reposState = ReposState.notFetched
  private var _fetchedRepoCounts = (fetchedCount: 0, totalCount: 0)
  
  private(set) var username: String {
    get { var value: String?; User.usernameQueue.sync() { value = self._username }; return value! }
    set { User.usernameQueue.sync(flags: .barrier) { self._username = newValue } }
  }
  
  private(set) var timeStamp: Date {
    get { var value: Date?; User.timeStampQueue.sync() { value = self._timeStamp }; return value! }
    set { User.timeStampQueue.sync(flags: .barrier) { self._timeStamp = newValue } }
  }
  
  private(set) var repos: [Repo] {
    get { var value: [Repo]?; User.reposQueue.sync() { value = self._repos }; return value! }
    set { User.reposQueue.sync(flags: .barrier) { self._repos = newValue } }
  }
  
  private(set) var reposState: ReposState {
    get { var value: ReposState?; User.reposStateQueue.sync() { value = self._reposState }; return value! }
    set { User.reposStateQueue.sync(flags: .barrier) { self._reposState = newValue } }
  }
  
  private(set) var fetchedRepoCounts: (fetchedCount: Int, totalCount: Int) {
    get { var value: (fetchedCount: Int, totalCount: Int)?; User.fetchedRepoCountsQueue.sync() { value = self._fetchedRepoCounts }; return value! }
    set { User.fetchedRepoCountsQueue.sync(flags: .barrier) { self._fetchedRepoCounts = newValue } }
  }
  
  func initializeWithCode(_ code: String) {
    User.fetchQueue.async() {
      if let accessToken = self.exchangeCodeForAccessToken(code: code) {
        self.accessToken = accessToken
        
        self.username = self.fetchUsername() ?? "(unknown)"
        
        self.reposState = .fetching
        self.repos = self.fetchStarredRepos(dicts: self.fetchStarredRepoDicts())
        
        for repo in self.repos {
          User.cacheRepo(repo: repo)
        }
      }
      
      self.reposState = .fetched
    }
  }

  func updateTimeStamp() {
    self.timeStamp = Date()
  }
  
  private func exchangeCodeForAccessToken(code: String) -> String? {
    var accessToken: String?
    let requestComponents = URLComponents(string: "https://github.com/login/oauth/access_token",
                                          queryDict: [
                                                       "client_id": GitHubClientID,
                                                       "client_secret": GitHubClientSecret,
                                                       "code": code
                                                     ])!
    let operation = BlockOperation(block: {
      let (data, _, _) = URLSession.shared.synchronousDataTask(with: requestComponents.url!)
      
      if let queryData = data,
         let queryString = String(data: queryData, encoding: .utf8),
         let urlComponents = URLComponents(string: "?\(queryString)") {
        accessToken = urlComponents.queryItems?.filter({ $0.name == "access_token" }).first?.value
      }
    })
    
    User.fastFetchOperationQueue.addOperations([operation], waitUntilFinished: true)
    
    return accessToken
  }

  private func fetchUsername() -> String? {
    var username: String?
    let operation = BlockOperation(block: {
      let (data, _, _) = URLSession.shared.synchronousDataTask(with: URL(string: "https://api.github.com/user")!,
                                                               headers: self.authorizedRequestHeaders())
      
      if let data = data,
         let bytes = try? data.makeBytes(),
         let json = try? JSON(bytes: bytes),
         let dict = json.object {
        username = dict["login"]?.string
      }
    })
    
    User.fastFetchOperationQueue.addOperations([operation], waitUntilFinished: true)
    
    return username
  }
  
  private func fetchStarredRepoDicts() -> [[String: Node]] {
    guard let _ = self.accessToken else { return [] }
    
    var dicts = [[String: Node]]()
    var page = 1
    var perPage = 100
    
#if DEBUG
    perPage = 10
#endif
    
    repeat {
      let requestComponents = URLComponents(string: "https://api.github.com/user/starred",
                                            queryDict: [
                                                         "page": String(page),
                                                         "per_page": String(perPage)
                                                       ])!
      let operation = BlockOperation(block: {
        let (data, _, _) = URLSession.shared.synchronousDataTask(with: requestComponents.url!,
                                                                 headers: self.authorizedRequestHeaders(with: ["Accept": "application/vnd.github.star+json"]))
        
        if let data = data,
           let bytes = try? data.makeBytes(),
           let json = try? JSON(bytes: bytes),
           let array: [Node] = json.node.nodeArray {
          dicts += array.flatMap { $0.nodeObject }

          if array.count < perPage || dicts.count >= MaxRepoCount {
            perPage = 0
          }
          else {
            page += 1
          }
        }
        else {
          perPage = 0
        }
      })
      
      User.fastFetchOperationQueue.addOperations([operation], waitUntilFinished: true)
    } while perPage > 0
    
    return dicts
  }
  
  private func fetchStarredRepos(dicts: [[String: Node]]) -> [Repo] {
    guard let _ = self.accessToken else { return [] }

    self.fetchedRepoCounts = (fetchedCount: 0, totalCount: dicts.count)
    
    var cachedRepos = [Repo]()
    var newRepos = [Repo]()
    
    for dict in dicts {
      if let repoDict: [String: Node] = dict["repo"]?.nodeObject,
         let id = repoDict["id"]?.int,
         let name = repoDict["name"]?.string,
         let ownerDict: [String: Node] = repoDict["owner"]?.nodeObject,
         let ownerId = ownerDict["id"]?.int,
         let ownerName = ownerDict["login"]?.string,
         let forksCount = repoDict["forks"]?.int,
         let starsCount = repoDict["stargazers_count"]?.int,
         let starredAtStr = dict["starred_at"]?.string,
         let starredAt = Date.date(fromIsoString: starredAtStr) {
        if let repo = User.cachedRepo(id: id) {
          cachedRepos.append(repo)
        }
        else {
          newRepos.append(Repo(id: id, name: name, ownerId: ownerId, ownerName: ownerName,
                               forksCount: forksCount, starsCount: starsCount, starredAt: starredAt))
        }
      }
    }

    self.fetchedRepoCounts = (fetchedCount: cachedRepos.count, totalCount: dicts.count)

    let operations = newRepos.map { repo in
      return BlockOperation(block: {
        if let readmeUrl = repo.readmeUrl {
          let (data, _, _) = URLSession.shared.synchronousDataTask(with: readmeUrl,
                                                                   headers: self.authorizedRequestHeaders(with: ["Accept": "application/vnd.github.raw"]))
          
          if let stringData = data,
             let string = String(data: stringData, encoding: .utf8) {
            repo.setReadme(withMarkdown: string)
            self.fetchedRepoCounts = (fetchedCount: (self.fetchedRepoCounts.fetchedCount + 1),
                                      totalCount: self.fetchedRepoCounts.totalCount)
          }
        }
      })
    }
    
    User.slowFetchOperationQueue.addOperations(operations, waitUntilFinished: true)

    return cachedRepos + newRepos
  }
  
  private func authorizedRequestHeaders(with headers: [String: String] = [:]) -> [String: String] {
    guard let accessToken = self.accessToken else { return headers }
    
    var authorizedHeaders = headers
    
    authorizedHeaders["Authorization"] = "token \(accessToken)"
    
    return authorizedHeaders
  }
}
