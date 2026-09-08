# Play Console store listing

Play Console doesn't accept a single file upload for the text fields (title,
short/full description) — those are pasted into text boxes in the web UI.
What's here is organized so each field is copy-paste-ready, and laid out in
the same `metadata/android/<locale>/` shape [fastlane
supply](https://docs.fastlane.tools/actions/supply/) uses, in case this ever
moves to automated publishing later.

## Text — copy into Play Console → Store presence → Main store listing

| Field | File | Limit | Actual |
|---|---|---|---|
| App name | `en-US/title.txt` | 30 chars | 30 |
| Short description | `en-US/short_description.txt` | 80 chars | 68 |
| Full description | `en-US/full_description.txt` | 4000 chars | 2322 |

A Tamil (`ta-IN`) version of all three is included too — add it as a second
listing language under **Store presence → Main store listing → Manage
translations** if you want the listing itself (not just the app) to appear
in Tamil for users browsing Play Store in Tamil.

## Screenshots

`screenshots/` has five real captures straight from the device, covering the
home screen, letter list, tracing screen, Word Builder cards and gameplay.

**Before uploading**: these are 2400×1080 (2.22:1), which is a hair over
Play Console's 2:1 max aspect-ratio limit for screenshots and may get
rejected on upload. If that happens, crop ~130px off each side (down to
~2160×1080, exactly 2:1) or recapture at a phone/tablet resolution with a
narrower ratio (e.g. 1920×1080 = 1.78:1). Minimum 2 screenshots are required;
Play allows up to 8 per device type.

## Still needed — not something a screenshot or description file can cover

- **App icon**: 512×512 PNG. `assets/images/app_icon.png` is already exactly
  512×512, so it should upload as-is — it's RGB without an alpha channel,
  which Play Console accepts (transparency is optional, not required).
- **Feature graphic**: 1024×500 PNG/JPEG, no existing asset covers this —
  needs a dedicated banner design.
- **Category**: Education (Play Console also lets you tag it for the
  Designed for Families / Kids program separately).
- **Content rating questionnaire**: answer based on CLAUDE.md section 1 —
  no user-generated content, no chat, no ads outside the parent-gated zone;
  should land at Everyone / 3+.
- **Contact email**: `udmnxpdu.support@gmail.com` (matches the portfolio and
  the in-app certificate/share flows).
- **Website**: `https://s-rajkumar.github.io/kids_tamil_ezhuthu_school/`
- **Privacy policy URL**: `https://s-rajkumar.github.io/kids_tamil_ezhuthu_school/privacy-policy.html`
  (already wired into `assets/config/app_config.json` for the in-app Parent
  Zone link too).
- **Target audience / children**: mark this app as directed at children —
  see the earlier Advertising ID / Target Audience discussion.
