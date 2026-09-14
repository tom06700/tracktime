# Navbar — physical iPhone check

Device: Tom’s iPhone, iPhone18,1, iOS 27.0, logical viewport 402 × 874. Profile build. MobAI temporarily enabled with explicit user permission and stopped afterwards; final list_devices confirmed bridgeRunning=false. No application source changes during this audit.

## Checks and evidence

1. Initial Séries: centered bar, all four labels visible. Native accessibility frames report 94 × 54 point buttons. Platform-view frame is (12,753,378,79); UIKit tab bar frame is (12,749,378,83). Outer Flutter margins do not describe the visible glass inset by themselves.
2. Taps Films → Explorer → Profil: selected native tabs and actual Flutter destination screens agree. Screenshots: /tmp/nitrate-navbar-check/tap-films.png, tap-explorer.png, tap-profil.png.
3. Return to Séries: native-coordinate tap from the observed OCR position succeeds and the actual Séries page returns. Screenshot: /tmp/nitrate-navbar-check/tap-series.png.
4. Drag Séries → Profil without an initial hold: destination is correct after release. Recorded in /tmp/nitrate-navbar-check/drag-release. Recording does not independently establish the precise commit timestamp relative to finger-up; WDA gesture execution and screenshot scheduling can serialize. No claim of measured frame rate or exact release timing from the contact sheet.
5. Round-trip drag Séries → Explorer → Séries and a vertical exit followed by lateral motion: Séries remains selected after release. Fast reverse swipe Films → Séries succeeds. Re-tapping/double-tapping Films leaves Films selected. These are gesture outcome checks; an OS-level touch cancellation is covered by Swift state tests, not synthesized during this device run.
6. Scroll: navbar disappears after scrolling down and returns after scrolling up. Screenshots: /tmp/nitrate-navbar-check/scroll-hidden.png and scroll-return.png, both inspected.
7. Secondary route: Films vus hides the navbar. Back restores Films selection; subsequent navigation still works. Screenshot: /tmp/nitrate-navbar-check/route-covered.png, inspected.

## Finding requiring follow-up

On Profil, after the transition settles, all four tab buttons disappear from WDA's visible element tree. The bar and labels remain visibly present, and tapping the OCR-observed Séries coordinate works. Reproduced on a second visit. A selector-based tap reports NO_MATCH with an off-screen candidate whose frame is still on-screen. This is an accessibility/hittability discrepancy, not proof that physical taps or VoiceOver itself are broken. Verify native accessibility containment and test with VoiceOver before claiming accessibility complete.

## Limits

No physical Android device was connected. The 21 Flutter tests and 8 independently compiled Swift state scenarios pass, including Android fallback behavior and release/cancel ordering. Dynamic Type, Reduce Transparency, a live VoiceOver pass, exact input/commit timing and on-device frame rate remain unverified. Existing app content/data inconsistencies were outside this navbar audit.

Recordings and original screenshots are local temporary evidence under /tmp/nitrate-navbar-check. Jump/structural hints correspond to deliberate destination changes; they do not establish stutter by themselves. Automation stopped successfully after tests.
