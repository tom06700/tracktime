# Episode list cascade implementation

Approved reference: option 1, V2 of `design/interactive/episode-list-motion/`.

One visible feature: port the selected entrance to the official episode list.

- [x] Add a focused widget test for lazy lists: the first visible entrance completes in 800 ms, ordinary rebuilds and scrolling never restart it, changing the view restarts it, reduced motion shows content immediately.
- [x] Add `app/lib/series/widgets/episode_cascade_sliver.dart`: one animation controller per list, six staggered rows maximum, 520 ms row entry with 56 ms offsets, 20 px rise, title 400 ms with 45 ms delay and 4 px rise, status 320 ms with 110 ms delay, cubic (.2, .75, .2, 1). Start only once the sliver reaches the viewport. Keep lazy construction and stable episode keys.
- [x] Wire the sliver and title/status transitions into `show_detail_screen.dart`, keyed by season and filter. Preserve the existing check interaction, network loading, navigation and scrolling behavior.
- [x] Run the new widget tests, existing detail navigation and season selector tests, and targeted analysis. Build iOS profile, install on the connected phone, inspect season changes and list scrolling, stop temporary automation afterward.

No production skeleton redesign, dependency change, background timer, recurring animation, commit or push is part of this change.

User added portrait locking during implementation: iPhone `UISupportedInterfaceOrientations` now permits portrait only; Android main activity uses `screenOrientation="portrait"`. The iPad-specific orientation list is unchanged.

Validation: 25 widget tests pass (cascade, detail navigation, season selector); targeted analysis passes; native orientation configuration parsed successfully; iOS profile build passes and the built Info.plist contains portrait only. Installed and launched on the connected iPhone after it was unlocked.

Device checks on One Piece: season 23 → 22 → 23, Tous/Non vus, scrolling and settled list visibility. Recording `/tmp/nitrate-cascade-device/filter` exposed rows beyond index 5 appearing prematurely. Fixed by letting additional rows share the sixth stagger phase instead of skipping the animation. This preserves the 800 ms maximum and the single controller. Rebuilt, reinstalled and recorded `/tmp/nitrate-cascade-device/final`; both contact sheets inspected, the premature lower-row appearance is resolved. Empty Non vus still lets the short page clamp its scroll position (existing page behavior, outside this entrance change).

App left open on One Piece, season 23, Tous. Temporary MobAI bridge stopped successfully. Android portrait setting verified in its manifest; no Android device was connected for a physical rotation test.
