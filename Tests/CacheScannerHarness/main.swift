import Foundation

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

let fm = FileManager.default
let root = fm.homeDirectoryForCurrentUser
    .appending(path: "Library/Caches/YuJiBuild/Tests/YuJiCacheTests-\(UUID().uuidString)")
let cacheRoot = root.appending(path: "Caches")
let residueRoot = root.appending(path: "Residues")
defer {
    unsetenv("YUJI_CACHE_SCAN_ROOT")
    unsetenv("YUJI_SCAN_ROOT")
    try? fm.removeItem(at: root)
}

try fm.createDirectory(at: cacheRoot.appending(path: "com.example.largecache"), withIntermediateDirectories: true)
try fm.createDirectory(at: cacheRoot.appending(path: "com.apple.Safari"), withIntermediateDirectories: true)
try fm.createDirectory(at: cacheRoot.appending(path: "tiny.cache"), withIntermediateDirectories: true)
try fm.createDirectory(at: residueRoot, withIntermediateDirectories: true)
let safeResidue = residueRoot.appending(path: "com.example.safeold")
let sensitiveResidue = residueRoot.appending(path: "com.example.profileold")
let mergedSafePeer = residueRoot.appending(path: "org.example.profileold")
try fm.createDirectory(at: safeResidue, withIntermediateDirectories: true)
try fm.createDirectory(at: sensitiveResidue.appending(path: "Bookmarks"), withIntermediateDirectories: true)
try fm.createDirectory(at: mergedSafePeer, withIntermediateDirectories: true)

try Data(repeating: 1, count: 2 * 1024 * 1024)
    .write(to: cacheRoot.appending(path: "com.example.largecache/payload.bin"))
try Data(repeating: 1, count: 2 * 1024 * 1024)
    .write(to: cacheRoot.appending(path: "com.apple.Safari/protected.bin"))
try Data(repeating: 1, count: 512 * 1024)
    .write(to: cacheRoot.appending(path: "tiny.cache/small.bin"))
try Data(repeating: 1, count: 2 * 1024 * 1024)
    .write(to: safeResidue.appending(path: "payload.bin"))
try Data(repeating: 1, count: 2 * 1024 * 1024)
    .write(to: sensitiveResidue.appending(path: "Bookmarks/data.bin"))
try Data(repeating: 1, count: 2 * 1024 * 1024)
    .write(to: mergedSafePeer.appending(path: "payload.bin"))

let oldDate = Date().addingTimeInterval(-400 * 24 * 60 * 60)
try fm.setAttributes([.modificationDate: oldDate], ofItemAtPath: safeResidue.path)
try fm.setAttributes([.modificationDate: oldDate], ofItemAtPath: sensitiveResidue.path)
try fm.setAttributes([.modificationDate: oldDate], ofItemAtPath: mergedSafePeer.path)

setenv("YUJI_CACHE_SCAN_ROOT", cacheRoot.path, 1)
setenv("YUJI_SCAN_ROOT", residueRoot.path, 1)

let output = ResidueScanner.scan()
let caches = output.results.filter { $0.kind == .cache }

require(caches.count == 1, "expected exactly one eligible cache")
require(caches.first?.bundleHint == "com.example.largecache", "large third-party cache was not detected")
require(caches.first?.totalSize ?? 0 >= 1024 * 1024, "cache size was not measured")
require(!output.results.contains { $0.bundleHint == "com.apple.Safari" }, "protected Apple cache was included")
require(!output.results.contains { $0.bundleHint == "tiny.cache" }, "cache below 1 MB was included")

let safeResult = output.results.first { $0.bundleHint == "com.example.safeold" }
require(safeResult?.risk == .high, "old non-sensitive residue was not classified as safe to review for cleanup")
let sensitiveResult = output.results.first { result in
    result.paths.contains { URL(fileURLWithPath: $0.path).lastPathComponent == "com.example.profileold" }
}
require(sensitiveResult?.containsSensitiveData == true, "sensitive residue content was not detected")
require(sensitiveResult?.risk == .review, "sensitive residue was allowed into suggested cleanup")
require(sensitiveResult?.paths.count == 2, "matching residue paths were not merged")
require(output.inspectedLocations >= 5, "scan coverage metrics were not recorded")
require(output.protectedCandidates >= 1, "protected candidate metrics were not recorded")

let approved = fm.homeDirectoryForCurrentUser.appending(path: "Library/Caches/com.example.cache").path
require(SafetyPolicy.isApprovedUserCachePath(approved), "valid user cache path was rejected")
require(!SafetyPolicy.isApprovedUserCachePath("/Library/Caches/com.example.cache"), "system cache path was allowed")
require(!SafetyPolicy.isApprovedUserCachePath("/tmp/com.example.cache"), "path outside user caches was allowed")
require(!SafetyPolicy.isApprovedResiduePath(residueRoot.path), "unapproved residue root was allowed")
require(SafetyPolicy.isProtectedPath("/var/db/example"), "symlinked private system path was not protected")
require(
    SafetyPolicy.isApprovedResiduePath(fm.homeDirectoryForCurrentUser.appending(path: "Library/Logs/com.example.old").path),
    "known residue location was rejected"
)
require(
    !SafetyPolicy.isApprovedUserCachePath(fm.homeDirectoryForCurrentUser.appending(path: "Library/Caches/com.apple.Safari").path),
    "protected Apple cache path was allowed"
)

let routineRoots = ResidueScanner.defaultScanRoots(home: fm.homeDirectoryForCurrentUser).map(\.0.path)
require(!routineRoots.contains { $0.contains("/Library/Containers") }, "routine scan enters private app containers")
require(!routineRoots.contains { $0.contains("/Library/Group Containers") }, "routine scan enters private app group containers")

print("PASS: expanded discovery, batched sizing, sensitive-data protection, cleanup boundaries, and private-container exclusion")
