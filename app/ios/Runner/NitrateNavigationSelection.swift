/// Keeps native tab previews separate from the page committed to Flutter.
/// Independent of UIKit so gesture ordering and cancellation can be tested.
struct NitrateNavigationSelection {
  private(set) var committed = 0
  private(set) var preview = 0
  private(set) var tracking = false
  var isWithinVerticalBounds = true
  private var finishing = false
  private var cancelled = false
  private var generation = 0

  var canSelect: Bool { !cancelled && isWithinVerticalBounds }

  mutating func begin() {
    generation += 1
    tracking = true
    finishing = false
    cancelled = false
    isWithinVerticalBounds = true
    preview = committed
  }

  mutating func select(_ index: Int) -> Int? {
    guard canSelect else { return nil }
    preview = index
    guard !tracking && !finishing else { return nil }
    return commit()
  }

  mutating func end(cancelled: Bool) -> Int {
    tracking = false
    finishing = true
    self.cancelled = self.cancelled || cancelled
    if self.cancelled { preview = committed }
    return generation
  }

  mutating func finish(_ token: Int) -> Int? {
    guard token == generation, finishing else { return nil }
    finishing = false
    guard !cancelled else { return nil }
    return commit()
  }

  mutating func synchronize(_ index: Int) {
    guard index != committed else { return }
    generation += 1
    committed = index
    preview = index
    cancelled = tracking || finishing
    finishing = false
  }

  private mutating func commit() -> Int? {
    guard preview != committed else { return nil }
    committed = preview
    return committed
  }
}
