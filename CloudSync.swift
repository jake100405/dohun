import Foundation
import Security

// Tokens are provisioned by the signed-in Site and stored only in the device Keychain.
@MainActor enum CloudSync {
    private static let service = "com.dohun.haruhankan.cloud.v1"
    private static var sending = false
    private static var token: String? {
        let query: [String:Any] = [kSecClass as String:kSecClassGenericPassword,
            kSecAttrService as String:service, kSecAttrAccount as String:"sync",
            kSecReturnData as String:true, kSecMatchLimit as String:kSecMatchLimitOne]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary,&result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data:data,encoding:.utf8)
    }
    static var isLinked: Bool { token != nil }
    static func connect(_ value:String) throws {
        guard value.range(of:"^[a-f0-9]{64}$",options:.regularExpression) != nil else { throw StudyError.invalid }
        let query:[String:Any] = [kSecClass as String:kSecClassGenericPassword,
            kSecAttrService as String:service,kSecAttrAccount as String:"sync"]
        let attributes:[String:Any] = [kSecValueData as String:Data(value.utf8),
            kSecAttrAccessible as String:kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly]
        let status=SecItemUpdate(query as CFDictionary,attributes as CFDictionary)
        if status == errSecItemNotFound {
            guard SecItemAdd(query.merging(attributes){_,v in v} as CFDictionary,nil) == errSecSuccess else {throw StudyError.invalid}
        } else if status != errSecSuccess { throw StudyError.invalid }
        try StudyStore.shared.resetCloudCursor()
        StudyStore.shared.cloudMessage="연결됨 · 입력을 전송할 준비가 됐어요."
    }
    static func disconnect() {
        let query:[String:Any] = [kSecClass as String:kSecClassGenericPassword,kSecAttrService as String:service,kSecAttrAccount as String:"sync"]
        SecItemDelete(query as CFDictionary)
        StudyStore.shared.cloudMessage="자동 전송 연결 해제됨 · 기록은 기기에 유지돼요."
    }
    static func flush() async {
        guard !sending,let credential=token else{return}
        sending=true;defer{sending=false}
        let store=StudyStore.shared
        guard store.loadError == nil else{return}
        let config=URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest=8;config.timeoutIntervalForResource=12
        let session=URLSession(configuration:config);defer{session.invalidateAndCancel()}
        do {
            // A bounded queue persists first; acknowledgement removes only the submitted IDs.
            for _ in 0..<4 {
                let ops=Array(store.state.pending.prefix(50))
                if ops.isEmpty {break}
                struct Packet:Encodable{let v=1;let ops:[QuickOp]}
                struct Receipt:Decodable{let receipts:[String]}
                var request=URLRequest(url:URL(string:Study.site+"api/sync")!)
                request.httpMethod="POST";request.setValue("Bearer "+credential,forHTTPHeaderField:"Authorization")
                request.setValue("application/json",forHTTPHeaderField:"Content-Type")
                request.httpBody=try JSONEncoder().encode(Packet(ops:ops))
                let (data,response)=try await session.data(for:request)
                guard let http=response as? HTTPURLResponse else{throw URLError(.badServerResponse)}
                if http.statusCode == 401 {store.cloudMessage="연결이 만료됐어요. 사이트에서 다시 연결해 주세요.";return}
                guard http.statusCode == 200,data.count<30000 else{throw URLError(.badServerResponse)}
                let receipt=try JSONDecoder().decode(Receipt.self,from:data)
                let submitted=Set(ops.map(\.id)),accepted=Set(receipt.receipts)
                guard !accepted.isEmpty,accepted.isSubset(of:submitted) else{throw StudyError.invalid}
                // Pairing may have changed while the request was in flight.
                guard token == credential else{return}
                try store.acknowledgeCloud(accepted)
            }
            struct Incoming:Decodable {let ops:[QuickOp];let cursor:Int;let more:Bool}
            for _ in 0..<10 {
                var req=URLRequest(url:URL(string:Study.site+"api/sync?after=\(store.state.syncCursor ?? 0)")!)
                req.setValue("Bearer "+credential,forHTTPHeaderField:"Authorization")
                let (data,response)=try await session.data(for:req)
                guard let http=response as? HTTPURLResponse,http.statusCode==200,data.count<800000,token==credential else {throw URLError(.badServerResponse)}
                let incoming=try JSONDecoder().decode(Incoming.self,from:data)
                try store.receiveCloud(incoming.ops,cursor:incoming.cursor)
                if !incoming.more {break}
            }
            await ActivityController.refresh()
            store.cloudMessage=store.state.pending.isEmpty ? "양방향 동기화 완료" : "일부 전송 대기 · 다음 입력 때 재시도해요."
        } catch {
            store.cloudMessage="전송 대기 \(store.state.pending.count)개 · 인터넷 연결 후 앱을 열거나 다음 입력 때 다시 보내요."
        }
    }
}
