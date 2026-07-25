import Foundation
import Cocoa
import CoreGraphics

// Activate app
let apps = NSWorkspace.shared.runningApplications.filter { $0.localizedName == "MacCleanOptimizer" }
if let app = apps.first {
    app.activate(options: [.activateIgnoringOtherApps])
}

Thread.sleep(forTimeInterval: 0.8)

let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []

for win in windowList {
    if let ownerName = win[kCGWindowOwnerName as String] as? String, ownerName == "MacCleanOptimizer",
       let boundsDict = win[kCGWindowBounds as String] as? [String: Any],
       let x = boundsDict["X"] as? Int,
       let y = boundsDict["Y"] as? Int,
       let width = boundsDict["Width"] as? Int,
       let height = boundsDict["Height"] as? Int, width > 300 && height > 300 {
        print("\(x),\(y),\(width),\(height)")
        exit(0)
    }
}
print("not_found")
