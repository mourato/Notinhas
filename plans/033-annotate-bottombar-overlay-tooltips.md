# Plan 033: OverlayTooltip on Annotate bottom-bar shortcut actions

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat df25f56f..HEAD -- Notinhas/Features/Annotate/Components/AnnotateBottomBarView.swift Notinhas/Features/Annotate/Services/AnnotateOverlayTooltipKeys.swift`
> Re-read HEAD after 031/032 land. On blocking mismatch, STOP.

## Status

- **Priority**: P1
- **Effort**: S
- **Risk**: LOW
- **Depends on**: plans/031-annotate-overlay-tooltip-keys.md
- **Category**: direction (discoverability)
- **Planned at**: commit `df25f56f`, 2026-07-21

## Execution profile

- **Recommended profile**: `implementer-fast`
- **Risk/lane**: `Low/Fast`
- **Parallelizable**: `yes` — independent of 032 once 031 is DONE (same
  presenter singleton; serialize if both land the same day to ease review)
- **Reviewer required**: `yes` — `BottomBarButton` API change touches hover UX
- **Rationale**: Three controls already compute shortcut strings; swap to
  keycaps via OverlayTooltip.
- **Escalate when**: zoom/pan controls need complex gesture copy, or ImgBB/
  Share gain shortcuts.

## Why this matters

Copy & close, pin, and cloud upload already resolve configurable shortcuts into
plain `.help("Title (⌘ ⇧ C)")` text via `tooltipText`. That fights the Arc-like
OverlayTooltip language used in Notinhas and (after 032) the toolbar. Switching
these three actions to keycap bubbles completes the Annotate window’s shortcut
discoverability surface for configurable actions.

## Current state

```367:450:Notinhas/Features/Annotate/Components/AnnotateBottomBarView.swift
  private var annotateActionButtons: some View {
    let cloudUploadShortcut = annotateShortcutManager.isActionShortcutEnabled(for: .cloudUpload)
      ? annotateShortcutManager.cloudUploadShortcut?.displayString : nil
    ...
        BottomBarButton(
          ...
          tooltip: tooltipText(..., shortcut: cloudUploadShortcut)
        )
    ...
      BottomBarButton(..., tooltip: tooltipText(..., shortcut: togglePinShortcut))
      BottomBarButton(..., tooltip: tooltipText(..., shortcut: copyAndCloseShortcut))
  }

  private func tooltipText(_ title: String, shortcut: String?) -> String {
    guard let shortcut else { return title }
    return L10n.Common.withShortcut(title, shortcut)
  }
```

```729:750:Notinhas/Features/Annotate/Components/AnnotateBottomBarView.swift
struct BottomBarButton: View {
  let icon: String
  let tooltip: String
  ...
    .help(tooltip)
}
```

- Plan 031: `AnnotateOverlayTooltipKeys.actionKeys(for:)`.
- Space-to-pan uses `.help("Move canvas")` without shortcut — optional
  improvement in this plan (keys `["Space"]` or localized title only). Prefer
  adding `overlayTooltip(L10n…, keys: ["Space"])` **only if** a proper L10n
  title already exists; otherwise leave pan as-is (do not hardcode English in
  a new user-facing string).

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Format | `swiftformat Notinhas/Features/Annotate/Components/AnnotateBottomBarView.swift` | exit 0 |
| Tests | `./scripts/run-tests.sh --skip-visual -only-testing:NotinhasTests/AnnotateOverlayTooltipKeysTests` | exit 0 |
| Build | `./scripts/build_and_run.sh --no-video-module` | launches |

## Suggested executor toolkit

- Skills: `macos-app-engineering`, `accessibility-audit`, `localization`,
  `plan-execute-review`.

## Scope

**In scope**:
- `Notinhas/Features/Annotate/Components/AnnotateBottomBarView.swift`
  — `BottomBarButton` API + cloud / pin / copy callers
- Optional: canvas pan button if L10n already exists for “Move canvas”
- `plans/README.md` status (unless reviewer maintains index)

**Out of scope**:
- Toolbar (032)
- New window / Share / ImgBB / Delete (no Annotate action shortcuts)
- Zoom menu labels
- Preferences / VideoEditor
- Slider steppers

## Git workflow

- Branch: `advisor/033-annotate-bottombar-overlay-tooltips`
- Commit: `feat(annotate): use overlay tooltips for bottom-bar shortcuts`
- Merge → cleanup → push per `plan-execute-review`.

## Steps

### Step 1: Extend `BottomBarButton` for overlay tooltips

Change the button to accept title + keys instead of a pre-baked help string:

```swift
struct BottomBarButton: View {
  let icon: String
  let tooltipTitle: String
  var tooltipKeys: [String] = []
  let action: () -> Void
  ...
  var body: some View {
    Button(action: action) { ... }
      .buttonStyle(.plain)
      .onHover { isHovering = $0 }
      .overlayTooltip(tooltipTitle, keys: tooltipKeys, edge: .above)
      .accessibilityLabel(
        tooltipKeys.isEmpty
          ? tooltipTitle
          : L10n.Common.withShortcut(tooltipTitle, tooltipKeys.joined(separator: ""))
      )
  }
}
```

Update **all** `BottomBarButton(` call sites in this file to the new parameter
names (`tooltip:` → `tooltipTitle:`). Call sites without shortcuts keep
`tooltipKeys` default `[]`.

Remove `.help(tooltip)` — do not dual-stack.

**Verify**: `rg "tooltip:" Notinhas/Features/Annotate/Components/AnnotateBottomBarView.swift`
shows no old `tooltip:` parameter on `BottomBarButton` initializers (except
comments).

### Step 2: Wire cloud / pin / copy to `actionKeys`

```swift
let cloudKeys = AnnotateOverlayTooltipKeys.actionKeys(for: .cloudUpload, manager: annotateShortcutManager)
let pinKeys = AnnotateOverlayTooltipKeys.actionKeys(for: .togglePin, manager: annotateShortcutManager)
let copyKeys = AnnotateOverlayTooltipKeys.actionKeys(for: .copyAndClose, manager: annotateShortcutManager)
```

Pass titles without `tooltipText` / `displayString` concatenation. For cloud,
keep the uploaded / reupload / upload title branching; only the keys change.

Delete `tooltipText` if unused.

**Verify**: `rg "tooltipText|displayString" Notinhas/Features/Annotate/Components/AnnotateBottomBarView.swift`
has no remaining uses for these three buttons’ shortcut hints.

### Step 3: Format, smoke, integrate

- Hover pin → keycaps matching Preferences default `⌃ ⌘ P` parts
- Hover copy → `⌘ ⇧ C` parts (order must match `ShortcutConfig.displayParts`)
- Mouse-out hides tooltip
- Commit / merge / cleanup / push

## Test plan

- Rely on 031 `actionKeys` tests.
- Manual hover on pin + copy + cloud (if cloud configured).

## Done criteria

- [ ] `BottomBarButton` uses `overlayTooltip`, not `.help`
- [ ] Cloud / pin / copy use `AnnotateOverlayTooltipKeys.actionKeys`
- [ ] Other bottom-bar buttons still show title-only overlay tooltips
- [ ] No English regressions for existing L10n titles
- [ ] Format + keys tests pass; merged and pushed

## STOP conditions

- `BottomBarButton` is used outside this file and the API break is non-local —
  grep the repo; if other files use it, update them in-scope or STOP.
- Cloud title branching becomes unclear — preserve exact title selection logic.
- Plan 031 missing.

## Maintenance notes

- When a new Annotate action shortcut is added to the bottom bar, use
  `actionKeys` — never `displayString` in hover UI.
- Reviewer: confirm uploaded-cloud disabled state still shows a sensible
  title-only tooltip.
