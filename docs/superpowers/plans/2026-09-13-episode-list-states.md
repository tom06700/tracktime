# Episode list states

User approved examining and improving three related episode-list behaviors.

Current device evidence: `/tmp/nitrate-episode-states/before/01-list.png` and `02-empty.png`, both inspected. Season 23 Non vus has pinned controls; season 22 Non vus moves the controls far down the page and only says “Aucun épisode à afficher.” Source inspection shows watched entries are filtered synchronously, with no removal transition.

- [x] Keep a minimum viewport of content below the episode controls using a trailing layout-aware spacer, for empty and short lists. Preserve lazy rendering and normal scrolling.
- [x] Render a season-complete state only when the season has known episodes and all are watched. Include a small finite check animation, count, “Saison suivante” when available, and “Revoir les épisodes”. Do not auto-switch season when marking its final episode.
- [x] Diff stable episode IDs through SliverAnimatedList. Confirm the persisted watched state, then fade and collapse the removed row in 440 ms. Other rows move with its height; repeated actions and reduced motion must settle safely.
- [x] Verify with widget tests, static analysis, iOS profile build, and device checks; stop temporary automation afterward. Do not alter real watch history for tests.

Validation: 31 Flutter widget tests pass; targeted analysis and git diff --check pass; iOS profile build installed and launched. Device screenshots and a 69-frame recording confirm the complete-state, review and next-season flow. Removal and bulk completion were verified with temporary test databases, without changing real watch history. MobAI stopped after checks.
