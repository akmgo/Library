import SwiftData
import SwiftUI

@main
struct LibraryApp: App {
    var body: some Scene {
        WindowGroup {
            AppRootView()
                .modelContainer(AppDatabase.container)
        }
    }
}
