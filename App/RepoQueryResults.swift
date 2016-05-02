import Foundation

struct RepoQueryResults {
  let repo: Repo
  let count: Int
  let htmls: [String]
  
  static func isOrderedBefore(left: RepoQueryResults, right: RepoQueryResults) -> Bool {
    return self.countIsOrderedBefore(left, right)
  }

  private static func countIsOrderedBefore(left: RepoQueryResults, _ right: RepoQueryResults) -> Bool {
    return left.count != right.count ? (left.count < right.count) : self.repoNameIsOrderedBefore(left, right)
  }
  
  private static func starredAtIsOrderedBefore(left: RepoQueryResults, _ right: RepoQueryResults) -> Bool {
    let result = left.repo.starredAt.compare(right.repo.starredAt)
    
    return result != .orderedSame ? (result == .orderedAscending) : self.repoNameIsOrderedBefore(left, right)
  }
  
  private static func repoNameIsOrderedBefore(left: RepoQueryResults, _ right: RepoQueryResults) -> Bool {
    let leftName = left.repo.name.lowercased()
    let rightName = right.repo.name.lowercased()
    
    return leftName != rightName ? (leftName < rightName) : self.ownerNameIsOrderedBefore(left, right)
  }
  
  private static func ownerNameIsOrderedBefore(left: RepoQueryResults, _ right: RepoQueryResults) -> Bool {
    let leftName = left.repo.ownerName.lowercased()
    let rightName = right.repo.ownerName.lowercased()
    
    return leftName != rightName ? (leftName < rightName) : (left.repo.id < right.repo.id)
  }
  
}