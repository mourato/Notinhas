# Plan 034: Add +/- steppers beside Annotate and Notinhas sliders

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat df25f56f..HEAD -- Notinhas/Shared/Extensions/Binding+Stepped.swift Notinhas/Features/Annotate/Components/AnnotateQuickPropertiesBar.swift Notinhas/Features/Notinhas/Views/NotinhasNoteEditorView.swift`
> On blocking mismatch, STOP.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED
- **Depends on**: none (independent of 031–033)
- **Category**: direction (usability)
- **Planned at**: commit `df25f56f`, 2026-07-21

## Execution profile

- **Recommended profile**: `implementer`
- **Risk/lane**: `Medium/Full`
- **Parallelizable**: `yes` — independent workstream from OverlayTooltip plans
- **Reviewer required**: `yes` — shared control used in dense Annotate chrome
- **Rationale**: New reusable control + multiple call-site adoptions; layout
  density and AX matter.
- **Escalate when**: Preferences / VideoEditor adoption is requested in the
  same PR (split to a follow-up plan instead).

## Why this matters

Annotate property sliders (stroke width, font size, blur strength, etc.) and
the Notinhas area stroke-width slider only change via click-and-drag. Fine
adjustments are awkward on trackpads, and there is no accessible step control.
`Binding.stepped(by:in:)` already snaps drag values — the missing piece is
explicit − / + buttons that nudge by the same step and clamp to the same range.

## Current state

- Stepping exists without UI steppers:

```11:20:Notinhas/Shared/Extensions/Binding+Stepped.swift
extension Binding where Value == CGFloat {
  func stepped(by step: CGFloat, in range: ClosedRange<CGFloat>) -> Binding<CGFloat> {
    Binding(
      get: { self.wrappedValue },
      set: { newValue in
        let snapped = (newValue / step).rounded() * step
        self.wrappedValue = Swift.min(Swift.max(snapped, range.lowerBound), range.upperBound)
      }
    )
  }
}
```

- Quick properties stroke control (pattern for others in the same file):

```1381:1403:Notinhas/Features/Annotate/Components/AnnotateQuickPropertiesBar.swift
  var body: some View {
    QuickPropertiesGroup(title: title, spacing: groupSpacing) {
      HStack(spacing: 6) {
        Image(systemName: iconName)
        Slider(
          value: $value.stepped(by: 1, in: AnnotationProperties.controlValueRange),
          in: AnnotationProperties.controlValueRange,
          onEditingChanged: onEditingChanged
        )
        ...
        Text(displayText)
      }
    }
  }
```

- Notinhas note editor area stroke slider (no `stepped` binding today — uses
  `Slider(..., step: 0.5)`):

```147:166:Notinhas/Features/Notinhas/Views/NotinhasNoteEditorView.swift
  private var areaStrokeWidthControl: some View {
    HStack(spacing: 8) {
      Text(NotinhasL10n.areaStrokeWidthLabel)
      Slider(
        value: $areaStrokeWidth,
        in: NotinhasVisualNote.areaStrokeWidthRange,
        step: 0.5
      )
      Text(areaStrokeWidthLabel)
    }
  }
```

- Preferences already uses a naked `Stepper` in Advanced log retention
  (`PreferencesAdvancedSettingsView.swift` ~152) — visual exemplar for −/+,
  but Annotate needs a compact control beside a slider, not a replacement.

- `AnnotationProperties.controlValueRange` = `1 ... 20`
  (`AnnotateAnnotationItem.swift`).

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Format | `swiftformat Notinhas/Shared Notinhas/Features/Annotate/Components/AnnotateQuickPropertiesBar.swift Notinhas/Features/Notinhas NotinhasTests` | exit 0 |
| Tests | `./scripts/run-tests.sh --skip-visual -only-testing:NotinhasTests/SteppedSliderControlTests` | exit 0 (or full `--skip-visual` if filter unsupported) |
| Build | `./scripts/build_and_run.sh --no-video-module` | launches |

## Suggested executor toolkit

- Skills: `macos-app-engineering`, `apple-design`, `accessibility-audit`,
  `swift-conventions`, `testing-xctest`, `plan-execute-review`.

## Scope

**In scope**:
- New shared control, e.g.
  `Notinhas/Shared/Components/SteppedSliderControl.swift`
- Unit tests:
  `NotinhasTests/Shared/Components/SteppedSliderControlTests.swift`
  (test the nudge/clamp math via a pure helper if the view is awkward to host)
- Adopt in `AnnotateQuickPropertiesBar.swift` private slider controls that
  already use `.stepped(by:in:)`:
  - `QuickStrokeWidthControl`
  - `QuickTextFontSizeControl`
  - blur / opacity / angle / feather controls in the same file that wrap
    `Slider` + `stepped` (search for `Slider(value: $value.stepped` in that
    file and convert each)
- Adopt in `NotinhasNoteEditorView.areaStrokeWidthControl`
- Optional tiny pure helper in `Binding+Stepped.swift`, e.g.
  `static func nudged(_ value: CGFloat, by step: CGFloat, in range: …) -> CGFloat`
  used by both buttons and tests

**Out of scope**:
- Preferences Capture / Quick Access / History sliders (follow-up plan if
  requested)
- VideoEditor / Recording waveform sliders
- Hue/alpha custom `AnnotateHueSlider` / `AnnotateAlphaSlider` (not SwiftUI
  `Slider`)
- Mockup sidebar sliders (lower traffic; follow-up)
- Changing step sizes or ranges

## Git workflow

- Branch: `advisor/034-stepped-slider-controls`
- Commit: `feat(ui): add plus/minus steppers beside annotate sliders`
- Merge → cleanup → push per `plan-execute-review`.

## Steps

### Step 1: Pure nudge helper + tests

Add to `Binding+Stepped.swift` (or a sibling file):

```swift
enum SteppedValue {
  static func nudge(_ value: CGFloat, by step: CGFloat, in range: ClosedRange<CGFloat>) -> CGFloat {
    let next = value + step
    let snapped = (next / step).rounded() * step
    return Swift.min(Swift.max(snapped, range.lowerBound), range.upperBound)
  }
}
```

Also provide `Double` if needed for Preferences later — **CGFloat is enough
for this plan**.

Tests:
1. Mid-range +1 step increases by step
2. At upperBound, +step stays at upperBound
3. At lowerBound, −step stays at lowerBound
4. Nudge from slightly off-step snaps via rounded step math consistent with
   `Binding.stepped`

**Verify**: new test target passes.

### Step 2: Build `SteppedSliderControl`

SwiftUI view API (adjust names to match repo style):

```swift
struct SteppedSliderControl: View {
  @Binding var value: CGFloat
  let range: ClosedRange<CGFloat>
  let step: CGFloat
  var sliderWidth: CGFloat? = nil
  var onEditingChanged: (Bool) -> Void = { _ in }
  // slots: leading icon / trailing label are caller-owned OR pass optional
}
```

Recommended layout (compact, Annotate density):

`[ − ] [ Slider ] [ + ]`

- Buttons: plain, 16–18pt hit target minimum, SF Symbols `minus` / `plus`
- Decrement calls `value = SteppedValue.nudge(value, by: -step, in: range)`
- Increment uses `+step`
- Disable − at `value <= range.lowerBound + epsilon`, + at upper bound
- Slider continues to use `$value.stepped(by: step, in: range)` and forwards
  `onEditingChanged`
- Accessibility: buttons labeled with `L10n` if suitable strings exist; else
  use `accessibilityLabel` with clear English **only if** the project already
  does that for similar chrome — prefer adding keys to existing annotate /
  common tables if you must introduce user-facing strings. If adding L10n,
  follow `localization` skill (xcstrings / L10n.swift). Prefer reusing
  something like decrease/increase if present; otherwise
  `.accessibilityLabel("Decrease")` / `"Increase"` is acceptable for this
  plan **only** when matching nearby unlabeled icon buttons — check
  `accessibility-audit` patterns in Annotate first.

Include a `#Preview` with a `@State` value.

**Verify**: file compiles; preview builds in Xcode conceptually.

### Step 3: Adopt in AnnotateQuickPropertiesBar

Replace the `Slider(...)` inside each `Quick*Control` that uses `.stepped`
with `SteppedSliderControl`, preserving `sliderWidth`, `onEditingChanged`,
and trailing `Text(displayText)` / icons as they exist today.

Suggested HStack after adoption:

`[icon] [SteppedSliderControl] [value label]`

Do not let the control grow the bar excessively — keep `controlSize(.small)`
on the slider; stepper buttons should be visually light (secondary
foreground).

**Verify**: `rg "Slider\\(value: \\$value\\.stepped" Notinhas/Features/Annotate/Components/AnnotateQuickPropertiesBar.swift`
returns no matches for the converted controls.

### Step 4: Adopt in NotinhasNoteEditorView

Replace area stroke `Slider` with `SteppedSliderControl` using
`NotinhasVisualNote.areaStrokeWidthRange` and `step: 0.5`. Keep the label and
value text. Preserve combined accessibility on the row.

**Verify**: note editor still shows stroke control; −/+ nudge by 0.5.

### Step 5: Format, test, smoke, integrate

- Drag still works; −/+ nudges; clamps at ends
- Commit / merge / cleanup / push

## Test plan

- `SteppedSliderControlTests` / `SteppedValue` nudge cases above.
- Pattern: small pure XCTest like other Shared component tests.
- Manual: Annotate → select arrow → stroke width −/+; Notinhas area note →
  stroke −/+.

## Done criteria

- [ ] `SteppedValue.nudge` (or equivalent) tested
- [ ] `SteppedSliderControl` exists and is used by Annotate quick property
  stepped sliders listed in Scope
- [ ] Notinhas area stroke width uses the control with step 0.5
- [ ] No Preferences/Video files modified
- [ ] Format + tests pass; merged and pushed

## STOP conditions

- Quick properties layout overflows or clips badly on small annotate windows —
  STOP and report with screenshot notes rather than shrinking hit targets below
  ~16pt.
- `onEditingChanged` semantics break undo coalescing for stroke edits — inspect
  callers; preserve when buttons fire (treat button nudge as a discrete edit:
  call `onEditingChanged(true)` then `false` around the assignment if that
  matches existing drag end behavior; if unclear, STOP and report).
- Demand to convert Preferences in the same change — split out; do not expand.

## Maintenance notes

- Follow-up candidate: Preferences Capture / Quick Access sliders.
- Custom hue/alpha bars stay separate.
- Reviewer: confirm disabled button states at range ends and that VoiceOver
  can focus − / slider / + separately.
