import AppIntents
import ActivityKit
// LiveActivityIntent runs in the containing app process; the widget renders ContentState.
// No App Groups, iCloud, APNs, or paid entitlement is requested.
struct StudyActionIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "공부 빠른 입력"
    static var openAppWhenRun: Bool = false
    @Parameter(title: "동작") var action: String
    @Parameter(title: "과목") var subjectIndex: Int
    @Parameter(title: "기록 날짜") var expectedDate: String
    init() { action = "next"; subjectIndex = 0; expectedDate = "" }
    init(_ action: String, index: Int, date: String) {
        self.action = action; self.subjectIndex = index; self.expectedDate = date
    }
    func perform() async throws -> some IntentResult {
        await CloudSync.flush()
        do {
            try await MainActor.run { try StudyStore.shared.act(action, index: subjectIndex, expectedDate: expectedDate) }
        } catch {
            await ActivityController.refresh(); throw error
        }
        await ActivityController.refresh()
        await CloudSync.flush()
        return .result()
    }
}
