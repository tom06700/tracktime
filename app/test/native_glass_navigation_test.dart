import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tracktime/widgets/nav_bar.dart';

void main() {
  const availability = MethodChannel('nitrate/native_navigation');
  const views = SystemChannels.platform_views;
  const items = [
    NavItem(icon: Icons.tv_outlined, label: 'Séries'),
    NavItem(icon: Icons.movie_outlined, label: 'Films'),
    NavItem(icon: Icons.travel_explore_outlined, label: 'Explorer'),
    NavItem(icon: Icons.person_outline, label: 'Profil'),
  ];
  final calls = <MethodCall>[];
  final viewCalls = <MethodCall>[];
  int? viewId;
  Widget host(ValueChanged<int> onSelected) => MaterialApp(
    home: Scaffold(
      bottomNavigationBar: NitrateNavBar(
        items: items,
        selectedIndex: 0,
        onSelected: onSelected,
      ),
    ),
  );
  setUp(() {
    calls.clear();
    viewCalls.clear();
    viewId = null;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(availability, (_) async => true);
    messenger.setMockMethodCallHandler(views, (call) async {
      if (call.method == 'create') {
        viewId = (call.arguments as Map)['id'] as int;
        messenger.setMockMethodCallHandler(
          MethodChannel('nitrate/native_navigation/$viewId'),
          (call) async {
            calls.add(call);
            return null;
          },
        );
      }
      viewCalls.add(call);
      return null;
    });
  });
  tearDown(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(availability, null);
    messenger.setMockMethodCallHandler(views, null);
    if (viewId != null) {
      messenger.setMockMethodCallHandler(
        MethodChannel('nitrate/native_navigation/$viewId'),
        null,
      );
    }
  });
  testWidgets(
    'native tabs receive gestures directly and own accessibility',
    (t) async {
      final visits = <int>[];
      await t.pumpWidget(host(visits.add));
      await t.pumpAndSettle();
      final native = t.widget<UiKitView>(find.byType(UiKitView));
      expect(
        (native.gestureRecognizers?.any(
              (f) => f.type == EagerGestureRecognizer,
            ) ??
            false),
        isTrue,
      );
      final blockers = t.widgetList<IgnorePointer>(
        find.ancestor(
          of: find.byType(UiKitView),
          matching: find.byType(IgnorePointer),
        ),
      );
      expect(blockers.any((w) => w.ignoring), isFalse);
      await t.tapAt(t.getCenter(find.byType(UiKitView)));
      expect(
        visits,
        isEmpty,
        reason: 'Only UIKit can resolve the actual native tab target',
      );
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'iOS 26 mounts native glass without changing reserved height',
    (t) async {
      await t.pumpWidget(host((_) {}));
      final before = t.getSize(
        find.byKey(const ValueKey('navigation-foundation')),
      );
      await t.pumpAndSettle();
      expect(find.byType(UiKitView), findsOneWidget);
      expect(
        t.getSize(find.byKey(const ValueKey('navigation-foundation'))),
        before,
      );
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'native host spans the screen so UIKit supplies the glass margins',
    (t) async {
      await t.pumpWidget(host((_) {}));
      await t.pumpAndSettle();
      final rect = t.getRect(find.byType(UiKitView));
      final screen = t.getSize(find.byType(Scaffold));
      expect(rect.left, 0);
      expect(rect.right, screen.width);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'older iOS keeps the existing interactive navbar',
    (t) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(availability, (_) async => false);
      final visits = <int>[];
      await t.pumpWidget(host(visits.add));
      await t.pumpAndSettle();
      expect(find.byType(UiKitView), findsNothing);
      await t.tap(find.text('Films'));
      expect(visits, [1]);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'native committed selections notify Flutter and reject invalid indices',
    (t) async {
      final visits = <int>[];
      await t.pumpWidget(host(visits.add));
      await t.pumpAndSettle();
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      for (final value in [0, -1, 4, 'bad', 2]) {
        await messenger.handlePlatformMessage(
          'nitrate/native_navigation/$viewId',
          const StandardMethodCodec().encodeMethodCall(
            MethodCall('selected', value),
          ),
          (_) {},
        );
      }
      expect(visits, [2]);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'native glass is hidden while a Flutter dialog covers the page',
    (t) async {
      final visits = <int>[];
      await t.pumpWidget(host(visits.add));
      await t.pumpAndSettle();
      final context = t.element(find.byType(NitrateNavBar));
      showDialog<void>(
        context: context,
        builder: (_) => const AlertDialog(title: Text('Fenêtre')),
      );
      await t.pumpAndSettle();
      final opacity = find
          .ancestor(of: find.byType(UiKitView), matching: find.byType(Opacity))
          .first;
      expect(t.widget<Opacity>(opacity).opacity, 0);
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
            'nitrate/native_navigation/$viewId',
            const StandardMethodCodec().encodeMethodCall(
              const MethodCall('selected', 2),
            ),
            (_) {},
          );
      expect(
        visits,
        isEmpty,
        reason: 'A covered bar cannot navigate behind a modal',
      );

      Navigator.of(context).pop();
      await t.pumpAndSettle();
      expect(t.widget<Opacity>(opacity).opacity, 1);
      expect(viewCalls.where((c) => c.method == 'create'), hasLength(1));
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'Android never requests native glass and keeps its tap behavior',
    (t) async {
      var checks = 0;
      final visits = <int>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(availability, (_) async {
            checks++;
            return true;
          });
      await t.pumpWidget(host(visits.add));
      await t.pumpAndSettle();
      await t.tap(find.text('Films'));
      expect(visits, [1]);
      expect(checks, 0);
      expect(find.byType(UiKitView), findsNothing);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
}
