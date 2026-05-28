#if os(iOS)
import ActivityKit
import Foundation

@MainActor
final class LiveActivityManager {
    static let shared = LiveActivityManager()

    private var currentActivity: Activity<ReadingTimerAttributes>?

    private init() {}

    var isActive: Bool { currentActivity != nil }

    func request(attributes: ReadingTimerAttributes, contentState: ReadingTimerAttributes.ContentState) {
        end()

        let content = ActivityContent(state: contentState, staleDate: nil)
        do {
            currentActivity = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
        } catch {
            print("LiveActivityManager: Failed to request activity: \(error)")
        }
    }

    func update(contentState: ReadingTimerAttributes.ContentState) {
        guard let activity = currentActivity else { return }
        Task {
            await activity.update(ActivityContent(state: contentState, staleDate: nil))
        }
    }

    func end(contentState: ReadingTimerAttributes.ContentState? = nil) {
        guard let activity = currentActivity else { return }
        let finalContent = contentState.map { ActivityContent(state: $0, staleDate: nil) }
        Task {
            await activity.end(finalContent, dismissalPolicy: .immediate)
        }
        currentActivity = nil
    }
}
#endif
