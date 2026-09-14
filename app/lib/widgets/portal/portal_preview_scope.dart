import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Only reachable from the non-release preview route. Does not override or
/// delete library data; it changes which empty-state widget is presented.
class PortalPreviewScope extends InheritedWidget {
  const PortalPreviewScope({super.key, required super.child});
  static bool enabled(BuildContext context) =>
      !kReleaseMode &&
      context.dependOnInheritedWidgetOfExactType<PortalPreviewScope>() != null;
  @override
  bool updateShouldNotify(PortalPreviewScope old) => false;
}
