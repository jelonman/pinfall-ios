# iOS build — green 2026-08-02

`Pinfall.app`, 147 MB, arm64, **BUILD SUCCEEDED** — run 30723103291, job 91430080970.

## Three separate faults, found in this order

**1. The export was aborting on a missing icon.** The committed `project.godot` had no
`config/icon` line. The iOS preset deliberately leaves several icon slots unset and Godot falls
back to the project icon for each, so with no project icon every fallback resolved to `''`:

    ERROR: Export Icons: Invalid icon (icons/notification_76x76): ''

**2. An aborted export still writes a pbxproj — with its placeholders raw.** Six of them:
`$pbx_embeded_frameworks`, `$additional_pbx_files`, `$additional_pbx_frameworks_build`,
`$additional_pbx_frameworks_refs`, `$additional_pbx_resources_build`,
`$additional_pbx_resources_refs`. A bare `$placeholder` where a value belongs is not valid
OpenStep plist, so Xcode said only *"The project 'Pinfall' is damaged and cannot be opened due
to a parse error"* — four runs, three wrong theories, all of them about objectVersion 46.

The two files were byte-identical apart from those six lines: 15,864 against 16,032. **The diff
answered in one run what five theories could not.**

**3. Godot 4.6.3's template needs Xcode 16.** Under 15.4 every source file compiles and the link
dies on `__swift_FORCE_LOAD_$_swift_Builtin_float`, with `SwiftUICore`, `_LocationEssentials`,
`AudioUnit` and `CoreAudioTypes` all "not found". Those are iOS 18 SDK libraries.

## The workflow shape that resulted

`export` on **ubuntu-latest** (Godot imports and exports the Xcode project, then FAILS LOUDLY on
an unsubstituted placeholder) → artifact → `compile` on **macos-14** (newest Xcode 16, builds the
shared scheme, asserts the `.app` exists).

Godot never runs on the Mac again. The Mac bills at 10x and now holds the job for 46 seconds.

## Still to do for the App Store

Signing. The record exists — **Pinfall Foundry, 6797051442**, bundle `com.piotraiventures.pinfall`,
profile `Pinfall_AppStore` ACTIVE, team `4X59743R44` — so the second workflow can archive and
upload with a real identity rather than `CODE_SIGNING_ALLOWED=NO`.
