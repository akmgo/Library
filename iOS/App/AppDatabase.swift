import Foundation
import SwiftData

enum AppDatabase {
    static let container: ModelContainer = {
        let schema = Schema([
            Book.self,
            ReadingLog.self,
            BookText.self
        ])

        let configuration = ModelConfiguration(schema: schema)

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            let fallback = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            do {
                return try ModelContainer(for: schema, configurations: [fallback])
            } catch {
                fatalError("ModelContainer failed: \(error.localizedDescription)")
            }
        }
    }()
}
