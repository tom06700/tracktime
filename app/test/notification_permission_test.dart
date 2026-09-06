import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tracktime/notifications/notification_permission.dart';
import 'package:tracktime/onboarding/notification_screen.dart';
import 'package:tracktime/theme.dart';

class FakePermission extends NotificationPermission {
  NotificationAccess current = NotificationAccess.notDetermined;
  NotificationAccess answer = NotificationAccess.authorized;
  int reads = 0, requests = 0, settings = 0;
  bool fail = false;
  Completer<NotificationAccess>? pending;
  @override
  Future<NotificationAccess> status() async {
    reads++;
    return current;
  }

  @override
  Future<NotificationAccess> request() async {
    requests++;
    if (fail) throw PlatformException(code: 'failed');
    return pending == null ? answer : pending!.future;
  }

  @override
  Future<void> openSettings() async {
    settings++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
      'la permission native relit le statut et ne redemande pas après une décision',
      () async {
    final calls = <String>[];
    var status = 'notDetermined';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(NotificationPermission.channel, (call) async {
      calls.add(call.method);
      if (call.method == 'request') status = 'authorized';
      return status;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(NotificationPermission.channel, null));
    const permission = NotificationPermission();
    expect(await permission.request(), NotificationAccess.authorized);
    expect(calls, ['status', 'request']);
    calls.clear();
    expect(await permission.request(), NotificationAccess.authorized);
    expect(calls, ['status']);
    status = 'denied';
    calls.clear();
    expect(await permission.request(), NotificationAccess.denied);
    expect(calls, ['status']);
  });

  Future<void> mount(
      WidgetTester tester, FakePermission permission, VoidCallback finish,
      {double scale = 1, bool reduce = true}) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
        theme: buildTheme(),
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
                disableAnimations: reduce,
                textScaler: TextScaler.linear(scale)),
            child: child!),
        home: NotificationScreen(
            permission: permission,
            onFinish: () async {
              finish();
            })));
    await tester.pump();
  }

  Future<void> tap(WidgetTester tester, String label) async {
    await tester.ensureVisible(find.text(label));
    await tester.pump();
    await tester.tap(find.text(label));
    await tester.pump();
  }

  testWidgets('libellés centrés avec ou sans cloche et après permission',
      (tester) async {
    final permission = FakePermission()
      ..current = NotificationAccess.authorized;
    await mount(tester, permission, () {});
    void centered(String label) {
      final text = find.text(label);
      final button =
          find.ancestor(of: text, matching: find.byType(FilledButton));
      expect(
          tester.getCenter(text).dx, closeTo(tester.getCenter(button).dx, .1));
    }

    centered('Continuer');
    await tester.pumpWidget(const SizedBox());
    permission.current = NotificationAccess.notDetermined;
    await mount(tester, permission, () {});
    centered('Activer les notifications');
    await tap(tester, 'Activer les notifications');
    centered('Découvrir Nitrate');
  });

  testWidgets('Plus tard continue sans jamais demander la permission',
      (tester) async {
    final permission = FakePermission();
    var finishes = 0;
    await mount(tester, permission, () => finishes++);
    expect(permission.requests, 0);
    await tap(tester, 'Plus tard');
    expect(finishes, 1);
    expect(permission.requests, 0);
  });
  for (final allowed in [true, false]) {
    testWidgets(
        'la réponse réelle ${allowed ? 'accordée' : 'refusée'} laisse continuer',
        (tester) async {
      final permission = FakePermission()
        ..answer =
            allowed ? NotificationAccess.authorized : NotificationAccess.denied;
      var finishes = 0;
      await mount(tester, permission, () => finishes++);
      await tap(tester, 'Activer les notifications');
      expect(permission.requests, 1);
      expect(find.text(allowed ? 'Autorisation accordée.' : 'À ton rythme.'),
          findsOneWidget);
      await tap(tester, 'Découvrir Nitrate');
      expect(finishes, 1);
    });
  }
  testWidgets('déjà autorisé ne demande pas à nouveau', (tester) async {
    final permission = FakePermission()
      ..current = NotificationAccess.authorized;
    var finishes = 0;
    await mount(tester, permission, () => finishes++);
    await tap(tester, 'Continuer');
    expect(finishes, 1);
    expect(permission.requests, 0);
  });
  testWidgets('erreur, réessai et double appui sans fausse confirmation',
      (tester) async {
    final permission = FakePermission()..fail = true;
    await mount(tester, permission, () {});
    await tap(tester, 'Activer les notifications');
    expect(find.textContaining('La demande n’a pas abouti'), findsOneWidget);
    permission.fail = false;
    permission.pending = Completer<NotificationAccess>();
    await tap(tester, 'Activer les notifications');
    await tap(tester, 'Un instant…');
    expect(permission.requests, 2);
    expect(find.text('Autorisation accordée.'), findsNothing);
    permission.pending!.complete(NotificationAccess.denied);
    await tester.pump();
    expect(find.text('À ton rythme.'), findsOneWidget);
  });
  testWidgets('texte agrandi, mouvement réduit et retour des réglages',
      (tester) async {
    final permission = FakePermission()..current = NotificationAccess.denied;
    await mount(tester, permission, () {}, scale: 2);
    tester.view.physicalSize = const Size(320, 568);
    await tester.pump();
    await tap(tester, 'Ouvrir les réglages');
    expect(permission.settings, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    permission.current = NotificationAccess.authorized;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('Continuer'), findsOneWidget);
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(tester.takeException(), isNull);
  });
  testWidgets('les boucles s’arrêtent hors écran et reprennent au retour',
      (tester) async {
    await mount(tester, FakePermission(), () {}, reduce: false);
    await tester.pump(const Duration(seconds: 1));
    expect(tester.binding.hasScheduledFrame, isTrue);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isFalse);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isTrue);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
