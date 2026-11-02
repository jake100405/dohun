import Foundation
import Combine
enum Study {
    static let subjects = ["대수A","대수B","미적분A","미적분B","물리학","화학","생명과학","지구과학","국어","영어","정보"]
    static let marks = ["o":"○","t":"△","x":"×","-":"·"]
    static let site = "https://dohun-study-week-1101.kkddhh0405.chatgpt.site/"
    static func day(_ date: Date = Date()) -> String {
        let f = DateFormatter(); f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX"); f.timeZone = .current; f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }
    static func date(_ key: String) throws -> Date {
        let f = DateFormatter(); f.calendar = Calendar(identifier: .gregorian); f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current; f.dateFormat = "yyyy-MM-dd"; f.isLenient = false
        guard key.count == 10, let d = f.date(from: key), day(d) == key else { throw StudyError.invalid }
        return d
    }
    static func week(_ key: String) throws -> String {
        let d = try date(key); let c = Calendar.current
        return day(c.date(byAdding: .day, value: -((c.component(.weekday, from: d)+5)%7), to: d)!)
    }
}
enum StudyError: LocalizedError {
    case invalid, locked, full, stale, corrupt
    var errorDescription: String? {
        switch self {
        case .invalid: return "기록 형식을 확인해 주세요."
        case .locked: return "이번 주 완료한 과목이에요. 완료를 해제해 주세요."
        case .full: return "미전송 기록이 200개예요. 먼저 사이트에 반영해 주세요."
        case .stale: return "날짜가 바뀌었어요. 카드를 새로 확인하고 다시 입력해 주세요."
        case .corrupt: return "저장 파일을 읽지 못해 덮어쓰지 않았어요."
        }
    }
}
struct QuickOp: Codable, Hashable, Sendable {
    var id: String; var date: String; var subject: String; var kind: String
    var mark: String?; var lock: Bool?
    init(date: String, subject: String, mark: String) {
        id = "ios-" + UUID().uuidString; self.date = date; self.subject = subject; kind = "mark"; self.mark = mark
    }
    init(date: String, subject: String, lock: Bool) {
        id = "ios-" + UUID().uuidString; self.date = date; self.subject = subject; kind = "lock"; self.lock = lock
    }
    enum CodingKeys: String, CodingKey { case id,date,subject,kind,value }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id); date = try c.decode(String.self, forKey: .date)
        subject = try c.decode(String.self, forKey: .subject); kind = try c.decode(String.self, forKey: .kind)
        if kind == "lock" { lock = try c.decode(Bool.self, forKey: .value) }
        else if kind == "mark" { mark = try c.decode(String.self, forKey: .value) }
        else { throw StudyError.invalid }
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id); try c.encode(date, forKey: .date); try c.encode(subject, forKey: .subject); try c.encode(kind, forKey: .kind)
        if kind == "lock" { try c.encode(lock ?? false, forKey: .value) }
        else { try c.encode(mark ?? "-", forKey: .value) }
    }
}
struct SavedStudy: Codable {
    var entries: [String:[String:String]] = [:]
    var completed: [String:[String]] = [:]
    var pending: [QuickOp] = []
    var selected: Int = 0
}
struct WebPayload: Decodable {
    struct Week: Decodable { var start: String; var done: String; var grid: [String] }
    var v: Int; var updatedAt: String; var labels: [String]; var weeks: [Week]; var receipts: [String]?
}
@MainActor final class StudyStore: ObservableObject {
    static let shared = StudyStore()
    @Published private(set) var state = SavedStudy()
    @Published private(set) var loadError: String?
    private let key = "HaruhankanFree.state.v1"
    init() {
        if let d = UserDefaults.standard.data(forKey: key) {
            do { let s = try JSONDecoder().decode(SavedStudy.self, from: d)
                guard (0..<11).contains(s.selected), s.pending.count <= 200 else { throw StudyError.corrupt }
                state = s
            } catch { loadError = StudyError.corrupt.localizedDescription }
        }
    }
    private func save(_ next: SavedStudy) throws {
        guard loadError == nil else { throw StudyError.corrupt }
        let d = try JSONEncoder().encode(next)
        UserDefaults.standard.set(d, forKey: key); state = next
    }
    func isLocked(_ subject: String, on date: String = Study.day()) -> Bool {
        guard let week = try? Study.week(date) else { return true }
        return state.completed[week,default:[]].contains(subject)
    }
    private func apply(_ op: QuickOp, to s: inout SavedStudy) throws {
        if op.kind == "lock" {
            let week = try Study.week(op.date); var set = Set(s.completed[week,default:[]])
            if op.lock == true { set.insert(op.subject) } else { set.remove(op.subject) }
            s.completed[week] = Study.subjects.filter { set.contains($0) }
        } else if op.mark == "-" { s.entries[op.date]?.removeValue(forKey: op.subject) }
        else { s.entries[op.date,default:[:]][op.subject] = op.mark }
    }
    func act(_ action: String, index: Int, expectedDate: String) throws {
        guard loadError == nil else { throw StudyError.corrupt }
        guard (0..<11).contains(index) else { throw StudyError.invalid }
        guard expectedDate == Study.day() else { throw StudyError.stale }
        var s = state
        if action == "previous" || action == "next" {
            s.selected = (index + (action == "next" ? 1 : 10)) % 11; try save(s); return
        }
        guard s.pending.count < 200 else { throw StudyError.full }
        let subject = Study.subjects[index]; let op: QuickOp
        if action == "done" || action == "unlock" {
            op = QuickOp(date: expectedDate, subject: subject, lock: action == "done")
        } else {
            guard ["o","t","x","-"].contains(action) else { throw StudyError.invalid }
            guard !isLocked(subject, on: expectedDate) else { throw StudyError.locked }
            op = QuickOp(date: expectedDate, subject: subject, mark: action)
        }
        try apply(op, to: &s); s.pending.append(op); s.selected = index; try save(s)
    }
    func select(_ index: Int) throws {
        guard (0..<11).contains(index) else { throw StudyError.invalid }
        var s = state; s.selected = index; try save(s)
    }
    func importWeb(_ data: Data) throws {
        guard data.count <= 60000 else { throw StudyError.invalid }
        let p = try JSONDecoder().decode(WebPayload.self, from: data)
        guard p.v == 2, p.weeks.count <= 30, p.labels.count == 3 else { throw StudyError.invalid }
        var s = state
        for w in p.weeks {
            let start = try Study.date(w.start)
            guard try Study.week(w.start) == w.start, w.done.count == 11,
                  w.done.allSatisfy({ "01".contains($0) }), w.grid.count == 7 else { throw StudyError.invalid }
            s.completed[w.start] = Study.subjects.enumerated().compactMap { Array(w.done)[$0.offset] == "1" ? $0.element : nil }
            for day in 0..<7 {
                let row = Array(w.grid[day])
                guard row.count == 11, row.allSatisfy({ "otsx-".contains($0) }) else { throw StudyError.invalid }
                let date = Study.day(Calendar.current.date(byAdding: .day, value: day, to: start)!)
                var entries: [String:String] = [:]
                for i in 0..<11 where row[i] != "-" { entries[Study.subjects[i]] = row[i] == "s" ? "x" : String(row[i]) }
                s.entries[date] = entries
            }
        }
        let receipts = Set(p.receipts ?? []); s.pending.removeAll { receipts.contains($0.id) }
        for op in s.pending { try apply(op, to: &s) }
        try save(s)
    }
    func exportURL() throws -> URL {
        guard !state.pending.isEmpty else { throw StudyError.invalid }
        struct Packet: Encodable { var v = 1; var ops: [QuickOp] }
        let d = try JSONEncoder().encode(Packet(ops: Array(state.pending.prefix(50))))
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))
        guard let str = String(data: d, encoding: .utf8)?.addingPercentEncoding(withAllowedCharacters: allowed),
              let url = URL(string: Study.site + "#widget-edits=" + str) else { throw StudyError.invalid }
        return url
    }
}
