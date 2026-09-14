// Run with swiftc ios/Runner/NitrateNavigationSelection.swift
// test/native_navigation_selection/main.swift -o /tmp/nitrate-selection-tests
func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
  precondition(condition(), message)
}
var s = NitrateNavigationSelection()
s.begin()
expect(s.select(1) == nil, "A touch previews without navigating")
expect(s.select(3) == nil, "Crossing tabs must not navigate")
expect(s.committed == 0, "Page stays unchanged while finger is down")
let release = s.end(cancelled: false)
expect(s.select(2) == nil, "UIKit's final selection can arrive after touchesEnded")
expect(s.finish(release) == 2, "Release commits the last native selection")
expect(s.select(2) == nil, "Duplicate native callback is ignored")
s.begin()
_ = s.select(1)
let cancel = s.end(cancelled: true)
expect(s.select(3) == nil, "Late callbacks after cancellation are ignored")
expect(s.finish(cancel) == nil && s.preview == 2, "Cancel restores the current page")
s.begin()
_ = s.select(1)
s.isWithinVerticalBounds = false
expect(!s.canSelect && s.select(3) == nil, "Vertical exit pauses preview")
expect(s.finish(s.end(cancelled: false)) == 1, "Release outside keeps last valid tab")
s.begin()
_ = s.select(3)
let stale = s.end(cancelled: false)
s.begin()
expect(s.finish(stale) == nil && s.committed == 1, "A stale release cannot commit a new gesture")
_ = s.select(2)
s.synchronize(0)
expect(s.finish(s.end(cancelled: false)) == nil && s.committed == 0,
       "An external page change cancels the pending gesture")
// Accessibility is a new native activation, independent of touch tracking.
s = NitrateNavigationSelection()
expect(s.select(3) == 3, "VoiceOver activation commits without a physical touch")
print("Native selection: 8 scenarios passed")
