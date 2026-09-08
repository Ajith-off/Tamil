# அஆஇஈ Tamil Ezhuthu: Kids

A Flutter app that teaches children (ages ~4–8) to write all **247 Tamil characters**. Tamil-first UI, English optional. Android first, iOS later.

Package: com.udmnxpdu.kids_tamil_ezhuthu_school

> Current build state, and the stroke-data bottleneck that gates everything
> else, are in **`HANDOFF.md`**. Read that before starting work.

---

## 1. Non-negotiable rules for this codebase

1. **No hardcoded values, ever.** Numbers, thresholds, costs, colours, durations — all live in `assets/config/*.json` and are read through `ConfigService`. Feature code must contain no magic numbers.
2. **No hardcoded strings.** All user-facing text goes through ARB files (`flutter_localizations` + `intl`), Tamil (`ta`) and English (`en`), from day one.
3. **Child safety first.** No login, no accounts, no analytics, no chat, no social sharing, no external links from any child-facing screen. All data local-only.
4. **Parental gate** required before: purchases, ad settings, privacy policy, any outbound link, progress export.
5. Child's drawings never leave the device.

---

## 2. Content model — the 247

| Category | Tamil | Count |
|---|---|---|
| Uyir | உயிர் எழுத்து | 12 |
| Aaytham | ஃ (sub-category inside Uyir, shown as special/bonus level) | 1 |
| Mei | மெய் எழுத்து | 18 |
| Uyirmei | உயிர்மெய் | 216 (18 consonants × 12 vowels) |
| **Total** | | **247** |

Uyirmei is navigated as **18 consonant sub-groups** (க, ங, ச, ஞ, ட, ண, த, ந, ப, ம, ய, ர, ல, வ, ழ, ள, ற, ன), each holding 12 letters. Never render 216 nodes on one screen.

### Beyond the 247 — வடமொழி எழுத்துக்கள்

| Category | Tamil | Count |
|---|---|---|
| Grantha | வடமொழி எழுத்துக்கள் (ஜ ஷ ஸ ஹ க்ஷ ஸ்ரீ) | 6 |

These write sounds Tamil **borrowed** rather than sounds it owns, so they are
outside the 247 and taught after them — a fourth catalogue beside uyir, mei
and uyirmei, never folded into one.

**The 247 are frozen.** Every order in `tools/orders.json` names arc indices,
and a skeleton change renumbers them, so anything added here is *appended*
and proved not to have moved what was there: `git diff` over
`assets/authoring/skeletons/` shows insertions only, and re-running
`trace_batch.py` leaves all 247 stroke files byte-identical.

Only ஜ carries an example word (ஜாடி). Grantha exists to write borrowed
words, so the rest have no native Tamil word a child would know, and the
field stays null rather than holding a name or a loanword — the same rule
uyirmei follows.

### Stroke data authoring strategy

Do **not** hand-author 216 uyirmei stroke sets. Compose them:

- **Suffix signs:** ா ி ீ ு ூ ை ௗ — appended after the consonant
- **Prefix signs:** ெ ே ை — drawn *before* the consonant (stroke order matters)
- **Wrap signs:** ொ ோ ௌ — components on both sides
- **Irregular/fused forms:** the ு and ூ forms fuse with most consonants. Budget ~36–40 hand-authored exceptions.

Realistic authoring load: 12 uyir + 18 mei + 1 aaytham + 18 consonant bases + ~40 irregulars ≈ **90 stroke sets**. Everything else is composed at runtime.

Composed characters may carry lower-fidelity stroke data; that is acceptable.

### Where stroke data comes from

Each letter needs two things, and **no single source has both**:

- **Shape** ← the bundled font's medial axis. A font has the exact letterform a child will read, but no notion of what is drawn first.
- **Order and direction** ← a stroke-order reference. This cannot be inferred from a font, and attempts to infer it by matching against a *different* letterform have failed repeatedly (see `HANDOFF.md`).

Never ship auto-derived stroke order without verifying it. Wrong order is precisely what a child would learn wrong.

---

## 3. Screen map

```
Splash → Language pick (தமிழ் / English, first launch only)
       → Home
           ├── உயிர் எழுத்து (12+1)         → Letter list → Letter screen
           ├── மெய் எழுத்து (18)             → Letter list → Letter screen
           ├── உயிர்மெய் (216)               → 18 sub-groups → Letter list → Letter screen
           ├── எழுத்து விளையாட்டு (51)      → Word card list → Word Builder
           ├── வடமொழி எழுத்துக்கள் (6)       → Letter list → Letter screen
           ├── Profile
           ├── Performance
           ├── Certificates
           └── Parent Zone  [parental gate]
                 ├── Settings (sound, tutorial speed, language)
                 ├── Purchase / remove ads
                 ├── Progress report
                 └── Privacy policy
```

The row runs **the 247 first, then the game, then வடமொழி**, and the screen
title carries the total: "அஆஇஈ தமிழ் எழுத்து — 247".

**Every tile carries how many characters are in it and how many are finished**
— "உயிர் எழுத்து (12+1)" with a medal and a count beneath. Uyir splits because
ஃ is a bonus level inside the vowels, not a thirteenth vowel. Not stars: a star
total climbs to three times the size of the category and says nothing a child
can act on, where "eleven of thirteen done" does. The game tile is the same
size and shape as the rest and differs only in colour and a slow breathing
motion, which is what a child who cannot read the label goes on.

**There is one game for now.** Picture Puzzle, Sound Match, Missing Letter and
Daily Challenge are still the plan (section 8) but no menu waits for them: the
word game sits on the home row directly, and a Games menu arrives when there
is a second game to put in it.

**A category appears on the picker once something inside it can be traced.**
A roster lands in the repo well before anyone has drawn its stroke orders, and
a tile leading to letters that cannot be opened teaches a child the app is
broken — the same reason the games and the parent zone are not
tiles-in-waiting.

**Letter list** shows each letter as a bubble with its earned stars. Nothing
carries a padlock; a character with no stroke data yet shows ⋯, which is a
development state rather than something to earn past.

**Every screen carries its back arrow in a ring**, and the home screen a quit
button in the matching ring on the opposite corner — a bare arrow on a cream
background is easy for a four-year-old to miss, and the system gesture is not
something they know about.

---

## 4. Letter screen — landscape

Orientation is **locked to landscape**. Three columns:

| Column | Contents |
|---|---|
| **Left** | Back, the letter, its transliteration, an example word |
| **Centre** | Square tracing canvas |
| **Right** | Mode buttons, replay demo, clear, submit (challenge only) |

The canvas contains **no font text**. Every layer is derived from the letter's stroke path, so the guide, the fill and the scoring all measure one shape:

1. **Letter tube** — the path stroked thick with round caps
2. **Dot trail** — evenly spaced along the centreline
3. **Trace fill** — gold gradient revealing the portion completed
4. **Target ring** — where the finger goes next

Dragging advances only while the finger is near the path, only ever forward, and cannot skip across a loop. Raw finger positions are recorded separately from progress, so scoring judges real accuracy rather than mere completion.

A demo animates the letter being written before each attempt (all modes except challenge). Finishing triggers a sparkle burst.

### Mode matrix

| Mode | Tamil | Canvas | Guided | Demo |
|---|---|---|---|---|
| Easy | எளிது | tube + one waypoint at a time | yes | yes |
| Medium | நடுத்தரம் | tube only | yes | yes |
| Hard | கடினம் | blank | yes, along the hidden path | yes |
| Challenge | சவால் | blank, outlined | **no** — freehand | no |

Easy shows the tube and, instead of the full dot trail, **one waypoint**: the next place to reach, which moves on as the child gets there. The tube says what the letter is; the waypoint says where to go next, which is the part a child cannot work out from a shape alone. It stays a set distance ahead of the finger so the hand never covers it. Medium then takes the waypoint away and leaves only the shape.

Hard keeps the demo because otherwise nothing tells the child which direction to write in. Challenge is the "real exam": nothing constrains the hand, and the shape is judged only on submit — it does outline the drawing area, because a canvas with nothing on it has no visible edges to write inside.

**Modes are NOT locked.** All four always tappable; Easy is the default. Two clean attempts at a mode auto-advance to the next one.

---

## 5. Scoring

**100 marks per character**, split across the modes (`assets/config/scoring_config.json`):

| Mode | Marks | Earned by |
|---|---|---|
| Easy | 25 | completion |
| Medium | 25 | completion |
| Hard | 20 + 10 | completion + fluency |
| Challenge | 20 | shape match alone |

Easy and medium are completion marks by design: the finger is snapped to the path, so half the score is always reachable by simply doing the work. That is deliberate, not an oversight.

Hard's fluency bonus is **silent** — no clock, no countdown, generous thresholds. Being slow forfeits the bonus, never a completion mark.

Challenge weighs shape only. Stroke count, order and direction are still recorded for the Parent Zone report, since stroke order is real pedagogy, but they do not affect the mark.

**Stars are cumulative** across modes: ≥30 = ⭐, ≥75 = ⭐⭐, ≥90 = ⭐⭐⭐. Each mode keeps its best result, so a worse retry never removes marks.

The first star sits at 30 rather than half marks so that **finishing hard on its own earns one**. Hard is worth 20 + 10, so a child who skips the guided modes tops out at 30; at a threshold of 50 they scored nothing, no star, and the next letter stayed locked — while the easier route through easy and medium scored 50 and opened it. Rewarding the easy path over the hard one is backwards. Whatever a child has earned is always shown, on the letter screen as well as the list, and it is read from the one store so re-entering a letter never resets the tally.

**Aggregation:**
- Character score = total marks across modes
- Category score = mean of its character scores
- Overall score = mean of categories, weighted by character count (uyirmei carries the most weight)

---

## 6. Progression & monetisation

**Nothing is locked.** Every character in every category is open from the
first launch, in any order. What tells a child where to go is a **guide ring**
— a light travelling round the edge of the one thing that is next — rather
than a wall of padlocks saying where they may not go. Guidance instead of
gating: at three to eight, a padlock reads as "you failed", and a ring reads
as "here".

Exactly one ring is on any screen; two would be a choice, which is the thing
it exists to remove. It marks the first set or character not yet finished, on
the home picker, the uyirmei rows and a letter list alike. It stops under the
device's reduce-motion setting.

The star-chain logic is still there and still tested —
`progression.starsToUnlockNext` is `0`, and raising it brings gating back
intact if it is ever wanted.

**Letters are always free.** Nothing gates the 247 or the six grantha letters
but stars — no coins, no ads, no purchase. That line is the whole reason the
rest of this section is safe.

**Games cost coins.** A game word is opened with a **heart**; one coin buys
three. A clean round — finished with no wrong drop — **gives the heart back**,
so playing well costs nothing and only a fumbled round spends anything. See
section 7.

**Monetisation:**
1. **Full Pack IAP** (~₹149, behind parental gate) — unlocks all letters immediately, unlocks all game modes and certificates.
2. **Rewarded ads in the Parent Zone only**, earning coins, always skippable after 5 seconds. Nowhere else in the app.
3. **No banner ads anywhere.** Not on home, not on category select, not on any screen. The Parent Zone is the only place an ad exists.

Coins therefore reach games, and an adult can top them up by watching an ad.
**They never reach letters**, which is what keeps "progression is never
blocked by an ad" true.

**iOS ships ad-free, IAP only** — required for App Store Kids Category.

### Compliance checklist
- [ ] Play Console → Target Audience: children
- [ ] `setTagForChildDirectedTreatment(true)`, max ad content rating **G**
- [ ] GMA SDK ≥ 20.6.0 (Android) so the advertising ID is not transmitted
- [ ] Certified Families ads SDK only (AdMob qualifies)
- [ ] Privacy policy URL live before submission (required even with zero collection)
- [ ] Content rating: Everyone / 3+
- [ ] No ad walls; nothing blocks letter progression
- [ ] Ads appear in the Parent Zone and nowhere else — no banners on any screen

---

## 7. Coins & hearts

**There are no hints.** A child who cannot form a letter has the demo, the
tube and easy mode; a paid shortcut past that is not teaching. Coins have
exactly one sink, which is what makes the balance easy to reason about.

- Starting balance: **13 coins** (config) — 39 word openings, and a clean round hands its heart straight back, so it only ever runs down on rounds that went wrong
- **Earn:** 1 per character taken to three stars, 1 per clean game round, and rewarded ads in the Parent Zone
- **Achievements** are the same two things counted: one per character taken to three stars, one per word beaten with no wrong drop. Both are derived rather than banked, so replaying either cannot mint a second.
- **Spend:** 1 coin → 3 hearts. A heart opens one game word.
- **A clean round refunds its heart** — no wrong drop at any point. A round with a wrong drop keeps the heart spent and earns no coin.

Earnings are **derived from progress, never banked**: `coinBalance()` counts
the three-star characters each time it is asked, so a letter pays exactly once
however often it is re-traced. Only spending accumulates.

A hint would have been a second sink competing with play. With one sink the
worst case is a child who has spent everything, and the refund rule means
that can only happen by losing repeatedly — at which point three hearts for a
coin they earn back by clearing any letter is a gentle enough floor.

---

## 8. Game modes

### Picture Puzzle (படம் சொல்) — 31 items
- **Uyir + ஃ (13):** show picture → child writes the *first* letter
- **Mei (18):** pure consonants cannot begin a Tamil word. Show the picture plus the word with one pure consonant blanked (e.g. பம்பரம் → ப_பரம், write ம்)

Starter word list for the 13:

| Letter | Word | Image |
|---|---|---|
| அ | அம்மா | mother holding child |
| ஆ | ஆடு | goat |
| இ | இலை | green leaf |
| ஈ | ஈ | housefly |
| உ | உரல் | stone mortar |
| ஊ | ஊஞ்சல் | swing |
| எ | எலி | mouse |
| ஏ | ஏணி | ladder |
| ஐ | ஐந்து | five fingers / five objects |
| ஒ | ஒட்டகம் | camel |
| ஓ | ஓடம் | small boat |
| ஔ | ஔவையார் | the poet (alt: ஔடதம், medicine bottle) |
| ஃ | எஃகு | steel bar |

Images: original AI-generated or CC0 only. Every image human-reviewed before shipping.

### Word Builder (சொல் கட்டு)

**Left: the picture and, beneath it, the word as a row of boxes** — each box
holding its target character as a faint shadow. **Right: the letters to drag.**
The picture and the word belong together, because the word is what the picture
*is*; the tiles are a separate thing to reach for.

A box is **exactly the size of a tile under the finger**, so what a child is
carrying and where it is going read as the same object. Tiles and boxes keep
their size and the picture gives way when room runs short — a goat that is a
little smaller is still a goat, but a letter too small to hit is not a letter.

Drag a tile into a box; light runs the box border like a snake, **green** if it
belongs there, **red** if it does not. Fill every box and the word bursts.

**The tile pool is the 31 base characters and nothing else** — 12 uyir, 18
mei, ஃ. Every other character in Tamil is built from these, and that is the
whole lesson, so the game never hands one over ready-made.

**Every consonant-vowel box takes two tiles, with no exceptions.** ம் + ஆ → மா,
and ம் + அ → ம. Splitting the inherent-a form matters more than it looks:
allowing ம as a single tile would make the rule "compose, except when you can
see no sign, in which case don't", and a rule with an exception in it is the
one a child gets wrong. Consonant first, then vowel — the other order reads as
a wrong drop.

**Word constraints**, all of which the picture set already satisfies:

| | |
|---|---|
| At most **4 characters** | longer words do not fit the row, and there is no picture for them |
| At most **2 uyirmei characters** | keeps a word to 6 tiles or fewer |
| Every character inside the 247 | a word needing ஜ or ஸ has no tiles to build it from |

That leaves **51 playable words**, 24 of them two-character, which is where to
start. They come from the curated picture set — see `tools/worksheet_art/`.

**Distractors** are chosen to *look* like the answer — ண/ன, ழ/ள, ர/ற — never
at random, since a random tile can be rejected without reading it.

**Every drop shows the tile that landed before anything happens to it**, once
the border has finished running. On the second tile of a consonant-vowel box
it then becomes the character the two make — ட் was already there, உ went
down, டு is the answer — and that join gets its own moment rather than
appearing in passing, because it is the whole lesson.

**A wrong drop is slower than a right one, and shows the child what they
actually built.** The audience is three to eight: a correction that flicks
past before they have looked up is a correction they never saw. So the light
runs the border more slowly, and only once it has finished does the box show
the letter the drop *made* — ட் plus அ reads as ட — with a cross through it.
Then it goes back to exactly what stood there before. Nothing a wrong drop
does is ever kept, and the cross is light enough to read the letter through,
because the letter is the point of the mark.

A right drop is quicker but not instant, and when the last box turns green
there is a beat with the finished word standing before the burst goes off —
the celebration should land on something the child has already looked at.

**Scoring.** A round finished with **no red at any point** earns a coin, gives
the heart back, and grants one achievement point *the first time that word is
cleared*. A round with a wrong drop can still be finished — a child is never
stuck — but it earns nothing and keeps the heart spent. A wrong drop costs no
heart of its own; the tile simply springs back.

**Entry.** Home → விளையாட்டு → Word Builder → a card per word, showing its
picture, its word, and a medal once it has been beaten cleanly. **Opening a
word spends a heart**; with none left the cards go quiet and a coin buys three
more.

**The screen carries what a child needs before they start**: hearts as a row
of shapes rather than a number — a spent one keeps its outline so what is
missing is visible — a medal for this word, and the coin balance. The **+** to
buy hearts appears where the missing hearts are, and only when there are none.

**Finishing** shows two buttons and nothing else: play it again, or take the
tick and go back. A clean round also shows **+1** beside a coin. Anything
further is a third thing to get wrong.

**Playing again is opening the word again, so it costs a heart.** With none
left the replay button becomes the way to buy some — and if there is no coin
either, it is simply absent, because an offer that cannot be taken is worse
than no offer.

**Tutorial.** Every time the game opens, a faint tile carries itself from the
tray into the box it belongs in, with a finger dot under it. Faint on purpose:
it has to read as something being shown, not something that happened, or a
child will think the first letter is already done. Touching anything cancels
it.

### Sound Match (ஒலி பொருத்து)
Play a letter sound → child picks or writes the matching letter.

### Missing Letter (விடுபட்ட எழுத்து)
Show a partial composition, child fills the blank. E.g. `ம் + _ = மா` → answer ஆ.

### Daily Challenge (தினசரி சவால்)
No levels. 5 random letters drawn from all categories, one attempt each, streak counter, bonus coins. Weight the random draw toward the child's lowest-scoring letters so it doubles as revision.

---

## 9. Audio

Every letter has: letter sound, an example word, and encouragement clips ("அருமை!", "மீண்டும் முயற்சி செய்").

**Fallback architecture** — real recordings drop in later with zero code change:

```json
"audio": {
  "letters": { "uyir_01": "assets/audio/letters/a.mp3" },
  "fallbackToTts": true
}
```

`AudioService` attempts the asset file; if absent, falls back to `flutter_tts` with Tamil locale. v1 ships fully functional on TTS. Recorded files later override individual entries.

All audio bundled as local assets — no network calls, no data collection. Global mute plus separate voice/music sliders in Parent Zone.

---

## 10. Tech stack

```
Flutter 3.x
├── State:      Riverpod
├── Storage:    shared_preferences (local only, no cloud, no login)
├── Drawing:    CustomPainter + GestureDetector (capture raw point streams)
├── Animation:  Custom path animation
├── Audio:      just_audio / audioplayers + flutter_tts fallback
├── Ads:        google_mobile_ads (Android only, feature-flagged off for iOS)
├── IAP:        in_app_purchase
├── i18n:       flutter_localizations + intl (ARB)
└── Analytics:  NONE in v1 — avoids COPPA / App Store 1.3 exposure entirely
```

**Storage is one JSON document under one key**, rewritten whole on every
change (`lib/data/repos/progress_repository.dart`). Hive and Isar earn their
keep on partial updates and queries at scale, and there are neither here: a
few hundred small records, read once at launch, never queried, smaller
altogether than a single letter's stroke file.

Marks and coins share that document but are owned by two different notifiers,
so each rewrite **waits for the read to finish** before merging. Without that,
a coin spent during launch writes its half beside an empty one and takes every
star with it — `progress_persistence_test.dart` fails if the wait is removed.
A corrupt or unreadable file opens the app empty rather than not at all.

**Fonts:** Noto Sans Tamil is **bundled** (`assets/fonts/`, OFL licensed) and used for UI. It is also the source the tracing centrelines are extracted from, so the letter a child traces is exactly the letter they read — and every device renders identical shapes. Without bundling, "match the printed letter" is undefined.

### Folder structure

```
lib/
├── core/config/       config_service.dart, models for each config file
├── data/
│   ├── models/        letter.dart, stroke.dart, score.dart
│   ├── letters/       uyir.json, strokes/
│   └── repos/
├── features/
│   ├── letters/       letter list (category)
│   ├── letter/        canvas/, trace/, scoring/
│   ├── games/
│   ├── profile/
│   ├── performance/
│   └── parent/
├── services/          audio_service.dart, ad_service.dart, iap_service.dart
└── l10n/

assets/
├── config/            app_config.json, scoring_config.json,
│                      trace_config.json, theme_config.json
├── fonts/             NotoSansTamil-Regular.ttf
├── audio/
└── images/

tools/                 stroke-data authoring (Python) — see HANDOFF.md
```

---

## 11. Design direction

Bright, high-contrast, colourful — the audience is 4–8 year olds who may not read yet. Large tap targets. Icons must be self-explanatory without text. Minimal chrome. **No dark patterns, no countdown pressure, no streak-loss guilt.**

Day theme: warm cream background, gold/amber trace gradient, soft grey-tan letter tube.

---

## 12. Build order

**Phase 1 — Demo**
12 uyir letters + ஃ · letter list · landscape letter screen with all 4 modes · stroke capture + scoring · local progress · Tamil UI. No ads, no games, no profile.

**Phase 2**
Mei (18) · uyirmei with composed strokes · coins · audio (TTS fallback).

**Phase 3**
Picture Puzzle · Word Builder · Sound Match · Missing Letter · Daily Challenge · profile · performance dashboard.

**Phase 4**
Certificates · English toggle polish · IAP · ads (Android) · Play Store submission.

**Phase 5**
iOS build, ad-free, Kids Category submission.
