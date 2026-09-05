# Native Flutter design QA — Nitrate

> Revue historique, antérieure à la refonte de septembre 2026. Le verdict
> ci-dessous ne valide ni la nouvelle branche ni le niveau artistique demandé.
> Nouvelle intro, accueil et composants : validation iPhone à effectuer par le
> propriétaire après livraison du lot. Aucun nouveau rendu natif inspecté ici.


Source visual truth: selected first image, `exec-f3a6a009-8547-4537-bfcf-fe004fd132ce.png` (854 × 1844).
Implementation: GitHub Actions native Flutter widget captures, 390 × 844 logical pixels, 780 × 1688 PNG; device padding top 59 / bottom 34 logical pixels. Both images are normalized to 390 × 844 for comparisons. The source omits system safe areas; these remain respected in the app.
State: dark home, Severance S02 E03, queued shows below. Catalogue posters and number of queued shows follow real fixture data; the mock contains different works. No claim of a pixel-identical poster collage.

## Comparison history

1. Initial native capture: One Piece featured instead of Severance (fixture state mismatch); cards overlapped the navigation. Corrected watched timestamp setup and reduced the hero's reserved artwork space from 199 to 148 px at this viewport.
2. `comparison-v2.png`: correct series and episode. P1: header contrast insufficient over the pale catalogue backdrop. Added a stronger top scrim. P2: yellow controls on other pages conflicted with the ivory home. Unified the shared theme and editorial detail titles.
3. `comparison-verified.png` and `controls-verified.png`: the revised header remains readable over the pale backdrop; hero title, both actions and posters are visible at the target viewport. Films, detail pages, settings and the empty state now share the ivory palette. The generated auditorium is sharp with no overflow. Movie fixture matching was corrected (Dune: Part One and Parasite), and long-film artwork follows its own title. Native render capture has no recorded Flutter exceptions.

Full-view evidence: `/workspace/scratch/86a9308c78e7/cinema-audit/comparison-verified.png`.
Focused controls evidence: `/workspace/scratch/86a9308c78e7/cinema-audit/controls-verified.png`.
Final implementation evidence: `/workspace/scratch/86a9308c78e7/cinema-audit/verified/01-series.png` plus 21 other states in Actions artifact 9967516071, run 33959567267.

Remaining P3/intentional differences: the generated corridor is replaced by real series art; library size follows the user data; the native safe area places the wordmark lower; the library shortcut uses Material iconography and settings remains directly accessible. The title's serif face is close rather than an exact proprietary-font match. No claim of pixel-identical reproduction.

## Required fidelity surfaces

- Typography: bundled Cormorant Garamond Medium for wordmark and display headings, system UI font for functional copy. Outlined SVG exports share the same glyph shapes. Native title truncation and enlarged-text behavior retain existing limits.
- Layout: full-bleed artwork, 24 px home gutters, pill actions, vertical poster queue, floating navigation. Safe areas intentionally differ from the generated mock. Secondary library access remains in the header.
- Color: ink #080C0B and ivory #F3E7CF, muted green surfaces, opaque high-contrast navigation, stronger top image scrim.
- Imagery: actual TheTVDB catalogue imagery replaces the mock's generated corridor and invented posters. This is an intentional dynamic-content constraint, not a promise to reproduce that particular corridor. Original auditorium illustration is used only for the empty state.
- Copy: functional French copy; episode names come from metadata. No playback promise: “Voir l’épisode” opens the episode details.

## Interaction evidence

274 tests and static analysis pass in Flutter CI run 33959567271. The opt-in audit renders page navigation, series/movie details, library, history, settings, import, search and watched states. The animation clip captures the watched action advancing S02 E03 to E04 and opening its detail sheet.

## Scope and gaps

The existing project explicitly requires Flutter iOS/Android and golden checks, with no web target. Native widget renders therefore replace the Product Design browser prototype gate. Real-device iPhone frame rate, system gestures, VoiceOver and signed installation remain unverified; the widget-test video cannot establish those. TestFlight is a separate manual Codemagic build.

## Implementation checklist

- [x] Native identity and bundled assets
- [x] Immersive home and motion
- [x] Shared page typography/colors
- [x] Corrected image/contrast findings and recaptured
- [x] Static analysis, 274 tests, 22 native captures and 3-second animation export
- [ ] Physical iPhone performance and signed TestFlight installation (separate device check)

final result: passed
Native implementation review; device verification limits remain as stated.
