# Native Liquid Glass navigation

Scope approved: Apple native glass on iOS; preserve the existing Flutter navbar on Android and older iOS, and all current navigation behaviors. No profile redesign.

Implementation: a small UIKit UITabBarController platform view, registered in the existing implicit Flutter engine. The system owns the glass appearance. No new dependency. Native selection uses Nitrate lilac and the four existing destinations. Flutter owns physical taps and drag preview/cancel/commit, with an accessible tab semantics overlay; the native view is visual-only so its gesture recognizer cannot consume short taps. Re-taps and invalid callback indices are ignored. Side margins are 12 logical pixels, widening the bar by 16 pixels. The existing scroll scaffold, page IndexedStack, safe area and allocated height are retained. The native surface is hidden when a Flutter route/modal covers it. Capability/channel failure falls back to the existing GlideControl.

Verification: 23 Flutter widget tests across native bridge/navigation/scroll navigation pass. Covers physical taps over the platform view (reproduced failing before the fix), expanded width, deferred drag commit, cancellation, native callbacks, invalid indices, no geometry jump, modal occlusion, old iOS and Android fallback, semantics and existing scroll behavior. Targeted analyzer clean. Xcode 26.4.1 signed profile build succeeds. Installed and launched on Tom’s iPhone 17 Pro via devicectl, without starting UI automation as requested.

Limit: device launch is not visual or touch verification. Native material over Flutter pixels, native item geometry and drag animation fidelity still need user inspection on the physical phone. No claim of measured on-device frame rate or Android device testing.

References consulted: https://developer.apple.com/videos/play/wwdc2025/219/ ; https://docs.flutter.dev/platform-integration/ios/platform-views ; https://pub.dev/packages/native_glass_navbar ; https://pub.dev/packages/native_liquid_glass . Native implementation uses public UIKit APIs and no hard-coded private subview names.
