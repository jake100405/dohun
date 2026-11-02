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
    @State private var editing=false
    @State private var minutes=""
    @State private var note=""
    @State private var message: String?
    @State private var pendingImport: Data?
    @State private var pendingPair: String?
    @Environment(\.scenePhase) private var scenePhase
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
                    Button("선택 과목 시간·메모 편집") {beginEdit()}
                    Picker("잠금화면 카드 색",selection:Binding(get:{store.state.theme ?? "green"},set:{value in perform{try store.setTheme(value)}})) {
                        Text("초록").tag("green");Text("파랑").tag("blue");Text("분홍").tag("pink");Text("크림").tag("cream")
                    }.pickerStyle(.segmented)
                    Divider()
                    Text("사이트 ↔ 잠금화면 동기화").font(.headline)
                    Text(store.cloudMessage).font(.footnote).foregroundStyle(.secondary)
                    Link("사이트에서 자동 반영 연결",destination:URL(string:Study.site+"index.html?connect=1")!)
                    Button("지금 동기화") { Task { await CloudSync.flush() } }
                    Button("자동 전송 연결 해제") { CloudSync.disconnect() }.font(.caption)
                    Text("한 번 연결하면 잠금화면 입력 후 서버에 전송해요. 사이트는 열려 있을 때 약 15초마다, 다시 열 때도 받아와요. 인터넷이 없으면 기기에 보관하며 다음 입력이나 앱을 열 때 다시 보내요. 사이트의 변경은 앱을 열거나 잠금화면 버튼을 누를 때 받아와요.").font(.footnote).foregroundStyle(.secondary)
                    Divider()
                    Text("수동으로 기록 보내기").font(.headline)
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
             .sheet(isPresented:$editing){NavigationStack {Form {Text(Study.subjects[store.state.selected]);TextField("공부 시간(분)",text:$minutes).keyboardType(.numberPad);TextField("짧은 메모",text:$note,axis:.vertical)}.navigationTitle("시간·메모").toolbar {Button("저장"){if !minutes.isEmpty && Int(minutes)==nil {message="분 단위 숫자를 입력해 주세요.";return};perform{try store.editDetail(index:store.state.selected,date:Study.day(),minutes:minutes.isEmpty ? nil : Int(minutes),note:note)};editing=false}}}}
             .task { while !Task.isCancelled {await CloudSync.flush();try? await Task.sleep(for:.seconds(15))} }
             .onChange(of: scenePhase) { _,phase in if phase == .active { Task { await CloudSync.flush() } } }
             .confirmationDialog("이 사이트에 공부 기록을 자동 전송할까요?",isPresented:Binding(get:{pendingPair != nil},set:{if !$0 {pendingPair=nil}}),titleVisibility:.visible) {
                 Button("자동 전송 연결") { if let token=pendingPair { do { try CloudSync.connect(token);Task { await CloudSync.flush() } } catch { message=error.localizedDescription } };pendingPair=nil }
                 Button("취소",role:.cancel){pendingPair=nil}
             } message: { Text("하루한칸 사이트의 로그인 계정에 ○·△·×·시간·메모·완료 기록을 서로 동기화해요.") }
             .onOpenURL { url in
                 if url.scheme=="haruhankan-native",url.host=="edit",let value=URLComponents(url:url,resolvingAgainstBaseURL:false)?.queryItems?.first(where:{$0.name=="index"})?.value,let index=Int(value),(0..<11).contains(index){try? store.select(index);beginEdit();return}
                 if url.scheme == "haruhankan-native",url.host == "pair",let token=URLComponents(url:url,resolvingAgainstBaseURL:false)?.queryItems?.first(where:{$0.name == "token"})?.value,token.range(of:"^[a-f0-9]{64}$",options:.regularExpression) != nil {pendingPair=token;return}
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
    private func beginEdit(){let detail=store.state.details?[Study.day()]?[Study.subjects[store.state.selected]];minutes=detail?.minutes.map(String.init) ?? "";note=detail?.note ?? "";editing=true}
    private func act(_ action:String,_ index:Int) { perform { try store.act(action,index:index,expectedDate:Study.day()) } }
    private func perform(_ action:() throws -> Void) {
        do { try action();Task {await ActivityController.refresh();await CloudSync.flush()} } catch {message=error.localizedDescription}
    }
}
