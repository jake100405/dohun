import SwiftUI
import WidgetKit
import ActivityKit
@main struct StudyWidgets: WidgetBundle {
    var body: some Widget { StudyLiveActivity() }
}
struct StudyLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: StudyActivity.self) { context in
            StudyCard(state:context.state,stale:context.isStale)
                .activityBackgroundTint(cardColor(context.state.theme))
                .activitySystemActionForegroundColor(.black)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) { StudyCard(state:context.state,stale:context.isStale) }
            } compactLeading: { Text("공부") }
              compactTrailing: { Text(Study.marks[context.state.marks[context.state.index]] ?? "·") }
              minimal: { Text("○") }
        }
    }
}
struct StudyCard: View {
    var state:StudyActivity.ContentState
    var stale:Bool
    private var locked:Bool { state.locks[state.index] }
    var body: some View {
        VStack(spacing:7) {
            HStack {
                Text("하루한칸 · \(state.date)").font(.caption2).foregroundStyle(.secondary)
                Spacer()
                Text(stale ? "앱에서 다시 시작" : "\(state.index+1)/11").font(.caption2)
            }
            HStack {
                action("previous",label:"◀")
                Spacer()
                Text(Study.subjects[state.index]).font(.headline)
                Text(locked ? "✓ 완료" : Study.marks[state.marks[state.index]] ?? "·").font(.headline)
                Spacer()
                action("next",label:"▶")
            }
            HStack {
                if !locked {action("minus5",label:"−5분")}
                Text("\(state.minutes?[state.index] ?? 0)분").font(.caption)
                if !locked {action("plus5",label:"+5분")}
                Link("메모 편집",destination:URL(string:"haruhankan-native://edit?index=\(state.index)")!).font(.caption)
            }
            if let notes=state.notes,!notes[state.index].isEmpty {Text(notes[state.index]).font(.caption).lineLimit(1)}
            HStack(spacing:6) {
                if locked {
                    Text("이번 주 완료 · 입력 잠김").font(.caption).frame(maxWidth:.infinity)
                    action("unlock",label:"완료 해제")
                } else {
                    action("o",label:"○");action("t",label:"△");action("x",label:"×");action("done",label:"완료")
                }
            }
        }.padding(12).foregroundStyle(Color(red:0.15,green:0.24,blue:0.20)).disabled(stale)
    }
    private func action(_ key:String,label:String) -> some View {
        Button(intent:StudyActionIntent(key,index:state.index,date:state.date)) {
            Text(label).font(.system(size:16,weight:.semibold)).frame(maxWidth:.infinity,minHeight:34)
                .padding(.horizontal,6).background(.black.opacity(0.06)).clipShape(RoundedRectangle(cornerRadius:9))
        }.buttonStyle(.plain).accessibilityLabel((key == "previous" ? "이전 과목" : key == "next" ? "다음 과목" : label))
    }
}

func cardColor(_ theme:String?)->Color {switch theme {case "blue":return Color(red:0.82,green:0.90,blue:0.98);case "pink":return Color(red:0.98,green:0.85,blue:0.90);case "cream":return Color(red:0.98,green:0.94,blue:0.80);default:return Color(red:0.86,green:0.94,blue:0.86)}}
