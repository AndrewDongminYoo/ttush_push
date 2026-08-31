---
type: Interview Ledger
parent: spec.md
---

## Records

### L1

Status: current

Question: What visual problem must the first pass solve?

Answer: "앱의 UI가 너무 AI Slop이 심합니다. 각 요소가 어울리지 않고, 가장 중요한 이벤트인 \"푸시\"가 감흥없는 이동 이벤트처럼 보입니다."

Decision: Replace the mixed visual language with one restrained match presentation.
Make Push read as a distinct collision and displacement event.

Source: Operator request in this session.

### L2

Status: current

Question: Which visual direction is approved for the first pass?

Answer: "1차 안부터 진행합니다. 스프라이트 교체는 필요합니다. (특히 두 팀이 전혀 다른 실루엣이라 되게 어색합니다.)"

Decision: Replace the five existing foreground sprites in place.
Keep the existing air-ruins background.
Use a restrained HUD and existing replay timing.

Source: Operator request in this session.

### L3

Status: current

Question: How should the explorer art avoid frame-animation scope?

Answer: "사람 모양으로 만드는게 더 많은 애니메이션 스프라이트를 요한다면, 좀더 SD 캐릭터화시키는 게 좋습니다."

Decision: Use two matched static super-deformed expedition characters.
Do not add frame animation, directional variants, or persistent facing state.

Source: Operator request in this session.

### L4

Status: current

Question: What must be restored before implementation after the previous working tree was lost?

Answer: Restore the missing visual contract.
Define the HUD and asset exclusions.
Add real Push approach, contact, and settled-state evidence.
Verify the branch base before completion.

Decision: This Spec and its implementation plan define the restored contract.
The integration fixture captures all three Push states.

Source: Advisor review on 2026-08-31.

### L5

Status: current

Question: Which existing ownership and evidence rules constrain this work?

Answer: Rust owns game rules and results.
Flutter can only present `MoveResolution` facts.
A screenshot fixture proves only states that it creates through the real interaction path.

Decision: The Push marker uses the existing Rust-authored resolution only.
The integration fixture taps the real move path before it captures the Push states.

Source: Oracle lookup on 2026-08-31.

### L6

Status: current

Question: Which camera must the footholds use after the first native visual pass?

Answer: "지금 깨진 타일은 정사각형이고 보통의 타일은 다른 원근 각도에서 보고 있어서 그 차이가 두드러집니다. 캐릭터가 그 위에 올라가 서있는게 아니라 그냥 겹쳐져 있는 것으로 보입니다."

Decision: Use one orthographic top-down square footprint for intact, damaged, and collapsed footholds.
Remove visible side walls and preserve the existing board geometry and cell rectangles.

Source: Operator request in this session.

### L7

Status: current

Question: How should the explorers change without losing the first generated set?

Answer: "캐릭터도 지금 이미지는 다른 용도로 보존하고, 좀 더 위에서 내려다보는 듯한 모습으로 수정해야 할 것 같습니다."
Answer: "만들어진 이미지들 자체로는 훌륭한 레퍼런스이므로 나중에 스크린샷 등 외부 컨텐츠를 만들 때 필요할 수 있습니다. 삭제하지 말고 별도로 보관해주세요."

Decision: Preserve all five first-pass images in an unbundled reference directory.
Add two board-specific high-angle explorer paths, keep the existing explorer files unchanged, and update only the active loader paths.

Source: Operator requests in this session.
