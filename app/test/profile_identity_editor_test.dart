import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tracktime/profile/profile.dart';
import 'package:tracktime/profile/identity_editor.dart';
import 'package:tracktime/theme.dart';

void main() {
  testWidgets('annuler conserve nom et avatar ; enregistrer persiste les deux',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'profile_name': 'Thomas',
      'profile_emoji': '🍿',
      'profile_since': 1234
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(profileProvider.future);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
            theme: buildTheme(),
            home: Scaffold(
                body: Builder(
                    builder: (context) => TextButton(
                        onPressed: () => editProfile(
                            context, container.read(profileProvider).value!),
                        child: const Text('Modifier')))))));
    Future<void> draft() async {
      await tester.tap(find.text('Modifier'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Camille');
      await tester.ensureVisible(find.text('🚀'));
      await tester.tap(find.text('🚀'));
      await tester.pump();
    }

    await draft();
    expect(container.read(profileProvider).value!.name, 'Thomas');
    expect(container.read(profileProvider).value!.emoji, '🍿');
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    final afterCancel = ProviderContainer();
    addTearDown(afterCancel.dispose);
    final unchanged = await afterCancel.read(profileProvider.future);
    expect(unchanged.name, 'Thomas');
    expect(unchanged.emoji, '🍿');
    await draft();
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    expect(find.text('Ton profil'), findsNothing);
    final reloaded = ProviderContainer();
    addTearDown(reloaded.dispose);
    final saved = await reloaded.read(profileProvider.future);
    expect(saved.name, 'Camille');
    expect(saved.emoji, '🚀');
    expect(saved.since, unchanged.since);
  });

  test('une identité invalide ne remplace pas les préférences existantes',
      () async {
    SharedPreferences.setMockInitialValues({
      'profile_name': 'Thomas',
      'profile_emoji': '🍿',
      'profile_identity_v1': '{"name":42,"emoji":null}'
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final profile = await container.read(profileProvider.future);
    expect(profile.name, 'Thomas');
    await expectLater(
        container
            .read(profileProvider.notifier)
            .saveIdentity(name: 'Camille', emoji: 'inconnu'),
        throwsArgumentError);
    expect(container.read(profileProvider).value!.name, 'Thomas');
  });
}
