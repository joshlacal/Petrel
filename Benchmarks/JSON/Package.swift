// swift-tools-version: 6.1
import PackageDescription
let package = Package(
 name: "PetrelJSONBench", platforms: [.macOS(.v15)],
 dependencies: [
  .package(name: "Petrel", path: "../.."),
  .package(url: "https://github.com/valpackett/SwiftCBOR.git", .upToNextMinor(from: "0.6.0")),
  .package(path: "Vendor/simdutf-swift", traits: ["UTF8", "UTF16", "Base64"]),
  .package(url: "https://github.com/michaeleisel/ZippyJSON.git", exact: "1.2.15")
 ],
 targets: [
  .target(name:"CJSONBridge", path:"Sources/CJSONBridge", publicHeadersPath:"include"),
  .target(name:"CBenchMetrics", dependencies:[.product(name:"SimdUTF",package:"simdutf-swift")], publicHeadersPath:"include", cxxSettings:[.headerSearchPath("../../Vendor/simdutf-swift/simdutf/include")]),
  .executableTarget(name:"PetrelJSONBench", dependencies:[
   "CBenchMetrics", "CJSONBridge",
   .product(name:"Petrel",package:"Petrel"),
   .product(name:"PetrelRepo",package:"Petrel"),
   .product(name:"SwiftCBOR",package:"SwiftCBOR"),
   .product(name:"SimdUTF",package:"simdutf-swift"),
   .product(name:"ZippyJSON",package:"ZippyJSON",condition:.when(platforms:[.macOS]))
  ], swiftSettings:[.swiftLanguageMode(.v6)])
 ], cxxLanguageStandard: .cxx17
)
