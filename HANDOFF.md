# Status & handoff

Working notes for picking this up in a fresh session. `CLAUDE.md` is the
project spec; this file is where things actually stand.

## Read this first

> **⚠ Nothing since `0d0dcd9` is committed.** 33 modified files and 32 new
> ones are sitting in the working tree: the six grantha letters and their
> stroke data, saved progress, the whole Word Builder game, the picture
> pipeline and its 51 cut-outs, the guide ring, and the home screen rework.
> **The Parent Zone (this session) is on top of that, uncommitted too.**
> **Commit before doing anything that could lose them.**

Open items, in the order they will bite:

1. **The Parent Zone's two outbound links are placeholders.**
   `assets/config/app_config.json` → `parentZone.projectDetailsUrl` and
   `.privacyPolicyUrl` point at `example.com`. CLAUDE.md section 1 requires a
   live privacy policy URL before Play Store submission — replace both before
   shipping. One-line edits, no code change.
2. **Watch Ads to Earn Coin is now a real AdMob rewarded ad**, not a mock —
   see "Round five" below. Builds and launches clean; a full watch-to-reward
   pass on-device hasn't been done yet. Play Console's own side of CLAUDE.md
   section 6's compliance checklist (target-audience declaration, Certified
   Families enrollment) is still outstanding — that part can't be done from
   this codebase.
4. **Picture Puzzle art is missing for five letters.** ஔ and ஃ have no
   picture at all, and வ் ழ் ற் appear in no kept word — so the game cannot
   cover every uyir or every mei yet. Words chosen: ஔவையார்/ஔடதம், எஃகு,
   செவ்வாய், தமிழ், காற்று. `tools/worksheet_art/words.json` records them
   under `_wanted`; drop single pictures in and name them.
5. **Nothing is locked, by design.** `progression.starsToUnlockNext` is `0`
   and stays there: a child picks any character in any order, and the guide
   ring says which one is next (CLAUDE.md section 6). The star-chain logic is
   untouched and `unlock_test.dart` still proves it, so raising the config
   brings gating back intact.
6. **`featureFlags.authoringEnabled` is `false`** — the **Author** button is
   gone from every screen, which is where it should stay. Turning it on does
   two things at once: it puts the button back on every letter list, and it
   makes the picker show categories with no stroke data yet. Both are
   developer tooling. `vadamozhi_test.dart` reads the flag rather than
   assuming it.
7. **Uyirmei carries no example words** — 216 of them cannot honestly be
   invented, so the field is nullable and the letter screen omits the panel.
   The 51 curated words now cover 62 distinct uyirmei between them, which is
   where honest ones could come from.
8. **The celebration star's gold shading has not been looked at on screen.**
   It shares `paintShadedStar()` with the badge mark, which was verified, but
   the full-size one at the centre of the burst has not been seen.
9. **The four other games do not exist.** Word Builder is the only one, and
   the home row holds it directly rather than behind a menu — a Games menu
   arrives when there is a second game to put in it (CLAUDE.md section 3).
10. **Tablets work but do not scale.** Verified 640x360 dp through 1706x1066
    dp: nothing breaks, but the side panels are fixed pixel widths so on a
    tablet they sit small and stranded while the canvas dominates. Making them
    proportional is a contained fix. Below about 570x320 dp the controls column
    overflows — out of scope, phones that small are not a target.

Checks: `flutter analyze && flutter test` — **177 tests** (unchanged this
round — the AdMob integration is a real-network path, not something a widget
test exercises).
`PYTHONIOENCODING=utf-8 PYTHONPATH=tools python tools/trace_batch.py` —
**253 traced, 0 pending, 0 warnings**. The 247 still regenerate
byte-identically, which is the check that adding a category took nothing away
from them.

**A new stroke file needs `flutter clean` before it reaches the device.**
`pubspec.yaml` ships `lib/data/letters/strokes/` as a directory, and both the
Flutter asset step and the Gradle task cache that listing: after tracing the
six grantha letters, two consecutive `flutter build apk --release` runs
(8–10s each) produced an APK still holding exactly 247 stroke files. Deleting
`.dart_tool/flutter_build` was not enough either. `flutter clean` then a full
build (~70s) is what picks them up. The symptom is a letter list that still
says "Author (6 left)" with everything greyed, which reads as a code bug and
is not one — check the APK first:

```bash
unzip -l build/app/outputs/flutter-apk/app-release.apk | grep -c letters/strokes/
```

## Where the app is

Boots to the **category picker** (`lib/features/home/home_screen.dart`)
→ pick a category → **letter list** (`lib/features/letters/letters_screen.dart`)
→ tap a letter → **landscape tracing screen**
(`lib/features/letter/letter_screen.dart`).

The picker is **one sliding row**, and it opens the word list directly —
there is no Games menu, because there is one game. It holds only what works:
the profile, the parent zone and the four unbuilt games are not greyed-out
tiles-in-waiting, because a child tapping something that does nothing learns
the app is broken.

The row runs **the 247 first, then the game, then வடமொழி** — the letters the
app is named for, then play, then the ones outside the 247. The title carries
the count too: "அஆஇஈ தமிழ் எழுத்து — 247", summed off the catalogues that
`LetterCatalogue.isPartOf247` marks rather than typed in, so a roster change
cannot leave the app claiming something it does not teach.

**The guide ring is what replaces the padlock.** `GuideHighlight` in
`lib/features/common/` puts a travelling light round the *one* thing that is
next: the first unfinished category on the picker, the first unfinished row on
the uyirmei screen, the first character short of three stars on a letter list.
Exactly one is active per screen — `guide_highlight_test.dart` asserts that,
because two rings would be a choice rather than an answer.

It stops under reduce-motion, which is worth honouring anyway and is what
keeps it out of `pumpAndSettle`, exactly like the breathing games tile. Its
width scales with what it is ringing: a fixed 5px looked right on a 92px
letter bubble and like a hairline on a 220px tile.

**Every back arrow sits in a ring** (`BackCircleButton`), with a matching
`CircleIconButton` in the same top-left corner opening the Parent Zone —
opposite corner from the totals a child watches climb. Quitting used to be
this button; it now lives inside the zone this one opens (see "Parent Zone"
below), so it is behind the gate rather than loose on a child-facing screen.

**Each tile reads `label (count)` with a medal beneath**, not stars. Uyir
shows `(12+1)`: ஃ is a bonus level inside the vowels rather than a thirteenth
vowel, and the split is derived by grouping the catalogue's own
`Letter.category` values, so it stays right without a special case.
`app_harness.dart`'s `categoryTile()` matches on the *start* of the label
because of it, and by prefix rather than containment: "மெய் எழுத்து" sits
inside "உயிர்மெய் எழுத்து", so anything looser matches two tiles.

The label reserves two lines' height whether it needs them or not, so a longer
name cannot make its tile taller than the others.

Uyirmei has one extra hop: **உயிர்மெய் → 18 consonant rows → 12 letters**.
216 never go on one screen (CLAUDE.md section 2). The rows are drawn with the
same `CategoryTile` as the home screen — shared, not copied, so the two cannot
drift: it is the same gesture at two depths and a child should not have to
learn it twice. A row shows its own first three letters, its name (`க வரிசை`)
and how many of its twelve are finished.

`uyirmei.json` is **generated** by `tools/gen_uyirmei.py`, not hand-written —
216 rows of the same three mechanical facts is 216 chances to mistype one. It
reads the consonants out of `mei.json`, so the two cannot disagree.

**Uyirmei carries no example words.** There is no honest way to invent 216 of
them and a wrong one teaches a wrong word, so `Letter.exampleWordTamil` is
nullable and the letter screen omits the panel rather than showing a blank.

**Every screen with a list carries a `ScoreBadge`** in the top corner — the
home picker, the category lists and the uyirmei rows: stars earned across
what is on *that* screen, the achievement total, and the coin balance. On a list the title stays
centred with the badge in an `Expanded` beside it, so the heading does not
shift as the totals grow. Home's badge totals all three catalogues, and each
category tile carries its own.

**`reward_icons.dart` is the one place either reward is drawn.** The star is
`MagicPenStar`: a slim handle running up from the lower left to a big
five-pointed star, with sparkles around the tip. Painted rather than picked
from Material, which has a wand (`auto_fix_high`) and a pencil (`edit`) but
neither with the star large enough to be the point of the mark. The wand is
the pen the child has been dragging round the canvas; the star is what it
just made. Every one in the app comes from there — the three under a letter,
the totals on a tile, the badge — so it reads as one thing and changing it is
a single edit. `letter_screen_trace_test.dart` finds it `byType`, not by
icon, so the two cannot drift apart again.

It is **shaded, not flat**: a light-to-deep gradient across the star and the
handle, plus facets that split each point into a lit half and a shadowed one,
which is what makes it read as polished gold rather than a yellow shape.

**The shading is lerped off the colour it is given, never a fixed gold.** The
same mark serves earned and unearned, so passing `starFilled` gives gold and
passing `starEmpty` gives a quiet grey with identical form. Hard-coding gold
would have left the unearned marks looking like a bug.

`paintShadedStar()` is shared with the completion burst, so the star that
blooms in the middle of it is the *same* star a child collects rather than a
second one that happens to look similar.

Two things to keep right when moving any of it:

- **Everything must fit inside the 0..1 box.** A star's points reach a full
  radius from its centre, so `x + r` and `y - r` decide whether it fits, not
  the centre. A sparkle at x 0.90 with r 0.115 reaches 1.015 and had its
  outer point sliced off by the widget bounds — invisible at a glance,
  obvious once someone looked. Check the extents, not the positions.
- **The sparkles thin out as the mark shrinks.** Below about 20 logical
  pixels the small ones turn to mush, so the painter keeps only as many as it
  can actually draw — five at 28px and up, three, then two, then none.

Every list screen also carries a **back arrow** on the left of its title. The
system gesture works, but a 4-year-old does not know that.

A uyirmei row is labelled **`க வரிசை`**, not `9 / 12`. The count was progress
through *authoring* — the developer's business, not a child's — and it stops
meaning anything once a category is finished. Each row tile also carries the
stars earned inside it.

### Parent Zone

The characters, games and scoring are frozen as of this session — CLAUDE.md's
"From here on we will focus on Parental Zone" — so this is new ground, not a
continuation of the letter/game work above.

Reached from a ringed icon button in the home screen's top-left corner
(`lib/features/home/home_screen.dart`, the `CircleIconButton` that used to
run `SystemNavigator.pop()` directly), through
`lib/features/parent/parental_gate_screen.dart` — a random multiplication
sum, four answers, wrong ones reshuffle the question rather than explain why.
One gate at the entrance rather than one per action, since nothing inside is
reachable without passing it first (CLAUDE.md section 1: "Parental gate
required before: purchases, ad settings, privacy policy, any outbound link,
progress export"). Not a row-scrolling tile any more — a tile at the far end
of a scrolling row can end up off-screen (`parent_zone_tile_test.dart` had to
force a 1600×900 viewport to reach it), and a settings-style entry reads
better as a corner button anyway, the same language the old quit button
already used.

`lib/features/parent/parent_zone_screen.dart` lists eight rows: watch an ad,
certificate, project details, privacy policy, **share the app**, version,
copyright, then **quit** — moved here from the home screen's top-left
corner, so it sits behind the gate instead of loose on a child-facing screen
(previously HANDOFF item 5, now resolved). Share uses `share_plus` to open
the platform share sheet with `l10n.shareAppText`, a fixed message naming the
app plus `parentZone.appShareUrl` — a real, correctly-formatted Play Store
listing URL built from the package id in CLAUDE.md's header
(`com.udmnxpdu.kids_tamil_ezhuthu_school`), even though nothing is published
there yet. Version comes from `package_info_plus`; the copyright year from
`DateTime.now()` rather than a typed-in one. The two links use `url_launcher`
and fail quietly into a snackbar (`l10n.linkOpenFailed`) rather than a crash
if nothing can open them —
`android/app/src/main/AndroidManifest.xml` carries the `https` `<queries>`
entry Android 11+ package visibility needs for that to work at all.

**Watch Ads to Earn Coin is a mock rewarded ad**, not AdMob —
`lib/services/ad_service.dart`. Chosen deliberately over wiring up
`google_mobile_ads` now: no ad unit IDs or Play Console child-directed setup
exist yet, and the mock behaves exactly like the real thing will — a
countdown (`parentZone.adDurationSeconds`), a skip button that only becomes
tappable after `parentZone.adSkippableAfterSeconds`, and the coin paid **only**
on watching it out, never on an early skip. `MockRewardedAdScreen` returns a
plain `bool` through `Navigator.pop`, which is the whole contract — swapping
in a real ad network later is a change to this one file, not to anything that
calls it.

Coins earned this way could not reuse the pattern the rest of the app's coins
use. Three-star letters and clean words are *derived* — `coinBalance()`
recounts them from progress every time, so replaying something never mints a
second coin. Watching an ad is an *event* with nothing left behind to
recount, so it needed the one thing the rest of the coin system deliberately
avoids: a stored, only-ever-growing counter. `AdCoinBank`
(`lib/features/letter/letter_providers.dart`) is that counter, the same
shape as `CoinPurse` but adding instead of spending, backed by a new
`coinsFromAds` field in `SavedProgress` alongside `coinsSpent`.

**The certificate is generated live, never stored.** CLAUDE.md's spec for it,
verbatim: 50 of its 100 marks for every one of the 247 core letters holding
at least one star, then 10 + 10 + 20 + 10 bonus marks for taking uyir, mei,
uyirmei and the Word Builder game each all the way to mastery — three stars
on every letter in the category, or a clean clear on every word.
`lib/features/parent/certificate_score.dart` is pure, tested logic
(`test/features/parent/certificate_score_test.dart`) with no widgets in it —
the same split the tracing screen's rules keep. Each of the five lines is
all-or-nothing, the same way a three-star letter or a clean word pays a coin:
there is no partial credit, and grantha does not count toward the 247 base
because it is outside the 247 by definition (CLAUDE.md section 2).
`lib/features/parent/certificate_screen.dart` reads straight off
`progressStoreProvider` and `gameStoreProvider`, so it is exactly as current
as the letter lists are — nothing to regenerate, nothing to go stale.

**Two URLs are placeholders**, `parentZone.projectDetailsUrl` and
`.privacyPolicyUrl` in `assets/config/app_config.json`, both pointing at
`example.com`. CLAUDE.md's own compliance checklist requires a *live* privacy
policy URL before Play Store submission — this is the one item in this
session's work that cannot ship as committed.

The Android app icon was replaced this session from the adaptive-icon export
at `C:\Users\Rajkumar\Downloads\app_icon\android` — `mipmap-*`,
`mipmap-anydpi-v26` and `drawable/ic_launcher_background.xml` copied
straight into `android/app/src/main/res/`, overwriting the default Flutter
icon. `AndroidManifest.xml` already pointed at `@mipmap/ic_launcher` and
needed no change. iOS icons are untouched — CLAUDE.md still has iOS as
Phase 5.

### Sound, language and the sky

Four asks in one session: a language switch, music/sound controls, actual
background music + click + celebration sound, letter speech for uyir, and a
sun/moon/stars decoration on the home screen. All new ground — CLAUDE.md
section 9 had only ever planned the letter-audio half of this.

**Every recorded sound in this build is synthesized, not sourced.**
`tools/gen_audio.py` writes four WAV files with the stdlib `wave` module
alone — plain sine tones on a C pentatonic scale (so nothing can land
dissonant), gentle envelopes, quiet by default:

- `assets/audio/sfx/click.wav` — a soft 70ms tick
- `assets/audio/sfx/celebration.wav` — a three-note "ta-da"
- `assets/audio/music/general_loop.wav` — a slow, sparse loop for every
  screen except the game
- `assets/audio/music/game_loop.wav` — the same scale, a touch faster and
  brighter, while a Word Builder screen is on top

Deliberate, not a placeholder chosen for lack of options: no download, no
licensing question, nothing that could be too intense for a 4-8 year old.
Real recordings can replace any file here later with zero code change — the
same fallback shape CLAUDE.md section 9 already planned for letter sounds.

**`featureFlags.audioEnabled` is now `true`** — it sat unused at `false`
since it was declared with no implementation behind it. It is the outermost
gate: `lib/services/audio_service.dart`'s `AudioService` takes an `enabled`
bool on every call rather than reading settings itself, and every caller
ANDs this flag with the Parent Zone's own switch before passing it in, so a
device with broken audio output can be silenced by flipping the one config
value instead of chasing three settings.

**`lib/services/settings_store.dart`** holds language, music-on and
sound-on — device preferences a grown-up sets once, kept in their own
`settings.v1` document rather than inside `SavedProgress`, so wiping progress
can never silently mute the app or flip its language. `main.dart`'s
`TamilEzhuthuApp` is now a `ConsumerWidget` reading `settingsStoreProvider`
for `MaterialApp.locale` instead of a hardcoded `Locale('ta')`. The Parent
Zone gained three new rows above Watch Ads — Language (a two-button
switch), Background music and Sound effects (each a plain `Switch`) — which
is also why `parent_zone_quit_test.dart` and `parent_zone_share_test.dart`
had to start scrolling to reach their rows: the list now runs past the
default 800×600 test viewport.

**Click plays at primary navigation taps, not everywhere.** Wiring it into
every `InkWell` in the app was in scope only in spirit — instead it sits at
the taps that actually move a child somewhere: home's category and game
tiles, letter bubbles, uyirmei group rows, word cards, and the Parent Zone
button. It deliberately does **not** sit on the tracing canvas or the mode
buttons — a click under every pointer-down while a child is mid-stroke would
be noise, not feedback. Extending it further is a per-screen call, not a
blocked one.

**Celebration plays wherever the sparkle burst already does** — a letter
finished (`letter_screen.dart`'s `_finish()`) and a word cleared
(`word_builder_screen.dart`'s `_finish()`) — regardless of whether marks were
earned, matching the burst's own always-fires behaviour.

**Letter speech is uyir-only for now, by explicit request**, gated on
`catalogue == LetterCatalogue.uyir` in `LetterScreen.build` (which covers
both உயிர் and the ஃ bonus letter, since both live in that catalogue). It is
plain Tamil TTS (`flutter_tts`, locale `ta-IN`) — there are no recordings to
fall back from yet, so this *is* the fallback CLAUDE.md section 9 describes,
running on its own rather than behind an asset check. Spoken once when the
screen opens and once when an attempt finishes ("spell the char in starting
and ending"), plus a small speaker icon under the transliteration in
`_LetterInfoPanel` that replays it on demand. **Confirmed working on a
Pixel 8**: `adb logcat` shows Google TTS loading its `ta-in` voice pack and
running a real synthesis request for அ the moment the letter screen opened —
worth widening to mei and uyirmei once that has been *heard*, not just
logged, but the mechanism itself is proven. If a device has no Tamil voice,
`AudioService.speak` fails silently into its own `catch`, same as every
other sound here.

**The sky backdrop is decoration, not a feature to extend.** One
`CustomPainter` (`lib/features/home/sky_backdrop.dart`) behind the home
screen's content: a glowing sun by day, a moon with two soft craters and a
handful of twinkling stars by night, decided once from `DateTime.now().hour`
at 6/18 rather than re-checked every frame. One shared `AnimationController`
drives the pulsing glow and the stars' per-star phase offset, honours
reduce-motion the same way `_BreathingTile` does, and reuses existing
`ThemeColors` (`starFilled`, `textSecondary`) rather than inventing new
config — deliberately as small as "a little theme" can be.

**Known gaps, in the order they'd bite:**

- Background music has no lifecycle handling — it keeps playing if the app
  is backgrounded, since `AudioService` is a single app-lifetime provider
  with no `AppLifecycleState` listener. Worth adding a pause-on-background
  hook before shipping.
- Click sound coverage is partial by design (see above) — extending it to
  mode buttons, round actions or Parent Zone rows is a small, deliberate
  follow-up if wanted, not an oversight to fix blindly.

### Round two on sound, the certificate and a theme toggle

Follow-up session, once uyir speech had been confirmed working on-device:

- **Click is now a bell "ting"**, not a soft tick — `_bell()` in
  `tools/gen_audio.py`, a fundamental plus a fast-decaying inharmonic
  partial (still nothing but `math.sin`). **The general background loop
  is now the same melodic family as the game loop**, just unhurried, rather
  than a sparse pad — "like the game category music" was the ask, and the
  two now share a scale and a shape, not just a key.
- **Letter speech is on for every catalogue now** — `speechEnabled: true`
  unconditionally in `LetterScreen.build`, no longer gated to uyir. The
  gate existed only because uyir was what had been checked on-device first.
- **Uyirmei letters show their composition** — "க் + ஆ = கா" under the
  transliteration, computed by `_uyirmeiComposition()` in
  `letter_screen.dart` from the letter's `order` (`(order - 1) % 12` gives
  the vowel column, since order runs across the whole 216 rather than
  resetting per group) and its `groupTamil` plus a pulli. The same
  composition CLAUDE.md section 8's Word Builder already teaches, now
  visible on the tracing screen too.
- **The certificate looks like a certificate now**, not a checklist card —
  double border, a medal, "இது சான்றளிக்கிறது", an editable name field
  (signature-styled, saved to `AppSettings.childName` so it survives a
  restart), the marks breakdown, and a date/signature line along the foot.
  An **info button** opens a dialog explaining the 50/10/10/20/10 split. An
  **export button** wraps the certificate in a `RepaintBoundary`, rasterises
  it with `toImage()`, writes the PNG to a temp file
  (`path_provider`), and hands it to the platform share sheet — "download"
  here means "save via whichever app the share sheet offers," the same
  mechanism the Parent Zone's Share row already uses, not a second,
  storage-permission-hungry path. **Not covered by a widget test**: the
  export button itself, since mocking image rasterisation plus two separate
  plugin channels (`path_provider` and `share_plus`) end-to-end was judged
  not worth the fragility for a placeholder-audio-tier feature; verify by
  hand before shipping.
- **A manual light/dark toggle sits beside the Parent Zone button** on the
  home screen — sun or crescent-moon icon, tapping flips
  `AppSettings.homeTheme` (`lib/services/settings_store.dart`). Deliberately
  **not** tied to the system clock or the device's dark-mode setting: a
  grown-up's explicit choice reads the same at any hour, on any device.
  Scoped to the **home screen only** — `ThemeConfig` gained a parallel
  `darkColors` palette in `theme_config.json`, and `HomeScreen.build`
  swaps its whole `colors` variable between `config.theme.colors` and
  `config.theme.darkColors` depending on the toggle; every tile, badge and
  button downstream already takes a `colors:` parameter, so nothing else
  had to change. The rest of the app (letter screens, Parent Zone,
  certificate) keeps the one light palette it always had — this was asked
  for as "theme in home screen," not an app-wide dark mode.
  `sky_backdrop.dart`'s sun/moon now follows this same toggle instead of
  `DateTime.now().hour`, and both the sun and the moon were toned down
  further (lower alpha, smaller radius) plus three soft cloud clusters
  added for the day theme — "like a background theme, not bold" was explicit.

**Still unverified by ear or eye this round:** the reworked general loop and
the new click "ting" haven't been listened to on a device, and the
certificate export hasn't been run end-to-end on-device either (only
analyzed and unit/widget-tested short of the actual file write + share
sheet). Worth a hands-on pass before calling any of the three finished.

### Round three: real cloud/star shapes, the theme going app-wide

- **Clouds and stars are shapes now, not circles.** `sky_backdrop.dart`'s
  `_paintCloud()` unions several overlapping ovals (`Path.combine`,
  `PathOperation.union`) into one silhouette rather than drawing a cluster of
  separate dots — one or two clouds is enough, per direct instruction, not
  three. Stars are a four-point sparkle (`_sparklePath()`, two overlapping
  diamonds) instead of a plain circle.
- **The light/dark theme is app-wide now**, not home-screen-only — every
  screen this session touched (`letters_screen.dart`,
  `letter_groups_screen.dart`, `letter_screen.dart`, `word_list_screen.dart`,
  `word_builder_screen.dart`, `parent_zone_screen.dart`,
  `parental_gate_screen.dart`, `certificate_screen.dart`) now calls
  `themeColorsOf(config, settings)` (new: `lib/services/theme_selector.dart`)
  instead of reading `config.theme.colors` directly. **The control itself
  still lives only on the home screen** — the sun/moon button beside Parent
  Zone — every other screen just reads `AppSettings.homeTheme`, the same
  settings object already threaded everywhere for sound. The authoring
  screen (dev tooling, gated off in a shipped build) was deliberately left
  on the light palette only — not worth the churn for a screen a child never
  sees.
- **Mastered letters get a green ring.** `letters_screen.dart`'s
  `_LetterBubble` now checks `stars >= 3` and swaps the unlocked border from
  `colors.primary` (orange) to `colors.success` (green) — orange still means
  "open," green now means "done," matching the colour the certificate and
  celebration burst already use for the same idea. Locked letters keep
  `colors.starEmpty` regardless.

### Round four: proportional certificate marks, a tiered medal, an easier gate

- **Certificate marks are proportional now, not all-or-nothing.**
  `CertificateLine` (`certificate_score.dart`) changed from an `earned: bool`
  to `achievedCount`/`totalCount`/`maxMarks`, with `marks` computed as
  `round(achievedCount / totalCount * maxMarks)` — a child with 1 of 247
  letters starred now sees "1/50" on that line instead of "+0". `complete`
  (`achievedCount >= totalCount`) still drives the check-mark/empty-ring icon,
  so "fully done" still reads at a glance; the number beside it is what
  changed. Every certificate row now displays `l10n.certMarksFraction` (new:
  "{marks}/{maxMarks}") instead of the old "+{marks}".
- **The five sentences were reworded** to match what was asked, not just
  "mastered": `certAllStarred` → "247-character practice marks",
  `certUyir`/`certMei`/`certUyirmei` → "Can write \_\_\_ letters fully
  without guidance", `certGame` → "Completed the letter game exam". The
  underlying achievement test is unchanged (still three stars per letter, or
  a clean word) — only the wording changed, not the criterion.
- **A medal carries the app icon** in the certificate's top-right corner —
  `assets/images/app_icon.png` (copied from the adaptive-icon export,
  `playstore-icon.png`, since the Android mipmap resources aren't readable
  as a Flutter asset) inside a ringed circle, with a two-tail ribbon painted
  by `_RibbonPainter`. **Its colour is the total score's tier** —
  `_medalColorFor()`: bronze under 50, silver 50–79, gold 80–99, diamond only
  at a perfect 100 — fixed real-world metal colours rather than anything
  from `ThemeColors`, since bronze has to look like bronze regardless of
  which home theme is picked.
- **The parental gate is deliberately easy now**: addition only, sum capped
  at 10 (`a` 1–9, `b` chosen so `a + b <= 10`). The earlier version drew both
  addends up to 19 each, which could ask a distracted grown-up to add two
  numbers near 40 — a gate nobody in a hurry can pass is worse than no gate,
  since it locks the whole Parent Zone away, ads and privacy policy
  included. `parental_gate_sum_test.dart` runs 30 regenerated questions and
  asserts the sum never exceeds 10.

### Round five: the mock ad became a real one

The Parent Zone's "Watch Ads to Earn Coin" now shows a **real AdMob rewarded
ad** — the "Coin Earn Ad" unit, app id and ad unit id supplied directly
this session, both real production ids.

- `AndroidManifest.xml` carries the app id as `APPLICATION_ID` meta-data
  (`google_mobile_ads` reads this on its own); the ad unit id lives in
  `assets/config/app_config.json` → `parentZone.rewardedAdUnitId`, read by
  `AdService` at call time — no id is typed directly into Dart code.
- `main.dart` calls `MobileAds.instance.initialize()` and
  `updateRequestConfiguration()` with child-directed treatment, under-age-of
  -consent, and max content rating G **on every launch, before `runApp`** —
  this satisfies three items on CLAUDE.md section 6's compliance checklist
  outright (`setTagForChildDirectedTreatment`, max rating G) rather than
  leaving them as future work.
- `AdService.showRewardedAd()` keeps its exact old signature
  (`Future<bool> Function(BuildContext, ParentZoneConfig)`), so
  `parent_zone_screen.dart` needed no changes at all — only the
  implementation underneath changed. It shows a small loading dialog while
  `RewardedAd.load()` is in flight (a real network fetch can take a moment,
  unlike the old mock's instant local timer), then hands off to the ad's own
  full-screen view. **The reward is paid only when AdMob's own
  `onUserEarnedReward` fires** — never guessed at from a timer the way the
  mock did.
- The request is `nonPersonalizedAds: true` — this app carries no accounts
  and no profiling to personalise from in the first place (CLAUDE.md
  section 1).
- `ParentZoneConfig.adSkippableAfterSeconds` and `.adDurationSeconds` are
  gone along with `MockRewardedAdScreen` — a real rewarded ad controls its
  own pacing and skip button, so those config values had nothing left to
  drive.
- **Still outstanding from CLAUDE.md section 6's checklist**: Play Console
  target-audience declaration, GMA SDK version confirmation (5.3.1 resolved
  this session — worth checking against the ≥20.6.0 *native* SDK floor,
  which is a different version number than the Flutter plugin's), Certified
  Families ads network enrollment, and the Play Console side of child-
  directed treatment. None of those are things this codebase can satisfy on
  its own — they're account/console configuration.
- **Verified this session**: builds clean, installs, and launches without a
  crash on the Pixel 8 with the real AdMob SDK initialized. **Not yet
  verified**: actually watching a real ad end-to-end and confirming the coin
  lands — AdMob's test/fill behavior on a freshly created ad unit can take
  time to warm up, so an empty fill on first try would not mean anything is
  wrong.

### வடமொழி எழுத்துக்கள் — the six grantha letters

ஜ ஷ ஸ ஹ க்ஷ ஸ்ரீ, in `lib/data/letters/vadamozhi.json`. **Outside the 247 by
definition** — they write sounds Tamil borrowed rather than sounds it owns —
so they are a fourth catalogue beside uyir, mei and uyirmei, never inside one.

Everything was **added, never modified**, because every order in
`tools/orders.json` names arc indices and renumbering one would silently point
a child at the wrong shape. The proof is mechanical, and worth re-running
after any change here:

- `export_skeletons.py` writes six new files and inserts six lines into
  `index.json`. `git diff` on `assets/authoring/skeletons/` shows **24
  insertions, 0 deletions** — no existing skeleton moved.
- `trace_batch.py` reports **247 traced, 6 pending, 0 warnings** and
  `git status lib/data/letters/strokes/` stays **empty**: all 247 stroke files
  regenerate byte-for-byte.
- `vadamozhi_test.dart` asserts the same thing from the app's side — the three
  catalogues are still 13 + 18 + 216, no grantha letter leaked into one, and
  no id collides.

`trace_batch.py` and the authoring screen both picked the category up with no
change: they read their roster from the letter JSONs and ask HarfBuzz. The
font has every glyph (ஜ ஷ ஸ ஹ க்ஷ ஸ்ரீ all shape, none is .notdef), and க்ஷ
and ஸ்ரீ each come back as a *single* precomposed glyph, so neither is a
special case.

**Only ஜ has an example word** (ஜாடி). The other five are left null on
purpose: grantha exists to write borrowed words, so there is no native Tamil
word for a child to recognise, and the honest options are all names or
loanwords. Same rule as uyirmei — the letter screen omits the panel rather
than showing an invented word.

**The picker hides a category until something in it can be traced.**
`HomeScreen` filters on `authoredStrokeIdsProvider`, so the roster can land in
the repo long before anyone draws the orders without a tile leading nowhere —
the same reason the games and the parent zone are not tiles-in-waiting. The
tile appears by itself the build after the first order is traced, which is
what the booting test in `vadamozhi_test.dart` pins down.

**`authoringEnabled` overrides that**, and has to: the Author button lives
inside a category's letter list, so a category with no orders is exactly the
one somebody needs to walk into. The flag is what makes it safe — off in a
child's build, on for whoever is drawing.

**The picker is one sliding row, not a wrapping grid.** Four tiles at 220dp
do not fit a phone in landscape, and wrapping dropped வடமொழி onto a second
line by itself, where it read as a different kind of thing rather than the
fourth of four. A horizontal `SingleChildScrollView` keeps them all one size
in one order, centred while they fit — so nothing moves on a tablet — and lets
the tile that does not fit peek in from the edge, which is what tells a child
to slide.

**All six are authored, traced and playable.** Drawn on a Pixel 8 through the
authoring screen; orders in `tools/orders.json` (252 entries). Verified on the
device: the tile slides into view, the list opens all six, and ஜ traces with
`ja` and ஜாடி beside it. `index.json` is 114 entries — the figure of 96 in
earlier notes was stale before this work.

**Two orders were repaired, and both were then confirmed on the device.** ஷ
and க்ஷ each crossed an arc twice inside one stroke, and `trace_batch.py`
reported a pen jump immediately after every second crossing — 19px on ஷ, 25px
and 19px on க்ஷ, against a stroke width of 50-60px. This is the third time that
exact signature has appeared: ண் ran `… 8 → 0R → 8 → 6R` and the second
crossing walked the pen away from where arc 6 began. Dropping the repeat took
all three warnings to **zero**, which is the same bar the seven repaired
uyirmei were held to.

That mattered because "0 warnings and every arc drawn" says the path is
continuous and complete, not that it is how the letter is written — five
letters passed those same checks with drifted orders after the shaping fix.
Only a person watching settles it, and one has: **both trace correctly.** The
doubled crossing was a solver artefact, not a hand's intention, which is now
true of all three letters it has happened to.

| letter | order as it now stands |
|---|---|
| ஜ | `1R 3 4R 0 2` |
| ஷ | `2 0 3 4R 6R 7 9 1R 8 10 5` — second `9` dropped |
| ஸ | `1 2R 3 0R` |
| ஹ | `2 1 5R 3R 4 0` |
| க்ஷ | `11 \| 8R 14R \| 13 1 7R 10 16R 2 3 4 5R 9R 12 18 0R 15 6` — second `16R` and second `18` dropped |
| ஸ்ரீ | `3 4 1 5R 7R 10 \| 9 8 0 \| 6R 2` |

### Picture data for the games

`tools/cut_worksheet_art.py` cuts individual pictures out of the A-to-Z
worksheet sheets in `tools/worksheet_pages/`, trims each to its own ink, drops
the page background to transparent and de-duplicates across sheets: **15
sheets → 136 cuts → 118 unique**. `tools/word_letters.py` then curates them to
**74** and splits each word into the characters a child actually writes.

Three cuts failed and are marked `damaged` — white art on a white card has no
seam to cut along, so there is nothing to separate. The fragmentation test in
`cut()` catches most of that case and falls back to an opaque picture; the
unicorn needed naming in `KEEP_OPAQUE`.

What the 74 cover, from `word_letters.py`:

- Picture Puzzle: all 74. First letters reach **11 of 12 uyir** — **ஔ has no
  picture**, and neither does ஃ. For the mei format (a word with one pure
  consonant blanked, CLAUDE.md section 8) **15 of 18** appear inside a word;
  **வ் ழ் ற் are unrepresented**.
- Word Builder: **63** at four characters or fewer.
- 62 distinct uyirmei appear across the words, which is where uyirmei example
  words can finally come from.

Every dropped picture carries its reason in `words.json` — duplicate,
loanword, rare, wrong, damaged. Four of the words in the first draft were
wrong and are recorded as such: கடல்பாசி is seaweed not a jellyfish, பச்சோந்தி
is a chameleon not an iguana, பாவாடை is a skirt not that frock, and the sun is
சூரியன் not வெயில். The narwhal and the heart shape have no word a Tamil child
knows, and inventing a compound would teach an invented word.

### Word Builder data — done; the screens are not

`tools/gen_word_builder.py` writes `lib/data/games/word_builder.json` and
copies the 51 pictures it needs into `assets/images/words/` (2.0 MB). Both
ship. Generated rather than hand-written for the same reason `uyirmei.json`
is: every slot's tiles follow mechanically from the word, and typing 51 of
them out is 51 chances to hand a child the wrong letter to drag.

**51 words**, ordered easiest first — 1 to 4 slots, 1 to 6 tiles. Each slot
carries the character to show in its box and the tiles that build it:

```json
{"char": "கா", "tiles": ["க்", "ஆ"]}
```

**Every consonant-vowel slot is two tiles, including the inherent-a form** —
ப = ப் + அ, not a ப tile. The tile pool is exactly the 31 base characters, so
nothing composed is ever handed over ready-made. Allowing ப as one tile would
make the rule "compose, except when you cannot see a sign", and a rule with an
exception in it is the one a child gets wrong.

`word_builder_data_test.dart` re-derives each slot from its own tiles and
fails if they do not spell it, checks every tile is in the 31, holds the
4-slot / 2-uyirmei limits, and confirms every picture exists on disk.

### Word Builder — playable

Home → the breathing **விளையாட்டு** tile → **சொல் கட்டு** → a card per word →
the game. Played end to end on a Pixel 8: ட் + உ joins into டு, a wrong drop
shows red, and a finished word bursts.

- `word_round.dart` holds **the rules with no widgets in them** — which tile a
  box takes next, what it shows half-built, whether the round is still clean.
  That is the part that can be wrong in a way nobody sees, so it is the part
  that is unit-tested.
- `word_builder_screen.dart` is the screen; `word_slot_box.dart` the box, its
  travelling border light and its cross.
- Every number is in `assets/config/games_config.json`, including the tile
  pool and the confusable groups distractors are drawn from.

**A wrong drop takes longer than a right one** — 950ms of border against 650,
then 1200ms of red against 800. The audience is three to eight and a
correction that flicks past is one they never saw. Only after the border
finishes does the box show what the drop *built* — ட் plus அ reading as ட —
crossed out, then it reverts. `crossOpacity` is 0.62 because the first version
at full strength hid the very letter the mark exists to show.

**A tile is never used up.** குகை needs க் twice; removing a tile on use would
leave a box that cannot be filled. `word_round_test.dart` plays all 51 words
through to completion, which is what proves no board is unsolvable.

**The burst is shared with the letter screen**, not copied —
`lib/features/common/celebration_burst.dart`. Same moment, same celebration.

**The games tile breathes, and stops when the device asks for reduced
motion.** That is worth honouring anyway, and it is also what makes it
testable: a repeating controller schedules frames forever, so `pumpAndSettle`
never returns while one runs. `stillAnimations(tester)` in `app_harness.dart`
turns it off for every booting test.

### Hearts, coins and the achievement

`GameStore` (`lib/features/games/game_providers.dart`) holds the two things
the games need kept: **hearts left** and **which words have been cleared
cleanly**. Both go in the same saved document as the letter marks.

**Hearts are the only stored balance in the app.** Everything else is derived
— three-star letters pay coins, and now cleared words do too, so a word pays
exactly once however often it is replayed and there is no event to miss or
de-duplicate. A heart is spent and given back, which cannot be derived from
anything, so it is a counter.

- Opening a word spends one; a clean round hands it straight back
- `openWord()` **refuses rather than going negative** — a heart is refused
  before it is charged for
- A coin buys `heartsPerCoin` (3)
- `finishedCleanly()` returns true only the first time, which is when the
  achievement and the coin are new

`coinBalanceProvider` is where the balance is worked out, once. Four screens
show it and adding a new source of coins should not mean remembering four
call sites.

`game_store_test.dart` covers the refusal, the refund, the replay case, and —
the one that matters — that writing hearts does not drop the letter marks
sharing the file.

**Layout, settled by play-testing on the device.** The word started centred
along the bottom of the whole screen and moved to sit under its own picture on
the left, with the tiles alone on the right — the picture and the word are the
same fact and belong together. The tray is sized from `tilesPerRow` and the
picture takes the remainder, so the busiest word (ஆரஞ்சு: 4 boxes, 9 tiles)
fits without clipping anything a finger has to hit. A box is `tileSize *
tileDragScale`, so the box and the tile being carried are the same size.

**Verified on the device**, including the part unit tests could not reach:
hearts read 1 of 3 after two opens *across a force-stop*, which is progress
persistence working for real.

**Still to build:** the four other games. Word Builder itself is done.

### Coins

Earned at one per letter taken to three stars, starting balance 50, both in
`app_config.json` (CLAUDE.md section 7).

**Earnings are derived from progress, never banked when they happen.**
`coinBalance()` counts the three-star letters each time it is asked. A letter
keeps its best result and stars only ever go up, so this pays exactly once per
letter however many times a child re-traces it — there is no event to miss,
replay or de-duplicate, and no "already awarded" set to keep in step with the
progress store. Only *spending* accumulates, in `CoinPurse`.

`coins_test.dart` covers the case that makes it worth doing this way: five
more attempts on an already-perfect letter leave the balance untouched.

The coin icon is `Icons.toll_rounded`, deliberately: every obvious coin icon
in Material carries a dollar sign, which is both the wrong currency and the
wrong idea. These buy **game hearts and nothing else** — never money, and they
never gate a letter. Tinted blue against the star's gold, so the two totals
never read as the same currency.

**There are no hints.** `hintsEnabled` is gone from `app_config.json` and
`FeatureFlags`, and coins now have exactly one sink (CLAUDE.md section 7).

`coinBalance` will happily go negative if more is spent than earned. That is
deliberate: a heart should be **refused before it is charged for**, which is
the game's job, not the balance's.

### Progress is saved now

`shared_preferences`, one JSON document under `progress.v1`, rewritten whole
on every change — `lib/data/repos/progress_repository.dart`. CLAUDE.md named
Hive or Isar; both earn their keep on partial updates and queries at scale and
there are neither here, so the dependency was not worth taking on.

Two things in it are load-bearing:

- **Every write waits for the read.** Marks and coins share one document but
  are owned by `ProgressStore` and `CoinPurse` separately, so a save that
  lands before the file has finished loading would write its own half beside
  an empty one — a coin spent during launch taking every star with it. Remove
  the `await load()` in `_write` and
  `test/data/progress_persistence_test.dart` fails on exactly that case; it
  was checked by removing it.
- **A corrupt or unreadable file opens the app empty rather than not at all.**
  Losing a session's stars is bad; refusing to launch is worse. An unknown
  `TraceMode` costs that mode's marks and not the whole file, so renaming one
  later is survivable.

Letters with nothing earned are not written, or the file would be 253 empty
records with four real ones in it.

A letter list shows its **whole** category — all 18 mei, authored or not.
Hiding the unfinished ones would tell a child மெய் has however many happen to
be done. Three states, and the last two look different on purpose:

| State | Mark | Means |
|---|---|---|
| open | — | tappable |
| locked | padlock | earn a star on the letter before it |
| not authored | ⋯ | no stroke data yet; nothing to trace |

A padlock promises "play and this opens". An un-authored letter cannot be
opened that way at all, so it must not wear one. **The star chain steps over
un-authored letters**, which is load-bearing rather than tidy: a letter with
no strokes can never be opened, so it can never earn a star, so anything
behind it in the chain would be locked forever. `unlock_test.dart` covers it.

Verified working on a Pixel 8 over adb, both categories.

### The tracing screen

The canvas draws **no font text**. Every layer comes from one source — the
letter's stroke path — so the guide, the fill and the scoring all measure the
same shape:

1. letter tube (path stroked thick, round caps)
2. dot trail along the centreline
3. gold gradient fill revealing the traced portion
4. target ring marking where the finger goes next

Easy keeps the tube but replaces 2 and 4 with a single **waypoint** — the
next place to reach, which moves on one step at a time as the child catches
up with it. The tube says what the letter is; the waypoint says where to go
next, which is the part a shape cannot tell you. `showWaypoints` in
`trace_config.json`.

`LetterPaths.nextWaypoint` is the mechanism, and two things about it matter:

- **`waypointSpacingFactor` is 0.12, not the 0.042 of the guide dots.** At
  the dot spacing the marker lands inside a fingertip and shows the child
  where they already are rather than where to go — the guidance read as no
  guidance at all. It has to stay under `traceLookaheadFactor` (0.14) so each
  one is reachable in a single movement, and it is comfortably inside
  `traceToleranceFactor` (0.1) so dragging straight between two of them never
  falls off a curve. Re-check all three together if any of them moves.
- **Touching a stroke is what moves its marker on**, via
  `TraceController.touchedCurrentStroke`. Distance alone cannot tell "not
  started" from "at the beginning", and every stroke after the first begins
  at zero again — so an untouched stroke shows where it *starts*, and a
  touched one shows where to go next.
- **`waypointMinLeadFactor` (0.075) keeps the marker clear of the hand.**
  Spacing alone does not: however far apart the waypoints are, the gap to
  the next one closes to nothing as the child arrives, so their own finger
  covers it at exactly the moment they need to see it. The marker therefore
  skips to the following waypoint once they are within this much of it, and
  the lead stays between 0.075 and 0.195 instead of between 0 and 0.12.

Challenge outlines the drawing area (`showFrame`): it draws nothing else at
all, and a blank canvas has no visible edges to write inside.

Dragging only advances while the finger is near the path, only moves forward,
and cannot skip across a loop (lookahead window). Raw finger positions are
recorded *separately* from progress so scoring judges real accuracy.

### Four modes (`assets/config/trace_config.json`)

| Mode | Canvas | Guided? | Marks |
|---|---|---|---|
| எளிது easy | tube + one waypoint at a time | yes | 25 |
| நடுத்தரம் medium | tube | yes | 25 |
| கடினம் hard | blank | yes (hidden path) | 20 + 10 fluency |
| சவால் challenge | blank, outlined | **no** — freehand | 20 (shape only) |

100 marks per character. Stars are **cumulative**: 30 → ★, 75 → ★★, 90 → ★★★.
Each mode keeps its best result, so a worse retry never removes marks, and
what the screen shows is always the running best. Two clean attempts
auto-advance to the next mode. See "Scoring" below for why the first star
is at 30.

Finishing sets off the sparkle burst, and where the letter's standing is at
least one star a **magic star blooms in the middle of it** — the burst says
"finished", the star says "and it counted". It springs past its final size and
settles back, so it lands rather than merely appears. Sized by
`celebration.starRadiusFactor`; the burst's own reach and particle count are
in the same block of `trace_config.json`.

The **authoring button is gone** from the letter lists — all 247 characters
are drawn, and it is developer tooling that a child-facing screen must never
lead to. `featureFlags.authoringEnabled` in `app_config.json` brings it back;
the screen itself is untouched.

After finishing, the canvas stops accepting input until reset. A prominent
**மீண்டும் (Again)** button appears for that — deliberately a button rather
than a timer, so the canvas never wipes itself while a child is still looking
at what they made (CLAUDE.md §11, no countdown pressure).

Hard's fluency bonus is silent — no clock, no countdown, and being slow only
forfeits the bonus, never a completion mark (CLAUDE.md §11).

### Unlock

> **⚠ Progression is currently OFF for play-testing.**
> `assets/config/app_config.json` → `progression.starsToUnlockNext` is **0**,
> so every letter is open. **Put it back to 1 before shipping.** The unlock
> logic is untouched and `unlock_test.dart` still proves it; only the config
> is turned off. `widget_test.dart` and `mei_navigation_test.dart` read this
> value rather than assuming it, so they stay honest either way.

First letter always open; each next opens at `starsToUnlockNext` stars.

A locked letter shows its own glyph greyed back behind a small padlock. A
wall of identical padlocks tells a child nothing; seeing the letter they are
working towards is half the reason to keep going.

### Scoring — two fixes worth knowing about

- **The screen reads progress from the store, not from its own copy.** It
  used to build an empty `LetterProgress` in `initState`, so leaving a letter
  and coming back counted only that visit: finish easy and medium for 50 and
  one star, return, trace once, and it read 25 out of 100 with no star.
  `letter_screen_progress_test.dart` is the regression.
- **The first star is at 30 marks, not 50.** Hard is worth 20 + 10 fluency,
  so a child who skips the guided modes tops out at 30 — which scored no
  star and left the next letter locked, while the easier route through easy
  and medium scored 50 and opened it. Rewarding the easy path over the hard
  one is backwards. `assets/config/scoring_config.json` → `starThresholds`.

- **Challenge shape is measured by nearest point, not by index.** It used to
  concatenate every stroke into one path, resample, and compare
  point-for-point — which asks "was the child in the same place at the same
  moment". Draw அ's bar longer relative to the body than the reference and
  everything after it lines up against the wrong part of the letter. On the
  real அ with the bar at double length — a normal thing to do, the letter
  still reads correctly — that scored **5.3/20** where the letter deserved
  most of the marks. It now pools the points and takes a symmetric
  nearest-point distance (`meanNearestPointDistance`): **18.8/20** for the
  same attempt. Measured both ways on purpose, so a half-drawn letter still
  loses marks rather than scoring perfectly on the part it did cover.

  `shapeToleranceRadius` went 0.16 → 0.24 alongside it, calibrated so ink
  within about half a tube width of the centreline reads as a good letter.

`test/scoring/scoring_fixtures.dart` now reads that config file rather than
duplicating its numbers — the copy had already drifted and the tests were
proving something the app no longer did.

## Stroke data — the real bottleneck

**All 13 uyir are authored and playable** — அ ஆ இ ஈ உ ஊ எ ஏ ஐ ஒ ஓ ஔ ஃ. Every
one was drawn by hand on a Pixel 8 through the authoring screen below, and
every one is listed in `lib/data/letters/uyir.json`, so the letter list shows
the full set.

## All 247 characters have stroke data

`trace_batch.py` with no arguments traces the lot: **247 traced, 0 pending,
0 warnings**. 13 uyir + 18 mei + 216 uyirmei, every one with a stroke file,
none malformed, none stray. That was the bottleneck the whole project was
gated on, and it is closed.

77 of the 216 uyirmei were drawn by hand; the other 139 are composed from
them. See below for how the split was worked out.

### Uyirmei — 77 drawings, not 216

Shaping all 216 shows most are not new shapes at all:

| what the font returns | count | what it means |
|---|---|---|
| **fused** — one precomposed glyph | **56** | nothing to reuse; needs its own order |
| consonant glyph + sign glyph | 142 | the sign is a *separate piece*, not touching |
| the bare consonant | 18 | the inherent-a form — already authored as mei |

So the hand-authoring is **56 fused + 9 distinct vowel-sign shapes = 65**,
one representative character supplying each sign, and the other 151 composed
from a consonant order already in `orders.json` plus a sign order. The list
is computed, not written down — `uyirmei_to_author()` in
`export_skeletons.py` asks HarfBuzz and returns exactly those 65. Their
skeletons are exported and in the authoring picker (`index.json` is 96
letters now).

Composition works because the vowel sign usually does not touch the
consonant: separate connected components, so the consonant's arcs inside a
composed glyph are the mei letter's arcs translated, and the sign's are its
own. `tools/compose_uyirmei.py` builds the rest from that.

**204 of 216 uyirmei now have orders**, 0 warnings: 65 drawn, 139 composed.

The composer reads two libraries out of what a hand actually did:

* **consonants** — each mei order with the puḷḷi's component dropped. The
  bare consonant's skeleton *is* the mei letter's minus its dot, arc for arc,
  checked before relying on it.
* **signs** — every component of an authored uyirmei that is not its
  consonant, keyed by **shape, not vowel column**. கி is one fused glyph
  while வி is a consonant plus a separate ி, so the column says nothing
  about which sign shape a letter holds. Keying by column composed 69;
  keying by shape composed 139.

Each sign also carries **whether the hand drew it before or after the
consonant** — ெ first, ா after, a wrap form one piece each side. Read off
the authored letter rather than decided in code, because that is a
handwriting fact. The composed னெ draws its sign first and னௌ puts a piece
either side, which is what the authored கெ and கௌ do.

This is emphatically *not* the failed matching of the section below: those
compared a font letterform against a handwriting animation. These are the
same glyph outlines from the same font at the same size, so a
translation-invariant signature matches them exactly — and `align()` returns
None rather than guessing whenever a signature is ambiguous or unmatched.

**The touching case is the one that is easy to miss.** ஞி தி நி பி மி யி ரி
வி ழி ளி றி னி are two glyphs whose *ink runs together*: the skeleton is a
single connected piece, so there is no seam to compose along and they have to
be drawn. They fell through both the authoring set and the composer at first,
which showed up as "the Author screen is missing ஞி". `uyirmei_to_author()`
now tests for it — multiple glyphs but one connected component — rather than
carrying a hardcoded list, so it stays right if the font changes. All 12 are
drawn now.

A composed order is checked exactly like a drawn one — `trace_batch.py` runs
the same pen-jump and coverage checks over all 216. Being derived is not a
reason to trust it more.

One thing to know about the coverage check there: it asks that every *piece*
is drawn, not every arc. A composed letter can only inherit the coverage of
what it was composed from, and the authored sources legitimately skip
junction slivers — கெ's sign leaves a 32px and a 4px arc alone, both well
inside the tube. Demanding every arc rejected 52 letters for a flaw their own
sources have.

**All 65 are drawn, exported and traced**, 0 warnings. `orders.json` holds 95
entries. Seven needed a mechanical repair first — கூ கை ணி ணீ ணு ணூ னூ, all
the two familiar classes: a skipped connector (12–25px, under half a stroke
width) or a connector crossed twice. Each repair was accepted only when it
reached **zero pen jumps and zero undrawn arcs**; they are the same operation
`repair_gaps` performs on its own and declines only when the arc graph offers
more than one route. Worth a look at those seven replays.

The **check itself was wrong first**, and that is the thing to remember: it
reported "the puḷḷi is never drawn" on கெ கை கௌ, which have no puḷḷi at all.
It had been written as "any undrawn arc in the topmost component", which on a
mei letter is the dot but on a uyirmei is the vowel sign — and it fired on
32px and 4px slivers *inside* a component that was otherwise fully drawn. It
is now `undrawn_components`: a warning means a whole connected piece is never
touched, which is the invariant that actually matters (க் without its dot is
க, கெ without its sign is க). Re-validated against all 18 mei — still catches
a deleted puḷḷi stroke on every one of them.

**All 18 mei are authored and playable** — க் ங் ச் ஞ் ட் ண் த் ந் ப் ம் ய்
ர் ல் வ் ழ் ள் ற் ன். Drawn by hand on a Pixel 8 in one sitting through the
authoring screen, orders in `tools/orders.json`, stroke data emitted and the
whole set checked on one contact sheet. **31 of the 247 characters are done**
(13 uyir + 18 mei); uyirmei is next.

Two orders needed correcting before they shipped, both caught by the pen-jump
check and neither visible in a still picture — see "What the check caught"
below. That is twice now that check has earned its keep.

The loop, if a category needs redoing:

1. `flutter run -d <device>`, Home → மெய் எழுத்து → the **Author** button.
   It opens scoped to that category's 18 letters and nothing else.
2. For each: draw it, **Derive**, *watch the replay*, **Keep**. Keep files the
   order and jumps to the next letter with none, so the whole category is one
   pass with no navigation in between. The picker ticks off what is done and
   the bar counts `n / 18 kept`.
3. **Export all** once at the end — every kept order as a single
   `tools/orders.json` object, to the clipboard, the console and a dialog.
   Paste it in whole.
4. `PYTHONIOENCODING=utf-8 PYTHONPATH=tools python tools/trace_batch.py mei`
   traces every letter that has an order, writes its stroke file, and stacks
   the filmstrips into one contact sheet. Check the sheet.
5. Rebuild. The letter appears in the mei list — no code or JSON edit.

### What the check caught in the 18 mei

Both letters looked complete on the filmstrip. `resample` fills a leap with
evenly spaced points, so a skipped piece draws as a straight line inside the
tube and the picture looks right — the same trap that let அ ship with its bar
traced twice.

- **ன் skipped an 18px connector.** Arc 6 was never drawn — 18px on a glyph
  whose stroke is 54px wide, so the finger genuinely never went near it. The
  automatic repair declined because the arc graph offered more than one way
  across. Naming arc 6 explicitly closes the gap to zero.
- **ண் crossed the same connector twice.** Arc 8 is a 21px link between the
  two nodes that the big loop (arc 0) also joins — parallel arcs, which is
  exactly the case the repair refuses to guess at. The order ran
  `… 8 → 0R → 8 → 6R`, and that second crossing walked the pen *away* from
  where arc 6 begins, which was the 21px gap. Dropping it leaves every arc
  still drawn and the join exact.

Both fixes were verified by the gap going to zero with no arc left undrawn,
then by the replay. Neither could have been read off the numbers.

### The export truncates if it is one block

`debugPrint` throttles. The first **Export all** of 18 letters came through
the console **cut off mid-way through the seventeenth**, so the merged JSON
would not parse. `_exportAll` now prints a line at a time.

The per-Keep console line is what saved that sitting: 18 letters had to be
recovered from the individual blocks rather than the merged one. Keep it.

Step 5 is why `mei.json` lists all 18 while only some are playable:
`LetterRepository.loadCatalogue` drops any letter whose stroke file the build
did not bundle. The roster is permanent, the bundle decides what is playable
yet. It is the *build* that decides, not the run — a stroke file written while
the app is running needs a rebuild, not a hot restart.

`trace_batch.py` also checks something specific to mei: **every letter's order
must draw the puḷḷi.** The dot is a separate component, so it is a separate
pen stroke and the easiest thing to forget — and க் without it is க, a
different letter. It is the topmost component of the glyph, which on all 18 is
the single highest-numbered arc. The check was run against every mei letter
both with and without that arc, and catches the omission in all 18.

Each mei letter is two components, the body plus the puḷḷi, which is a filled
dot and so depends on `_dot_arcs`. On the authoring canvas the puḷḷi is still
a short segment to draw over — that scaffolding is what makes it nameable —
but what ships is a single point, drawn as a dot and completed by a touch.

Orders live in `tools/orders.json`; அ and உ stay in `ORDERS` because they
were hand-verified against a stroke-order reference before the screen existed.

The authoring screen below is how the rest get made.

Each letter needs two things from two different sources:

- **Shape** ← the app's bundled font (`assets/fonts/NotoSansTamil-Regular.ttf`).
  Bundled deliberately: without it each device rendered different shapes and
  "match the printed letter" was undefined.
- **Order + direction** ← nothing in a font knows this.

### What did NOT work

Automating order derivation. Three attempts, each checked against அ (where the
order was hand-verified) and each contradicted it:

1. geometric nearest-neighbour → descent before loop
2. animation-votes-for-arcs → centre line before bowl
3. connected pen-walks → bar before bowl

Root cause: the font letterform and the UPenn handwriting animation are
different enough shapes that point-to-point matching is unreliable. The same
mismatch broke an earlier "snap the animation onto the font" experiment.
`tools/auto_trace.py` and `tools/upenn_order.py` are that dead end, kept only
as reference.

**Do not ship auto-derived stroke order without verifying it.** Wrong order is
precisely what a child would learn wrong.

### The authoring screen — how orders get made now

Drawing supplies the order in the *same* coordinate space as the target, which
is why it works where matching two different letterforms did not. And the
answer is a **list of arc indices, not new geometry** — the shape that ships is
still the font's exact medial axis, so a shaky finger costs nothing.

The loop, roughly 2 min/letter:

1. `flutter run -d <device>`, open a letter list, tap **Author** (debug builds
   only). The session covers that category's letters.
2. Pick the letter. The canvas shows its arcs as a tube, each numbered with
   the index `glyph_skeleton.py` prints.
3. Write it with a finger, lifting between strokes.
4. **Derive** → the order appears as `1 → 2 → 6 → 0R → 6R → 5 | 3 → 4`
   (`R` = against the arc's stored direction) and the replay plays.
   *Watch the replay.* Reading the numbers is how அ shipped wrong.
5. **Keep** → filed, and the screen moves to the next letter with no order.
   Every Keep also prints its own entry to the `flutter run` console
   immediately: an order held only in memory is one crash away from being
   redrawn, and redrawing is the expensive part. Coming back to a kept letter
   shows what it holds, and the button says **Replace →**.
6. **Export all** → one JSON object of every order kept, to the clipboard,
   the console and a dialog. Paste into `tools/orders.json`.
7. `PYTHONIOENCODING=utf-8 PYTHONPATH=tools python tools/trace_batch.py mei`
   writes the real stroke data for all of them and one contact sheet.

`tools/orders.json` overrides `ORDERS` in `trace_letter.py` where both have a
letter. Adding to `ORDERS` by hand still works and is still fine for a
one-arc letter.

The screen reports four things, all worth reading:

| Report | Means |
|---|---|
| **Pen jumps Nx mid-stroke** | The order skips a piece. Arcs that meet share a pixel, so a gap is never legitimate. |
| **Arcs never drawn** | Missed part of the letter, or a skeleton artefact. |
| **N crossings ignored** | Arcs clipped in passing at junctions. Normal; check the list if an arc you *meant* to draw is in it. |
| **N samples off the letter** | Fine for a multi-piece letter like ஃ, suspicious for a single-piece one. |

Tolerance: the solver recovers the order under a hand wobble of about half a
tube width. Past that, very short arcs (அ's arc 6 is 22px, 3% of the letter)
get missed — the finger genuinely does not go near them. The pen-jump check
catches it. `assets/config/authoring_config.json` holds every threshold.

### Verify before accepting — twice now this caught real bugs

Fixed this session, all three found by the join check the authoring screen
needed:

- **அ's bar was traced twice.** `ORDERS` said `(3, True)`, which wrote the bar
  middle→top and then doubled back down through the middle to reach arc 4.
  Invisible in the verify image, because the return leg lies exactly on top of
  the bar. Now `(3, False)`. `trace_letter.py` warns about this class of bug.
- **`glyph_skeleton.build` dropped branches.** The walk started only from each
  junction clump's representative pixel, so a branch hanging off a different
  pixel of the same clump was lost whenever its far end was also a clump. ஆ's
  vertical bar had a 74px hole because of it. Component counts across the 13
  uyir dropped sharply once fixed — those "separate pieces" were missing
  branches, not pen lifts.
- **ஃ lost two of its three dots.** A pure-loop component has no pixel of
  degree ≠ 2, and the fallback seeded only one such component in the whole
  glyph.
- **Corners were not nodes.** A junction is where strokes meet; a corner is
  where one turns. Both are places a pen starts or stops, but only the first
  was breaking arcs, so ஈ's top-left horizontal and its left vertical were
  one L-shaped arc — and ஈ is written as two strokes meeting at that corner.
  Neither could be named. `_split_at_corners` now cuts an arc where it turns
  more than `CORNER_DEGREES` (55°) over a stroke-width-scaled window.
  Only ஈ changed (3 → 4 arcs); every other letter's arcs and indices are
  untouched, the sharpest curve elsewhere being 46°.

  Two ~87° bends are deliberately **not** split — ஊ arc 6 and ஔ arc 2 — as
  they sit 33px and 43px from an arc's end on a ~53px-wide stroke. Those are
  hooks at a stroke terminal, and a sliver arc narrower than the pen is
  something nobody could aim at. `min_segment` is what holds them back.

- **Arcs stopped short of their own nodes.** A walk begins at some pixel of
  the clump it leaves and ends at some pixel of the clump it reaches, and
  neither is necessarily the pixel the graph calls the node. Only the start
  was being pulled onto the representative, so arcs that are supposed to
  touch sat 4–8px apart and the arc graph looked disconnected. Both ends are
  pulled on now.
- **A short line read as a loop.** Closedness was an absolute tolerance
  (half a stroke width). அ's arc 6 is a 22px straight connector whose ends
  are 23px apart, so it was classified as a loop and skipped the join logic.
  It has to be relative: a loop is *long* and returns to where it began,
  `gap <= length * CLOSED_ARC_RATIO`.
- **A loop was pinned to its stored start.** Once loops stopped being flipped,
  they began wherever their first stored point happened to be, leaving a gap
  of however far that was (23px on ஆ). A loop has no inherent beginning —
  `rotate_ring` joins it wherever the pen arrives, direction untouched.
- **Wide glyphs were being clipped by the raster.** `rasterize` drew at 720pt
  into a fixed 1100×1100 square and centred the glyph. ஔ is 1476px wide at
  that size, so its left edge was cut off *before* the skeleton was computed
  — arcs ran to column 0 and a piece of the letter was simply absent. It
  presented as "ஔ is not showing fully" on the authoring canvas, which
  looked like a layout problem and was not: the piece was missing from the
  source. The canvas is now cut to the glyph plus `RASTER_MARGIN`. ஔ went
  11 → 15 arcs; every other letter's arc count and indices are unchanged,
  and அ and உ still regenerate byte-identically.

  Worth remembering for mei and especially uyirmei — the ௌ and ொ forms are
  wider still, and a fixed square would have clipped many of them silently.
- **A long open curl was being closed into a loop.** ஆ's bottom curl is 997px
  with its two ends **133px apart** — 13% of its own length, so
  `CLOSED_ARC_RATIO` (0.15) called it a ring. `rotate_ring` then joined it up,
  drawing a 133px segment the font does not contain and welding the curl onto
  the vertical bar. `resample` spread points evenly across the invention, so
  the still picture looked perfect; the letter simply ended in the wrong place.

  The ratio test alone cannot separate the two cases, and the history shows
  why an absolute test alone cannot either — அ's 22px connector with its ends
  23px apart was misread as a loop by the old absolute tolerance. **Both** now
  have to pass: `CLOSED_ARC_MAX_GAP_FACTOR` (0.5) additionally requires the
  ends to be within half a stroke width.

  Measured over every arc in all 31 letters first: a genuine loop's ends sit
  on the *same* node and the gap is **exactly 0** (28 of them), the largest
  real one is 0.38 stroke widths, and ஆ's is 2.52. Nothing else is anywhere
  near the line, and regenerating every letter changed ஆ alone.

  `SkeletonArc.isClosed` takes the same cap, so the authoring replay and the
  join check agree with what ships — a replay worth watching has to. One
  caller does **not** pass it yet: `order_solver.dart`, which uses closedness
  to unwrap a position when reading direction off the ink. Left alone
  deliberately, since changing it changes what the screen *derives* and every
  other letter currently derives correctly. Worth revisiting if a curl ever
  comes back with its direction reversed.

- **The glyphs were never being shaped. This was the big one.**

  Tamil letters here are more than one code point — க் is க + U+0BCD — and
  `rasterize` used Pillow, which has **no shaper in this environment**
  (`PIL.features.check("raqm")` is False). So it laid the string out by
  advance width: draw க, step forward, drop a standalone puḷḷi. The font does
  not work that way. Ask HarfBuzz for க் and it answers with **one
  precomposed glyph** — gid 77, where bare க is gid 18.

  The damage: every mei letter's dot sat up to **a third of the letter's
  width** right of where the designer put it (+33.5% on ண், +28% on ங்).
  Shaped, the worst is 10.8% and most are inside ±3% — which is the font's
  own design, and the traced dot now lands where the app's own text renderer
  puts it. *"The dot is not centred"* was right, and the earlier reading of
  it — that the font placed it there deliberately — was wrong. The
  measurement was of a bad raster.

  `rasterize` now shapes with HarfBuzz and draws by glyph id with FreeType;
  Pillow is no longer used for text at all. **This was going to be far worse
  for uyirmei than it was for mei**: கு is a single fused glyph too, and கெ
  *reorders* — the vowel sign is emitted **before** the consonant. Neither is
  reachable by stacking advances, so composing 216 uyirmei on the old raster
  would have produced nonsense.

  Fallout, checked letter by letter: all 18 mei kept their arc counts and
  indices, so every authored order survived. ஒ, ஓ and ஔ lost a couple of arcs
  each (7→5, 8→6, 15→11) to sub-pixel antialiasing flipping a borderline
  corner split. ஔ's ink box is byte-for-byte the same size, so this is *not*
  the old clipping bug returning.

  The mechanical checks passed on those, but they were **not** right: the
  pattern and order had drifted on ஆ, ஊ, ஒ, ஓ and ஔ. All five were redrawn
  and re-exported, and those are the orders in `tools/orders.json` now. Worth
  remembering — "0 warnings and every arc drawn" says the path is continuous
  and complete, not that it is the way the letter is written. Only a person
  watching the replay says that.

  `tools/requirements.txt` now exists and pins everything, because the
  skeleton is sensitive at this level: ~1% of edge pixels moved three
  letters' arc counts, and an arc count change renumbers every index in
  `tools/orders.json`.

- **The spur pruner ate a real branch.** `SPUR_FACTOR` was 1.4, so any twig
  under 1.4 stroke widths was trimmed as a rasterisation artefact. ங்'s middle
  vertical ends in a 69px stub on a 60px stroke, and it was being deleted —
  the traced stem stopped **129px short** of the printed one, which is what
  "the second vertical needs to be longer" turned out to mean. A rounded
  stroke end sprouts a twig about *half* a stroke width; anything past a full
  one is a branch, so the factor is now **1.0**.

  Checked across all 31 letters before changing it: at 1.0 **only ங் changes**
  (9 → 10 arcs), so every other authored order stayed valid and every other
  stroke file regenerates byte-identically. At 0.8 ல் also changes, at 0.6
  seven letters do. Measure this before touching it again — a skeleton change
  renumbers arcs, and every order in `tools/orders.json` names arc indices.

  ங்'s order was re-indexed by hand (the dot moved 8 → 9) and the recovered
  stem tip placed at arc 8. **ங் is worth redrawing to confirm** — three
  different placements of that stub all pass the pen-jump and every-arc-drawn
  checks, so only watching the replay settles which is right.

- **The dot was drawn at the wrong size.** A puḷḷi is **95px across on every
  mei letter** where the letter's own stroke is 54-62px — 1.5x to 1.8x wider.
  Drawing it at the tube width made it visibly small, and it is why ங்'s ink
  coverage sat at 10.8%; it is 3.6% now, the rest being square font corners a
  round cap cannot fill. A dot stroke therefore ships its own `width`, and
  `Stroke.width` overrides the letter's tube for that stroke alone. Nothing
  else in a letter varies in width, so nothing else carries one.

  Worth keeping in mind for uyirmei: the ௗ and ஸ்ரீ forms have marks that are
  not the letter's stroke width either.

- **A dot shipped as a little bar.** `_dot_arcs` gives a filled dot a short
  segment because the authoring screen needs something a finger can follow —
  a point cannot be drawn over or named in an order. But that segment was
  being shipped, and stroked with a round cap at each end it comes out about
  **1.7x wider than it is tall**: a lozenge, not a dot. `trace_letter.py` now
  collapses a stroke made only of dot arcs back to its centre
  (`gs.dot_arc_indices` says which arcs those are), so the letter ships the
  point a dot actually is. The scaffolding stays on the authoring side, where
  it is needed; only ஈ changed, and every other letter regenerates
  byte-identically.

  A one-point stroke is now a first-class thing on the canvas: drawn as a
  circle, and **completed by touching it** rather than by dragging across it.
  There is no path to creep along and no direction to get wrong, and asking a
  child to drag along a mark the size of their own fingertip is asking for
  precision the mark does not have. `dotStrokeLengthFactor` gives it a
  notional length so anything that weighs strokes by length — the progress
  fraction, the fluency reference, how far the demo has got — does not treat
  it as nothing; at zero the demo counts the puḷḷi finished the instant it
  reaches it. `test/features/letter/dot_stroke_test.dart` covers it, and
  `LetterPaths` used to drop these strokes outright (`points.length < 2`),
  so without that fix every mei letter would have lost its puḷḷi entirely.

- **A filled dot has no medial axis to speak of.** It is a single point;
  `skeletonize` renders that as a pixel or two and `_prune_spurs` then clears
  it as a stray twig, so ஈ's two dots were missing from the graph and from
  the letter. `_dot_arcs` gives every inked piece the skeleton left empty a
  short segment through its centre, shortened by the stroke width — stroked
  as a tube with round caps that *is* the dot, and long enough for a finger
  to follow. Only ஈ was affected (4 → 6 arcs), and because the segments are
  two points long they sort last, so no existing arc index moved.

  ஃ is unaffected: its marks are outlined rings in this font, not filled
  dots, so they skeletonize to real loops. Any mei or uyirmei letter with a
  puḷḷi (ஂ) will need this — that dot is filled.

Both `trace_letter.py` and the authoring screen now check that consecutive
arcs of a stroke actually meet. Regenerating உ after all three fixes gives a
byte-identical file; அ differs only by the bar fix.

### Repairing a skipped connector

`trace_letter.py` fills gaps automatically (`trace(..., repair=False)` to
opt out) and prints what it did. A gap is never legitimate — arcs that meet
share a pixel — so it means the pen was recorded leaving one arc and landing
on another it could not have reached without crossing something between.
What it crossed is whatever the skeleton says lies between them, and that is
recovered as the shortest path through the arc graph.

This is not inventing an order: both ends were drawn, only the join was
missed. Where the graph offers more than one way across, nothing is guessed
— the gap is left and reported.

### Per-letter gotchas

From `tools/export_skeletons.py` (re-run it after any `glyph_skeleton.py`
change):

| Letter | arcs | components | note |
|---|---|---|---|
| உ ஃ | 2–3 | 1 / 3 | quickest. ஃ is three dots, so three pen lifts |
| ஈ எ ஏ | 4 | 1 | should be quick |
| ஐ ஆ ஒ ஓ ஊ | 6–9 | 1, ஊ 2 | |
| இ ஔ | 11 | 1 / 3 | ஔ needs three pen lifts |
| அ | 7 | 1 | done |

Components are a *floor* on pen lifts, not the count — ஈ is one connected
piece written in three strokes.

Sources: UPenn South Asia Center animations,
`ccat.sas.upenn.edu/plc/tamilweb/gif/<name>.gif` (alet aalet ilet iilet ulet
uulet elet eelet ailet olet oolet aulet ahlet). Each letter is inked in a
*different* colour on white — key on "not white", not on red.

## Known gaps

- **Progress is in memory only** — resets on restart. `ProgressStore` in
  `lib/features/letter/letter_providers.dart` is the only class to change;
  CLAUDE.md plans Hive/Isar, local-only.
- The category picker covers uyir and mei; no uyirmei, games, profile or
  parent zone yet.
- Mei transliterations are plain ASCII to match the uyir style, so ந் and ன்
  are both `n` — they are homophones, which is honest, but if the Parent Zone
  ever needs them distinguished it is one edit in `mei.json`.
- Only one app-booting widget test per file — asset futures do not resolve for
  a second boot in the same file, and Flutter isolates files, not tests. Same
  trap for `dart:io`: a `testWidgets` body runs under fake async, so
  `await File(...).readAsString()` never completes and the test hangs until
  it is killed. Use `readAsStringSync`.
- ஃ traces as three circles, which is right: in this font its marks really
  are outlined rings, not filled dots — that is why they skeletonize to
  ~590px loops. ஈ's dots are the filled kind, and those needed `_dot_arcs`.
- The authoring screen exports through the clipboard, the console and a
  dialog, but writes no file. `tools/harvest_orders.py` closes that: it reads
  an `adb logcat` dump, pulls out every `=== kept:` block, and merges them into
  `tools/orders.json` on `--write`.

  ```bash
  adb -s <device> logcat -d > log.txt
  PYTHONIOENCODING=utf-8 python tools/harvest_orders.py log.txt          # show
  PYTHONIOENCODING=utf-8 python tools/harvest_orders.py log.txt --write  # merge
  ```

  **It falls back to the one-line summary when the JSON block is truncated**,
  which is not a rare case — `debugPrint` throttling is what cut the first
  Export all of 18 mei letters off mid-way through the seventeenth, and it
  swallowed ஷ's block during the grantha sitting. The summary
  (`2 → 0 → 3 → 4R → … | 3 → 4`) carries the same information on one line, so
  it survives where the block does not. The parser round-trips all 246
  existing orders byte-exactly, which is how it was checked.
- Kept orders live in the authoring screen's own state, so leaving the screen
  loses the sitting. The per-Keep console line is the backstop — the entries
  are all in the `flutter run` output either way.
- An arc can only be written whole. The order format names arc indices, so a
  deliberately partial arc has nowhere to go; the solver drops those and says
  so under "crossings ignored".
- இ leaves its arcs 9 and 10 undrawn — 7px and 5px crumbs at a junction on a
  56px stroke, well inside the tube and bypassed without any pen jump. Long
  standing and harmless; not worth an order that names a sliver nobody could
  aim at.
- The authoring pipeline needs `pip install -r tools/requirements.txt`.

## Checks

```bash
flutter analyze && flutter test      # 89 tests, all passing
flutter run -d <device-id>
adb -s <device-id> exec-out screencap -p > shot.png   # verifying on device
```

Re-running `trace_batch.py uyir aaytham` rewrites all 13 uyir stroke files
byte-identically, so `git status` staying clean is the check that the pipeline
still does what it did. That is how the batch tool itself was verified.

`test/app_harness.dart` holds the hop from launch to a letter list. Every
booting widget test goes through it, so when the route grows another screen
there is one place to change.

`test/features/authoring/order_solver_test.dart` walks அ's and உ's known
orders, draws over them with a synthetic wobble, and insists the solver
recovers them — the two hand-verified letters are the only ground truth there
is, so they are what guards the solver.

Both were also authored on a real Pixel 8 through the screen itself, and the
resulting orders regenerate their stroke files byte-for-byte.
