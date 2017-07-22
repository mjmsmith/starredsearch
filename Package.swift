import PackageDescription

let package = Package(
  name: "VaporApp",
  dependencies: [
    .Package(url: "https://github.com/qutheory/vapor.git", majorVersion: 2),
    .Package(url: "https://github.com/vapor/leaf-provider.git", majorVersion: 1)
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
