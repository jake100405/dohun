# 하루한칸 Live · 무료 설치 시험판

현재 상태: iOS 시험판 소스입니다. 빌드는 GitHub Actions에서 진행하며 무료 서명과 실기기 검증은 별도로 필요합니다. 소스 ZIP은 설치 가능한 IPA가 아닙니다.

## 목표

잠금화면의 실시간 현황 카드에서 과목 ◀ ▶ 전환, ○·△·× 입력, 이번 주 과목 완료/잠금, 완료 해제.
앱을 화면에 띄우지 않고 처리하도록 LiveActivityIntent를 사용했습니다. 완전히 잠긴 기기에서는 Face ID/암호 인증이 필요할 수 있습니다.

- 11과목: 대수A/B, 미적분A/B, 물리학, 화학, 생명과학, 지구과학, 국어, 영어, 정보
- 앱 안에도 같은 기록 입력 화면이 있습니다.
- iOS 17 이상. 네트워크·APNs·App Groups·iCloud 권한을 사용하지 않습니다.
- 기록은 앱 프로세스의 UserDefaults에 보관합니다. 위젯은 OS가 전달한 Activity ContentState만 표시합니다.
- 앱 안과 잠금화면 카드의 입력은 같은 저장소를 사용하도록 설계했습니다.
- 사이트와는 수동 왕복 전송입니다. 기기 내 기존 공부·운동 기록을 삭제하지 않습니다.
- 운동 탭과 운동 그림은 기존 사이트에서 계속 사용합니다.

## Windows에서 빌드 준비

1. 이 폴더 내용을 본인 GitHub 저장소의 루트에 올립니다. .github/workflows/ios-unsigned.yml도 포함해야 합니다.
2. GitHub Actions → Build free iOS trial → Run workflow.
3. macOS 클라우드 러너가 시뮬레이터/기기용 앱·위젯을 컴파일합니다.
4. 성공 시 Artifacts의 HaruhankanFree-unsigned에서 IPA를 다운로드합니다.
5. 비공개 저장소는 계정의 Actions 무료 사용량을 확인하세요. 할당량을 넘어 유료 실행을 신청하지 마세요. 공개 저장소는 소스가 공개됩니다. 공부 기록·Apple 비밀번호는 저장소에 넣지 마세요.

GitHub Actions에서 소스 커밋마다 빌드합니다. 실제 빌드 상태는 Actions 실행 결과를 확인하세요.

## 무료 서명·설치

1. 본인 Windows PC에서 AltStore Classic/AltServer 공식 안내를 따라 설치합니다.
2. 아이폰을 PC에 연결하고 필요한 기기 신뢰/개발자 모드를 본인이 허용합니다.
3. AltStore My Apps의 +로 위에서 만든 IPA를 선택합니다.
4. 위젯 확장을 유지합니다. 제거하면 잠금화면 카드가 표시되지 않습니다.
5. 무료 Apple 계정은 7일 이내 인증 갱신이 필요합니다. AltServer의 갱신이 실제 작동하는지 확인하세요.
6. 서명·확장 제한 때문에 설치 또는 실행이 실패할 수 있습니다. 유료 가입 없이 먼저 이 최소 시험판으로 확인하세요.

Apple 비밀번호를 제작자나 채팅에 보내지 마세요. 계정 입력·약관·서명 허용은 본인 기기에서 직접 진행합니다.
AltStore 공식 Windows 안내: https://faq.altstore.io/altstore-classic/how-to-install-altstore-windows

## 사용 및 기존 사이트 연결

1. 앱에서 공부 시작 · 잠금화면 카드 켜기를 누릅니다.
2. 아이폰 화면을 잠그고 카드의 과목 전환과 기호 입력을 시험합니다.
3. 완료를 누르면 그 주의 해당 과목이 잠깁니다. 완료 해제로 다시 입력합니다.
4. 앱의 사이트에 기록 반영 → Safari의 기록 반영을 누릅니다.
5. 사이트의 위젯 연결 → iOS 시험판으로 보내기를 눌러 전송 확인과 최신 웹 기록을 가져옵니다.
6. 기존 Safari/홈 화면 앱은 저장 공간이 다를 수 있으니 평소 기록하던 쪽에서 반영합니다.

실시간 현황은 최대 8시간 활성화됩니다. 이후에는 앱에서 공부 시작을 다시 눌러야 합니다. 상시 고정 위젯과 다릅니다.

## 실기기 통과 기준

- 앱/위젯 확장이 모두 무료 서명으로 설치됨
- 앱에서 카드를 시작하고 앱을 뒤로 보내도 카드가 표시됨
- 잠금화면 ○·△·× 입력이 앱을 열지 않고 저장됨 (OS 인증은 별도)
- ◀ ▶ 전환 직후 입력해도 표시한 과목에 저장됨
- 완료 후 기호 입력이 차단되고 해제 후 재입력됨
- 앱 강제 종료/다시 실행 후 기록이 유지됨
- 사이트 수신 확인 후 미전송 목록이 정리됨
- 다음 날 전날 버튼을 누르면 새 날짜 확인 없이 기록하지 않음

## 참고

https://developer.apple.com/documentation/widgetkit/adding-interactivity-to-widgets-and-live-activities
https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities
https://developer.apple.com/documentation/appintents/liveactivityintent
https://faq.altstore.io/altstore-classic/your-altstore

Generated/App-Info.plist 및 Generated/Widget-Info.plist는 XcodeGen이 생성합니다.
