import Foundation
import ActivityKit
struct StudyActivity: ActivityAttributes {
    struct ContentState: Codable, Hashable, Sendable {
        var date: String; var index: Int; var marks: [String]; var locks: [Bool]
    }
    var name: String
}
@MainActor enum ActivityController {
    static func snapshot() -> StudyActivity.ContentState {
        let store = StudyStore.shared; let day = Study.day()
        return .init(date: day, index: store.state.selected,
                     marks: Study.subjects.map { store.state.entries[day]?[$0] ?? "-" },
                     locks: Study.subjects.map { store.isLocked($0, on: day) })
    }
    static func refresh() async {
        let content = ActivityContent(state: snapshot(), staleDate: nil)
        for activity in Activity<StudyActivity>.activities { await activity.update(content) }
    }
    static func start() async throws {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            throw NSError(domain: "Haruhankan", code: 1, userInfo: [NSLocalizedDescriptionKey:"설정에서 하루한칸의 실시간 현황을 허용해 주세요."])
        }
        await end()
        _ = try Activity.request(attributes: StudyActivity(name: "하루한칸"),
                                 content: ActivityContent(state: snapshot(), staleDate: nil), pushType: nil)
    }
    static func end() async {
        for activity in Activity<StudyActivity>.activities { await activity.end(nil, dismissalPolicy: .immediate) }
    }
}
