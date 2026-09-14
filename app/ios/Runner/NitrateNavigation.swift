import Flutter
import UIKit

final class NitrateNavigationFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger

  init(messenger: FlutterBinaryMessenger) { self.messenger = messenger }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }

  func create(
    withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?
  ) -> FlutterPlatformView {
    NitrateNavigationView(frame: frame, id: viewId, messenger: messenger, args: args)
  }
}

private final class NitrateNavigationView: NSObject, FlutterPlatformView {
  private let controller: NitrateTabController
  private let channel: FlutterMethodChannel

  init(frame: CGRect, id: Int64, messenger: FlutterBinaryMessenger, args: Any?) {
    channel = FlutterMethodChannel(
      name: "nitrate/native_navigation/\(id)", binaryMessenger: messenger
    )
    controller = NitrateTabController()
    super.init()
    controller.loadViewIfNeeded()
    controller.view.frame = frame
    controller.configure(args as? [String: Any] ?? [:])
    controller.onSelection = { [weak self] index in
      self?.channel.invokeMethod("selected", arguments: index)
    }
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else { result(nil); return }
      guard call.method == "update", let data = call.arguments as? [String: Any] else {
        result(FlutterMethodNotImplemented)
        return
      }
      self.controller.configure(data)
      result(nil)
    }
  }

  func view() -> UIView { controller.view }

  deinit { channel.setMethodCallHandler(nil) }
}

/// UIKit owns its actual hit targets, glass interaction and accessibility.
/// Only committed selections cross the bridge to Flutter's page router.
private final class NitrateTabController: UITabBarController, UITabBarControllerDelegate {
  var onSelection: ((Int) -> Void)?
  private var labels: [String] = []
  private var symbols: [String] = []
  private var selection = NitrateNavigationSelection()
  private lazy var touchObserver = NitrateTabTouchObserver { [weak self] phase in
    guard let self else { return }
    switch phase {
    case .began:
      self.selection.begin()
    case .moved(let point):
      self.selection.isWithinVerticalBounds =
        point.y >= -20 && point.y <= self.tabBar.bounds.height + 20
    case .ended(let cancelled):
      let token = self.selection.end(cancelled: cancelled)
      if cancelled { self.selectedIndex = self.selection.committed }
      // Let UIKit deliver its final didSelect for the same touch event first.
      DispatchQueue.main.async { [weak self] in
        guard let self else { return }
        if let index = self.selection.finish(token) {
          self.onSelection?(index)
        }
        if !self.selection.tracking { self.selectedIndex = self.selection.preview }
      }
    }
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    delegate = self
    view.backgroundColor = .clear
    view.isOpaque = false
    tabBar.isTranslucent = true
    tabBar.addGestureRecognizer(touchObserver)
    // Do not assign a UIBlurEffect or opaque appearance: iOS supplies Liquid Glass.
  }

  func configure(_ data: [String: Any]) {
    let nextLabels = data["labels"] as? [String] ?? labels
    let nextSymbols = data["symbols"] as? [String] ?? symbols
    overrideUserInterfaceStyle = (data["isDark"] as? Bool ?? true) ? .dark : .light
    if let argb = data["tintColor"] as? NSNumber {
      let color = argb.uint32Value
      tabBar.tintColor = UIColor(
        red: CGFloat((color >> 16) & 255) / 255,
        green: CGFloat((color >> 8) & 255) / 255,
        blue: CGFloat(color & 255) / 255,
        alpha: CGFloat((color >> 24) & 255) / 255
      )
    }
    if nextLabels != labels || nextSymbols != symbols {
      labels = nextLabels
      symbols = nextSymbols
      let pages = labels.enumerated().map { index, label in
        let page = UIViewController()
        page.view.backgroundColor = .clear
        page.view.isOpaque = false
        page.tabBarItem = UITabBarItem(
          title: label,
          image: UIImage(systemName: index < symbols.count ? symbols[index] : "circle"),
          tag: index
        )
        page.tabBarItem.accessibilityIdentifier = "nitrate-tab-\(index)"
        return page
      }
      setViewControllers(pages, animated: false)
    }
    if let index = data["selectedIndex"] as? Int,
       labels.indices.contains(index) {
      selection.synchronize(index)
      guard !selection.tracking, index != selectedIndex else { return }
      if data["reduceMotion"] as? Bool == true || UIAccessibility.isReduceMotionEnabled {
        UIView.performWithoutAnimation { self.selectedIndex = index }
      } else {
        selectedIndex = index
      }
    }
  }

  func tabBarController(_ tabBarController: UITabBarController, shouldSelect viewController: UIViewController) -> Bool {
    if (UIAccessibility.isVoiceOverRunning || UIAccessibility.isSwitchControlRunning)
        && !selection.tracking {
      // An accessibility activation is not a continuation of a cancelled touch.
      selection = NitrateNavigationSelection()
      selection.synchronize(selectedIndex)
    }
    return selection.canSelect
  }

  func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
    if let index = selection.select(viewController.tabBarItem.tag) {
      onSelection?(index)
    }
  }
}

/// Passive observation: never wins recognition, cancels controls, delays their
/// touch events or inspects UIKit's private subviews. UIKit resolves each tab.
private final class NitrateTabTouchObserver: UIGestureRecognizer {
  enum Phase { case began, moved(CGPoint), ended(Bool) }
  private let onPhase: (Phase) -> Void
  private weak var finger: UITouch?

  init(onPhase: @escaping (Phase) -> Void) {
    self.onPhase = onPhase
    super.init(target: nil, action: nil)
    cancelsTouchesInView = false
    delaysTouchesBegan = false
    delaysTouchesEnded = false
  }

  override func canPrevent(_ preventedGestureRecognizer: UIGestureRecognizer) -> Bool { false }
  override func canBePrevented(by preventingGestureRecognizer: UIGestureRecognizer) -> Bool { false }

  override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
    guard finger == nil, touches.count == 1, let touch = touches.first else {
      onPhase(.ended(true))
      state = .failed
      return
    }
    finger = touch
    onPhase(.began)
  }

  override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
    guard let finger else { return }
    onPhase(.moved(finger.location(in: view)))
  }

  override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
    guard let finger, touches.contains(finger) else { return }
    onPhase(.moved(finger.location(in: view)))
    onPhase(.ended(false))
    self.finger = nil
    state = .failed
  }

  override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
    onPhase(.ended(true))
    finger = nil
    state = .failed
  }

  override func reset() {
    super.reset()
    if finger != nil { onPhase(.ended(true)) }
    finger = nil
  }
}
