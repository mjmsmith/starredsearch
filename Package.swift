import PackageDescription

let package = Package(
  name: "VaporApp",
  dependencies: [
    .Package(url: "https://github.com/qutheory/vapor-mustache.git", majorVersion: 0, minor: 6)
  ],
  exclude: [
    "Config",
    "Deploy",
    "Public",
    "Resources",
    "Tests",
    "Database"
  ]
)
