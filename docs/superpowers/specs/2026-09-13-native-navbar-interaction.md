# Native navbar interaction refinement

Approved after the technical review: improve native tab hit-target correspondence and touch feedback while keeping four tabs, 12-point outer side margins, release-only page changes, cancellation and scroll hiding. Android and older iOS retain GlideControl and the existing Flutter gestures. User requested no iPhone automation.

## Implementation

- Supported iOS sends touches eagerly to UiKitView. The native UIKit tab bar owns exact item targeting, glass touch responses and accessibility; there is no Flutter overlay estimating native item rectangles.
- Flutter gesture recognition wraps only the fallback navbar.
- A passive UIKit recognizer observes touch begin/end/cancel without recognizing, delaying or preventing system gestures. UIKit selection events update a preview; only after release does the selected destination cross the channel.
- NitrateNavigationSelection isolates commit state, stale-release tokens, cancellation, vertical exit and externally requested page changes. VoiceOver and Switch Control activation remain available after cancellation.
- Covered routes hide the bar, suppress its semantics and reject late selection callbacks behind the modal.
- Uses public UIKit APIs. No custom private subview lookup, synthesized UITouch or new package dependency.

## Verification

The new Flutter regression initially failed because native input was intercepted. Native preview/cancel tests previously simulated the removed Flutter overlay; those cases now run against the Swift selection state. Targeted Flutter tests cover eager native delivery, capability fallback, callback validation, geometry, modal suppression, Android input, and scroll behavior. Native state tests cover eight interaction-ordering scenarios.

Commands:

```sh
cd app
flutter test --no-pub test/native_glass_navigation_test.dart test/nav_bar_test.dart test/scroll_navigation_test.dart
swiftc -module-cache-path /tmp/nitrate-swift-cache ios/Runner/NitrateNavigationSelection.swift test/native_navigation_selection/main.swift -o /tmp/nitrate-selection-tests
/tmp/nitrate-selection-tests
flutter build ios --profile --no-pub
```

Limits: widget tests mock the UIKit surface, and Swift tests exercise selection state rather than UIKit rendering or actual gestures. Native press/scrub fidelity, VoiceOver, Dynamic Type, contrast and frame rate still need physical-device inspection. No Android device verification is claimed.

References: https://developer.apple.com/videos/play/wwdc2025/284/ ; https://developer.apple.com/design/human-interface-guidelines/tab-bars ; UIKit UIGestureRecognizer and UIGestureRecognizerSubclass public SDK headers.
