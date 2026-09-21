# Closed playtest tester kit

The text handed to testers for the Closed Playtest Validation milestone, and the record format their answers come back in.
Issue #42 rules an analytics or crash-reporting SDK out of scope for this round on the grounds that a form and a session log carry the same information at this scale.
This file is that form and that log.

Copy the blocks below verbatim.
Everything outside a block is a note for whoever runs the playtest, not for a tester.

## What each block feeds

| Block             | Definition of Done item it closes                                                         |
| ----------------- | ----------------------------------------------------------------------------------------- |
| Release notes     | The upload itself, which is item 2                                                        |
| Invitation        | Items 3 and 6: a Play-delivered install, and coverage of every mode and difficulty        |
| Per-match record  | Items 5, 6 and 7: the match count, the coverage, and the five fields per match            |
| Closing questions | Items 8 and 9: whether the coach alone carried the rules, and the three recurring reports |
| Blocker report    | Item 10: zero P0/P1 crashes and zero progress-blocking defects                            |

## Release notes for the closed Alpha track

Play asks for these per language, capped at 500 characters each.
The blocks must match `fastlane/metadata/android/en-US/changelogs/6.txt` and `fastlane/metadata/android/ko-KR/changelogs/6.txt` before upload.

`en-US`:

```plaintext
🆕 What's New
• Pick your rival: share one device for a head-to-head duel, or challenge four AI levels, from a gentle Easy to a ruthless Expert.
• The whole game now speaks English and Korean.

✨ Improvements
• A friendlier first-match guide and a fresh launcher icon with rivals mid-push.
• Under-the-hood tune-ups for a smoother match.

🔧 Fixes
• Korean result announcements now say who really won.

Push smart. Hold your ground. Win two rounds. 🏆
```

`ko-KR`:

```plaintext
🆕 새로운 기능
• 상대를 고르세요. 한 기기에서 친구와 맞대결을 펼치거나, 쉬움부터 만만치 않은 전문가까지 네 단계의 AI에 도전할 수 있습니다.
• 게임 전체를 영어와 한국어로 즐길 수 있습니다.

✨ 개선
• 첫 매치 안내가 더 친절해지고, 앱 아이콘은 서로를 밀어내는 두 탐험가로 새 단장했습니다.
• 보이지 않는 곳도 손봐서 매치가 더 매끄럽게 이어집니다.

🔧 수정
• 한국어 결과 안내가 누가 이겼는지 정확하게 알려줍니다.

푸시하고, 버티고, 두 라운드를 먼저 차지하세요. 🏆
```

## Invitation

Send this after the build reaches the track and Play shows it as available.

The invitation deliberately does not explain a single rule.
Item 8 asks whether the game is playable from the coach alone, and a tester who was told the rules in the invitation can no longer answer that question.

```plaintext
안녕하세요. Ttush Push 1.1.1 비공개 Alpha 테스트를 부탁드립니다.

먼저 Play 스토어에서 앱을 최신 버전으로 업데이트해 주세요.
파일을 직접 설치하지 마시고 Play가 전달하는 업데이트로 받아 주셔야, 실제 배포 경로가 함께 검증됩니다.

부탁드리는 것은 세 가지입니다.

첫째, 규칙 설명을 따로 찾지 마시고 화면에 나오는 안내만 보고 플레이해 주세요.
규칙이 안내만으로 전달되는지가 이번 테스트에서 확인하려는 가장 중요한 항목이라서, 저도 규칙을 미리 설명하지 않겠습니다.

둘째, 여러 판을 해 보시되 2인 플레이와 AI 대전을 모두 해 보세요.
AI 대전은 쉬움, 보통, 어려움, 전문가를 각각 한 번 이상 겪어 봐 주세요.

셋째, 매치를 한 판 끝낼 때마다 아래 형식으로 한 줄씩 적어서 보내 주세요.
```

Returning testers are asked to do nothing about the coach, because the build handles it.
`firstPlayCoachVersion` moved from 1 to 2 in `lib/game/coach/first_play_coach_store.dart`, and completion is stored under a key that carries that number, so a tester who finished the coach in 1.0.0 meets it again here.
That matters because all 34 testers already on the track had dismissed it, and item 8 asks what a player learns from the coach.
`shows the coach to a player who completed the 1.0.0 version` in `test/game/view/game_page_accessibility_test.dart` fails if the constant goes back to 1.

## Per-match record

Five fields are readable on the screen when the match ends.
Ask the tester to copy each visible label in the interface language instead of translating it.

```plaintext
한 판이 끝날 때마다 이렇게 한 줄씩 남겨 주세요.

[기기 모델] / [Android 버전] / [화면 언어]
[소요 시간] / [모드] / [난이도] / [결과] / [승리 사유]

- 기기를 바꾸면 새 기기 정보 아래에 그 기기에서 플레이한 매치를 적어 주세요.
- 소요 시간: 분 단위의 대략적인 값이면 충분합니다.
- 모드: 화면에 표시된 2인 플레이 또는 AI 대전을 적어 주세요.
- 난이도: AI 대전일 때만 쉬움, 보통, 어려움, 전문가 중 화면에 표시된 항목을 적고, 2인 플레이이면 비워 두세요.
- 결과: AI 대전이면 승 또는 패, 2인 플레이이면 이긴 쪽을 화면에 표시된 원정대 이름으로 적어 주세요.
- 승리 사유: 매치가 끝난 화면에 표시되는 문구를 그대로 옮겨 주세요.

예시
Pixel 9 / Android 16 / 한국어
4분 / AI 대전 / 보통 / 패 / 상대의 움직임을 막았습니다.
Galaxy S24 / Android 15 / 한국어
7분 / 2인 플레이 / / 불씨 원정대 / 상대를 보드 밖으로 푸시했습니다.
```

Group the match records by device model, Android version, and interface language.
Item 3 requires at least one completed match on each of at least two different physical Android devices.

## Closing questions

Ask these once, after the tester has finished playing, never between matches.

```plaintext
마지막으로 네 가지만 여쭙겠습니다. 한 줄씩이면 충분합니다.

1. 규칙 중에서 끝까지 이해되지 않았거나, 한참 뒤에야 알게 된 것이 있었다면 무엇이었습니까?
2. 불공평하다고 느낀 순간이 있었다면 어떤 상황이었습니까?
3. 지루하다고 느낀 구간이 있었다면 언제였습니까?
4. 게임 규칙을 알려 주는 안내 화면의 문구를 이해하는 것은 얼마나 편했습니까? 편함, 보통, 어려움 중 하나와 그 이유를 한 줄로 적어 주세요.
```

The first three questions map one to one onto item 9, which asks for the top three recurring reports of confusion, unfairness and boredom.
Recurring is the operative word: a single tester's answer is an anecdote, and the item is closed by what repeats across testers.

## Blocker report

```plaintext
앱이 튕기거나, 화면이 멈추거나, 그 밖의 어떤 이유로든 더 진행할 수 없게 된 경우에는, 판이 끝나기를 기다리지 마시고 그때 바로 알려 주세요.
눌러도 아무 반응이 없거나 매치를 끝낼 수 없는 상황도 여기에 들어갑니다.
어떤 화면에서 무엇을 누른 직후였는지 한 줄이면 충분합니다.
```

## Interpreting the coach answers

The app ships English and Korean localizations through `lib/l10n/arb/app_en.arb` and `lib/l10n/arb/app_ko.arb`.
The interface follows the device locale.

That affects item 8 specifically.
A tester who cannot follow the coach does not show whether the coach sequence or its localized wording caused the problem.
Use the recorded interface language and the fourth closing answer to separate these causes when you evaluate item 8.
