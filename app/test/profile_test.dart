import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tracktime/profile/profile.dart';

void main() {
  test('profil par défaut : avatar pop-corn, repli de nom', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final profile = await container.read(profileProvider.future);
    expect(profile.emoji, defaultAvatar);
    expect(profile.hasName, isFalse);
    expect(profile.displayName, 'Cinéphile');
  });

  test('setName et setEmoji persistent et mettent à jour l\'état', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(profileProvider.future);

    await container.read(profileProvider.notifier).setName('Thomas');
    await container.read(profileProvider.notifier).setEmoji('🚀');

    final p = container.read(profileProvider).value!;
    expect(p.name, 'Thomas');
    expect(p.displayName, 'Thomas');
    expect(p.emoji, '🚀');

    // Persistance : un nouveau container relit les mêmes valeurs.
    final c2 = ProviderContainer();
    addTearDown(c2.dispose);
    final reloaded = await c2.read(profileProvider.future);
    expect(reloaded.name, 'Thomas');
    expect(reloaded.emoji, '🚀');
  });

  test('« membre depuis » est stable entre deux lectures', () async {
    SharedPreferences.setMockInitialValues({});
    final c1 = ProviderContainer();
    addTearDown(c1.dispose);
    final first = await c1.read(profileProvider.future);

    final c2 = ProviderContainer();
    addTearDown(c2.dispose);
    final second = await c2.read(profileProvider.future);

    expect(second.since, first.since);
  });
}
