import Foundation

struct RepoQueryResults {
  enum SortOrder: String {
    case count
    case starred
    case name
    case owner
  }
  
  let repo: Repo
  let count: Int
  let htmls: [String]
  
  static func sorted(results: [RepoQueryResults], by sortOrder: SortOrder) -> [RepoQueryResults] {
    switch sortOrder {
      case .count:
        return results.sorted(isOrderedBefore: self.countIsOrderedBefore).reversed()
      case .starred:
        return results.sorted(isOrderedBefore: self.starredAtIsOrderedBefore).reversed()
      case .name:
        return results.sorted(isOrderedBefore: self.repoNameIsOrderedBefore)
      case .owner:
        return results.sorted(isOrderedBefore: self.ownerNameIsOrderedBefore)
    }
  }

  private static func countIsOrderedBefore(_ left: RepoQueryResults, _ right: RepoQueryResults) -> Bool {
    return left.count != right.count ? (left.count < right.count) : self.repoNameIsOrderedBefore(left, right)
  }
  
  private static func starredAtIsOrderedBefore(_ left: RepoQueryResults, _ right: RepoQueryResults) -> Bool {
    let result = left.repo.starredAt.compare(right.repo.starredAt)
    
    return result != .orderedSame ? (result == .orderedAscending) : self.repoNameIsOrderedBefore(left, right)
  }
  
  private static func repoNameIsOrderedBefore(_ left: RepoQueryResults, _ right: RepoQueryResults) -> Bool {
    let leftName = left.repo.name.lowercased()
    let rightName = right.repo.name.lowercased()
    
    return leftName != rightName ? (leftName < rightName) : self.ownerNameIsOrderedBefore(left, right)
  }
  
  private static func ownerNameIsOrderedBefore(_ left: RepoQueryResults, _ right: RepoQueryResults) -> Bool {
    let leftName = left.repo.ownerName.lowercased()
    let rightName = right.repo.ownerName.lowercased()
    
    return leftName != rightName ? (leftName < rightName) : (left.repo.id < right.repo.id)
  }
}