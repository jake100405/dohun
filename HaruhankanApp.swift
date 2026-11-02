import SwiftUI
import ActivityKit
@main struct HaruhankanApp: App {
    var body: some Scene {
        WindowGroup { StudyHome() }
    }
}
@MainActor struct StudyHome: View {
    @ObservedObject private var store = StudyStore.shared
    @Environment(\.openURL) private var openURL
    @State private var message: String?
    @State private var pendingImport: Data?
    private let green = Color(red:0.25,green:0.40,blue:0.31)
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment:.leading,spacing:20) {
                    Text("오늘의 공부를, 잠금화면에서도.").font(.title2.bold())
                    Text("무료 설치 시험판 · iOS 17 이상").font(.caption).foregroundStyle(.secondary)
                    Button("공부 시작 · 잠금화면 카드 켜기") { Task { do { try await ActivityController.start() } catch { message = error.localizedDescription } } }
                        .buttonStyle(.borderedProminent).tint(green)
                    Button("잠금화면 카드 종료") { Task { await ActivityController.end() } }.font(.caption)
                    Text("카드의 ◀ ▶로 과목을 고르고 ○·△·×·완료를 눌러요. 완료한 과목은 색칠되고 입력이 잠겨요. Face ID 인증이 필요할 수 있어요. 실시간 현황은 최대 8시간 활성화되므로 공부할 때 다시 켜 주세요.")
                        .font(.footnote).foregroundStyle(.secondary)
                    ForEach(Array(Study.subjects.enumerated()),id:\.offset) { index,subject in
                        let locked = store.isLocked(subject)
                        HStack {
                            Button { perform { try store.select(index) } } label: {
                                HStack {
                                    Image(systemName:store.state.selected == index ? "circle.inset.filled" : "circle")
                                    Text(subject).fontWeight(.semibold)
                                    Spacer()
                                    Text(locked ? "✓ 완료" : Study.marks[store.state.entries[Study.day()]?[subject] ?? "-"] ?? "·")
                                }
                            }.buttonStyle(.plain)
                            if locked { Button("해제") { act("unlock",index) }.font(.caption) }
                        }.padding(12).background(locked ? green.opacity(0.16) : Color.secondary.opacity(0.07)).clipShape(RoundedRectangle(cornerRadius:12))
                    }
                    HStack {
                        ForEach(["o","t","x","done"],id:\.self) { action in
                            Button(action == "done" ? "완료" : Study.marks[action]!) { act(action,store.state.selected) }
                                .buttonStyle(.bordered).disabled(store.isLocked(Study.subjects[store.state.selected]))
                        }
                    }
                    Divider()
                    Text("사이트와 수동으로 기록 맞추기").font(.headline)
                    Text("미전송 \(store.state.pending.count)개").font(.caption)
                    Button("사이트에 기록 반영") {
                        do { openURL(try store.exportURL()) } catch { message = store.state.pending.isEmpty ? "보낼 기록이 없어요." : error.localizedDescription }
                    }.disabled(store.state.pending.isEmpty)
                    Link("기존 공부·운동 사이트 열기",destination:URL(string:Study.site)!)
                    Text("사이트에서 내용 확인 후 기록 반영을 누르고, 위젯 연결의 iOS 시험판으로 보내기를 눌러 수신을 확인해요. Safari와 홈 화면 앱은 저장 공간이 다를 수 있으니 기록하던 쪽에서 반영해 주세요.")
                        .font(.footnote).foregroundStyle(.secondary)
                    if let error = store.loadError { Text(error).foregroundStyle(.red) }
                }.padding()
            }.navigationTitle("하루한칸")
             .alert("안내",isPresented:Binding(get:{message != nil},set:{if !$0 {message = nil}})) { Button("확인"){message=nil} } message:{Text(message ?? "")}
             .onOpenURL { url in
                 guard url.scheme == "haruhankan-native", url.host == "import",
                       let raw = URLComponents(url:url,resolvingAgainstBaseURL:false)?.queryItems?.first(where:{$0.name == "payload"})?.value,
                       let d = raw.data(using:.utf8) else {return}
                 pendingImport=d
             }
             .confirmationDialog("사이트 기록을 가져올까요? 미전송 입력은 유지돼요.",isPresented:Binding(get:{pendingImport != nil},set:{if !$0 {pendingImport=nil}}),titleVisibility:.visible, presenting:pendingImport) { d in
                 Button("가져오기") { perform { try store.importWeb(d) };pendingImport=nil }
                 Button("취소",role:.cancel){pendingImport=nil}
             }
        }
    }
    private func act(_ action:String,_ index:Int) { perform { try store.act(action,index:index,expectedDate:Study.day()) } }
    private func perform(_ action:() throws -> Void) {
        do { try action();Task {await ActivityController.refresh()} } catch {message=error.localizedDescription}
    }
}
