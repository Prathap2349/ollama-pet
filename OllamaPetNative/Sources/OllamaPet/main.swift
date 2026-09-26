import Foundation
import AppKit

@main
@MainActor
struct OllamaPetApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}




