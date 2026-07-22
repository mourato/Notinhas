# Development

Set up Notinhas for local development and run it from source.

## Prerequisites

- macOS 13.0+
- Xcode 15.0+
- Command Line Tools: `xcode-select --install`

## Clone the repository

```bash
git clone https://github.com/mourato/Notinhas.git
cd Notinhas
```

## Open in Xcode

```bash
open Notinhas.xcodeproj
```

Build and run with `Cmd+R` using the **Notinhas** scheme (Video module off by default).

## Build from the terminal

```bash
xcodebuild -project Notinhas.xcodeproj -scheme Notinhas -configuration Debug build CODE_SIGNING_ALLOWED=NO
```

Output: `~/Library/Developer/Xcode/DerivedData/Notinhas-*/Build/Products/Debug/Notinhas.app`

## Run the local debug app

```bash
./scripts/build_and_run.sh
```

The script builds **Notinhas Debug.app** at:

```text
.build/xcode-derived-data/Build/Products/Debug/Notinhas Debug.app
```

Debug uses bundle ID `com.mourato.notinhas.debug` so TCC grants stay separate from release `com.mourato.notinhas`.

Reset local Debug permissions:

```bash
tccutil reset ScreenCapture com.mourato.notinhas.debug
tccutil reset Microphone com.mourato.notinhas.debug
tccutil reset Accessibility com.mourato.notinhas.debug
```

## Run tests

Unit tests live in `NotinhasTests/`, a peer folder of `Notinhas/`.

```bash
./scripts/run-tests.sh
./scripts/run-tests.sh --video-module   # optional Recording/VideoEditor XCTests
```

Or directly:

```bash
xcodebuild test -project Notinhas.xcodeproj -scheme Notinhas -configuration Debug
```

## Optional Video module

```bash
./scripts/build_and_run.sh --video-module
open Notinhas.xcodeproj   # select **Notinhas Video** scheme
```

Enable at runtime under **Preferences → Advanced** when compiled in.

## Related docs

- [BUILD.md](BUILD.md) — archive, export, DMG packaging
- [RELEASES.md](RELEASES.md) — GitHub Release workflow
- [MIGRATION.md](MIGRATION.md) — Notinhas upgrade path
