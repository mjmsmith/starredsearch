import Foundation
import Vapor

#if DEBUG
  private let MaxRepoCount = 100
#else
  private let MaxRepoCount = 1000
#endif

class User {
  private static let cachedRepos = NSMapTable(keyOptions: .strongMemory, valueOptions: .weakMemory)
  private static let cachedReposQueue = dispatch_queue_create("cachedRepos", DISPATCH_QUEUE_CONCURRENT)
  
  private static func cachedRepo(id id: Int) -> Repo? {
    var cachedRepo: Repo?
    dispatch_sync(self.cachedReposQueue, { cachedRepo = self.cachedRepos.object(forKey: id) as? Repo})
    return cachedRepo
  }
  
  private static func cacheRepo(repo: Repo) {
    dispatch_barrier_sync(User.cachedReposQueue, { self.cachedRepos.setObject(repo, forKey: repo.id) })
  }
  
  private static let fetchQueue = dispatch_queue_create("", DISPATCH_QUEUE_CONCURRENT)

  private static let fetchOperationQueue: NSOperationQueue = {
    let operationQueue = NSOperationQueue()
    operationQueue.maxConcurrentOperationCount = 10
    return operationQueue
  }()
  
  enum ReposState {
    case notFetched
    case fetching
    case fetched
  }
  
  private(set) var timeStamp: NSDate {
    get {
      var value: NSDate?
      dispatch_sync(self.timeStampQueue, { value = self._timeStamp })
      return value!
    }
    
    set {
      dispatch_barrier_sync(self.timeStampQueue, { self._timeStamp = newValue })
    }
  }

  private(set) var repos: [Repo] {
    get {
      var value: [Repo]?
      dispatch_sync(self.reposQueue, { value = self._repos })
      return value!
    }
    
    set {
      dispatch_barrier_sync(self.reposQueue, { self._repos = newValue })
    }
  }

  private(set) var reposState: ReposState {
    get {
      var value: ReposState?
      dispatch_sync(self.reposStateQueue, { value = self._reposState })
      return value!
    }
    
    set {
      dispatch_barrier_sync(self.reposStateQueue, { self._reposState = newValue })
    }
  }
  
  private(set) var fetchedRepoCounts: (fetchedCount: Int, totalCount: Int) {
    get {
      var value: (fetchedCount: Int, totalCount: Int)?
      dispatch_sync(self.fetchedRepoCountsQueue, { value = self._fetchedRepoCounts })
      return value!
    }
    
    set {
      dispatch_barrier_sync(self.fetchedRepoCountsQueue, { self._fetchedRepoCounts = newValue })
    }
  }

  private var oauthToken: String?

  private let timeStampQueue = dispatch_queue_create("timeStamp", DISPATCH_QUEUE_CONCURRENT)
  private var _timeStamp = NSDate()
  
  private let reposQueue = dispatch_queue_create("repos", DISPATCH_QUEUE_CONCURRENT)
  private var _repos = [Repo]()

  private let reposStateQueue = dispatch_queue_create("reposState", DISPATCH_QUEUE_CONCURRENT)
  private var _reposState = ReposState.notFetched

  private let fetchedRepoCountsQueue = dispatch_queue_create("fetchedRepoCounts", DISPATCH_QUEUE_CONCURRENT)
  private var _fetchedRepoCounts = (fetchedCount: 0, totalCount: 0)
  
  func initializeWithCode(code: String) {
    dispatch_async(User.fetchQueue, {
      if let oauthToken = self.exchangeCodeForAccessToken(code) {
        self.oauthToken = oauthToken
        self.reposState = .fetching
        self.repos = self.fetchStarredRepos(self.fetchStarredRepoDicts())
        
        for repo in self.repos {
          User.cacheRepo(repo)
        }
      }
      
      self.reposState = .fetched
    })
  }

  func updateTimeStamp() {
    self.timeStamp = NSDate()
  }
  
  private func exchangeCodeForAccessToken(code: String) -> String? {
    var accessToken: String?
    let requestComponents = NSURLComponents.componentsWith(string: "https://github.com/login/oauth/access_token",
                                                           queryDict: [
                                                                        "client_id": GitHubClientID,
                                                                        "client_secret": GitHubClientSecret,
                                                                        "code": code
                                                                      ])!
    let operation = NSBlockOperation(block: {
      let (data, _, _) = NSURLSession.shared().synchronousDataTask(with: requestComponents.url!)
      
      if let queryData = data,
             queryString = String(data: queryData, encoding: NSUTF8StringEncoding),
             urlComponents = NSURLComponents(string: "?\(queryString)") {
        accessToken = urlComponents.queryItems?.filter({ $0.name == "access_token" }).first?.value
      }
    })
    
    User.fetchOperationQueue.addOperations([operation], waitUntilFinished: true)
    
    return accessToken
  }

  private func fetchStarredRepoDicts() -> [[String: Node]] {
    guard let _ = self.oauthToken else { return [] }
    
    var dicts = [[String: Node]]()
    var page = 1
    var perPage = 100
    
#if DEBUG
    perPage = 10
#endif
    
    repeat {
      let requestComponents = NSURLComponents.componentsWith(string: "https://api.github.com/user/starred",
                                                             queryDict: [
                                                                          "page": String(page),
                                                                          "per_page": String(perPage)
                                                                        ])!
      let operation = NSBlockOperation(block: {
        let (data, _, _) = NSURLSession.shared().synchronousDataTask(with: requestComponents.url!,
                                                                     headers: self.authorizedRequestHeaders(["Accept": "application/vnd.github.star+json"]))
        
        if let bytes = data?.arrayOfBytes(), json = try? Json(Data(bytes)), array = json.array {
          dicts += array.flatMap { $0.object }

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
      
      User.fetchOperationQueue.addOperations([operation], waitUntilFinished:true)
    } while perPage > 0
    
    return dicts
  }
  
  private func fetchStarredRepos(dicts: [[String: Node]]) -> [Repo] {
    guard let _ = self.oauthToken else { return [] }

    self.fetchedRepoCounts = (fetchedCount: 0, totalCount: dicts.count)
    
    var cachedRepos = [Repo]()
    var newRepos = [Repo]()
    
    for dict in dicts {
      if let repoDict = dict["repo"]?.object,
             id = repoDict["id"]?.int,
             name = repoDict["name"]?.string,
             ownerDict = repoDict["owner"]?.object,
             ownerId = ownerDict["id"]?.int,
             ownerName = ownerDict["login"]?.string,
             starredAtStr = dict["starred_at"]?.string,
             starredAt = NSDate.date(fromIsoString: starredAtStr) {
        if let repo = User.cachedRepo(id: id) {
          cachedRepos.append(repo)
        }
        else {
          newRepos.append(Repo(id: id, name: name, ownerId: ownerId, ownerName: ownerName, starredAt: starredAt))
        }
      }
    }

    self.fetchedRepoCounts = (fetchedCount: cachedRepos.count, totalCount: dicts.count)

    let operations = newRepos.map { repo in
      return NSBlockOperation(block: {
        if let readmeUrl = repo.readmeUrl {
          let (data, _, _) = NSURLSession.shared().synchronousDataTask(with: readmeUrl,
                                                                       headers: self.authorizedRequestHeaders(["Accept": "application/vnd.github.raw"]))
          
          if let stringData = data, string = String(data: stringData, encoding: NSUTF8StringEncoding) {
            repo.setReadme(withMarkdown: string)
            self.fetchedRepoCounts = (fetchedCount: (self.fetchedRepoCounts.fetchedCount + 1),
                                      totalCount: self.fetchedRepoCounts.totalCount)
          }
        }
      })
    }
    
    User.fetchOperationQueue.addOperations(operations, waitUntilFinished: true)

    return cachedRepos + newRepos
  }
  
  private func authorizedRequestHeaders(headers: [String:String] = [:]) -> [String:String] {
    guard let oauthToken = self.oauthToken else { return headers }
    
    var authorizedHeaders = headers
    
    authorizedHeaders["Authorization"] = "token \(oauthToken)"
    
    return authorizedHeaders
  }
}
