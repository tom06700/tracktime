# Episode list states — checks and changes

## 1. Empty filter — corrected on iPhone

The original empty state collapsed the page and moved the season selector away from its pinned position. A trailing sliver now maintains a viewport below the controls, including while outgoing rows shrink. The device selector remains at y=130 pt for the list and the completed season. A widget regression test reproduces the original 429 px displacement and passes with the correction.

Before: ![Empty filter before](/tmp/nitrate-episode-states/before/02-empty.png)

## 2. Completed season — implemented and checked on iPhone

Known, fully watched seasons show a finite check animation, episode count, review action, and next-season action when available. An unavailable season uses a separate message. Completing an episode or a whole season pins the current season rather than implicitly switching to the next unwatched one.

After: ![Completed season](/tmp/nitrate-episode-states/after/01-complete.png)

The device flow “Revoir les épisodes → Non vus → Saison suivante · 23” succeeds. All three contact sheets from the 69-frame recording `/tmp/nitrate-episode-states/after/flow` were inspected. Reported structural changes correspond to content replacement; the previous large header displacement is absent.

![Next season](/tmp/nitrate-episode-states/after/02-next-season.png)

## 3. Watched episode removal — implemented, verified in widget tests

Stable IDs drive SliverAnimatedList updates. The persisted watched state is shown before fading and collapsing a row over 440 ms; its neighbors follow the shrinking height. Rapid removals/reinsertions and reduced motion are covered. Initial hydration and changes above 24 items use a lazy list reset to avoid allocating hundreds of controllers. The existing 800 ms entrance remains shared by the list.

Removal was not exercised against real phone watch history. The full final-episode and bulk-season completion paths were tested against temporary databases instead. No real watch state was changed during device checks.

## Validation and limits

- 31 widget tests pass: episode cascade/removal, detail navigation and season selector.
- Targeted Dart analysis and git diff --check pass.
- iOS profile build passes; installed and launched on the USB iPhone.
- Existing large-text detail checks pass. New state exposes a semantic heading and native buttons; no claim of a complete VoiceOver audit.
- No Android hardware test or physical rotation test in this change.
- App left on One Piece, season 23, Non vus. Temporary MobAI bridge stopped.
