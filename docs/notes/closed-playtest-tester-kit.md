# Closed playtest tester kit

The text handed to testers for the Closed Playtest Validation milestone, and the record format their answers come back in.
Issue #42 rules an analytics or crash-reporting SDK out of scope for this round on the grounds that a form and a session log carry the same information at this scale.
This file is that form and that log.

Copy the blocks below verbatim.
Everything outside a block is a note for whoever runs the playtest, not for a tester.

## What each block feeds

| Block             | Definition of Done item it closes                                                         |
| ----------------- | ----------------------------------------------------------------------------------------- |
| Release notes     | The upload itself, which is item 1                                                        |
| Invitation        | Items 2 and 5: a Play-delivered install, and coverage of every mode and difficulty        |
| Per-match record  | Items 4, 5 and 6: the match count, the coverage, and the five fields per match            |
| Closing questions | Items 7 and 8: whether the coach alone carried the rules, and the three recurring reports |
| Blocker report    | Item 9: zero P0/P1 crashes and zero progress-blocking defects                             |

## Release notes for the internal testing track

Play asks for these per language, capped at 500 characters each.

`en-US`:

```plaintext
New in 1.1.0

- Match setup: pick 2 Players or Play vs AI, and Easy, Normal or Hard, before the board opens.
- Leaving a match asks first, so one stray tap no longer ends a round in progress.
- A new launcher icon.
- The interface font ships inside the app, so the first screen no longer waits on a download.

Tell us anything that crashes, blocks you, or leaves you unsure what to do.
```

`ko-KR`:

```plaintext
1.1.0에서 달라진 점

- 보드가 열리기 전에 2인 대전과 AI 대전 중에서 고르고, Easy, Normal, Hard 중에서 난이도를 선택합니다.
- 매치 도중에 나가려고 하면 확인을 먼저 묻기 때문에, 잘못 누른 한 번으로 진행 중인 라운드가 끝나지 않습니다.
- 런처 아이콘을 새 그림으로 교체했습니다.
- 인터페이스 글꼴을 앱 안에 함께 담았기 때문에, 첫 화면이 글꼴을 내려받기를 기다리지 않습니다.

앱이 튕기거나, 더 진행할 수 없게 막히거나, 무엇을 해야 할지 알 수 없었던 순간이 있으면 알려 주세요.
```

## Invitation

Send this after the build reaches the track and Play shows it as available.

The invitation deliberately does not explain a single rule.
Item 7 asks whether the game is playable from the coach alone, and a tester who was told the rules in the invitation can no longer answer that question.

```plaintext
안녕하세요. Ttush Push 1.1.0 내부 테스트를 부탁드립니다.

먼저 Play 스토어에서 앱을 최신 버전으로 업데이트해 주세요.
파일을 직접 설치하지 마시고 Play가 전달하는 업데이트로 받아 주셔야, 실제 배포 경로가 함께 검증됩니다.

부탁드리는 것은 세 가지입니다.

첫째, 규칙 설명을 따로 찾지 마시고 화면에 나오는 안내만 보고 플레이해 주세요.
규칙이 안내만으로 전달되는지가 이번 테스트에서 확인하려는 가장 중요한 항목이라서, 저도 규칙을 미리 설명하지 않겠습니다.

둘째, 여러 판을 해 보시되 2인 대전과 AI 대전을 모두 해 보시고, AI 대전은 Easy, Normal, Hard를 각각 한 번 이상 겪어 봐 주세요.

셋째, 매치를 한 판 끝낼 때마다 아래 형식으로 한 줄씩 적어서 보내 주세요.
```

Returning testers are asked to do nothing about the coach, because the build handles it.
`firstPlayCoachVersion` moved from 1 to 2 in `lib/game/coach/first_play_coach_store.dart`, and completion is stored under a key that carries that number, so a tester who finished the coach in 1.0.0 meets it again here.
That matters because all 34 testers already on the track had dismissed it, and item 7 asks what a player learns from the coach.
`shows the coach to a player who completed the 1.0.0 version` in `test/game/view/game_page_accessibility_test.dart` fails if the constant goes back to 1.

## Per-match record

Five fields, all of them readable off the screen the match ends on.
The win reason appears there in English as `by knockout` or `by immobilization`, so a tester can copy it rather than judge it.

```plaintext
한 판이 끝날 때마다 이렇게 한 줄씩 남겨 주세요.

[소요 시간] / [모드] / [난이도] / [결과] / [승리 사유]

- 소요 시간: 분 단위의 대략적인 값이면 충분합니다.
- 모드: 2 Players 또는 Play vs AI
- 난이도: AI 대전일 때만 Easy, Normal, Hard 중 하나를 적고, 2인 대전이면 비워 두세요.
- 결과: AI 대전이면 승 또는 패, 2인 대전이면 이긴 쪽을 Azure 또는 Ember로 적어 주세요.
- 승리 사유: 매치가 끝난 화면에 표시되는 문구를 그대로 옮겨 주세요.

예시
4분 / Play vs AI / Normal / 패 / by immobilization
7분 / 2 Players / / Ember / by knockout
```

Also collect the device model and the Android version once per tester, not once per match.
Item 2 asks for a completed match on at least two real Android devices, and that is the only field that answers it.

## Closing questions

Ask these once, after the tester has finished playing, never between matches.

```plaintext
마지막으로 세 가지만 여쭙겠습니다. 한 줄씩이면 충분합니다.

1. 규칙 중에서 끝까지 이해되지 않았거나, 한참 뒤에야 알게 된 것이 있었다면 무엇이었습니까?
2. 불공평하다고 느낀 순간이 있었다면 어떤 상황이었습니까?
3. 지루하다고 느낀 구간이 있었다면 언제였습니까?
```

The three questions map one to one onto item 8, which asks for the top three recurring reports of confusion, unfairness and boredom.
Recurring is the operative word: a single tester's answer is an anecdote, and the item is closed by what repeats across testers.

## Blocker report

```plaintext
앱이 튕기거나, 화면이 멈추거나, 그 밖의 어떤 이유로든 더 진행할 수 없게 된 경우에는, 판이 끝나기를 기다리지 마시고 그때 바로 알려 주세요.
눌러도 아무 반응이 없거나 매치를 끝낼 수 없는 상황도 여기에 들어갑니다.
어떤 화면에서 무엇을 누른 직후였는지 한 줄이면 충분합니다.
```

## One thing to settle before sending

The app's interface is English only.
`lib/l10n/arb/` holds `app_en.arb` and nothing else, so the coach lines, the mode and difficulty labels, and the win reasons all reach a Korean tester in English.

That is a problem specifically for item 7.
A tester who could not follow the coach cannot tell you whether the coach was unclear or whether it was in a language they do not read, and item 7 is the item that decides whether the tutorial needs work.
Decide which reading you want before the invitations go out.
Adding a Korean locale is out of scope for this milestone; asking each tester how comfortable they are reading English UI costs one line and separates the two readings well enough to interpret the answers.
