# Native navbar interaction

Approved scope: let UIKit own its tab hit targets and Liquid Glass touch response; preserve release-only page changes, cancellation, vertical exit, scroll hiding, width and Android behavior. No redesign or automatic iPhone UI testing.

1. Add a regression proving supported iOS forwards physical gestures directly to its platform view, instead of interpreting them with the Flutter overlay. Keep fallback tests.
2. Add a small independently executable Swift selection-state test suite covering preview, release, cancellation, duplicate callbacks, accessibility and external selection changes.
3. Make UIKit own touches and accessibility. Observe its touch lifecycle without preventing or delaying its gestures; gate Flutter page callbacks until release. Use native selection callbacks, with no guessed item rectangles or private subviews.
4. Run targeted Flutter tests, Swift state tests, analyzer, and a signed profile build. Install and launch using devicectl without automation. Report that physical touch/visual verification still requires the user.
