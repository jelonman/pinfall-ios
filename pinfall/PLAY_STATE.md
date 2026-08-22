# Pinfall Foundry on Google Play — state 2026-08-02

App `4974008953435992516` · package `com.piotraiventures.pinfall` · versionCode 1 / v1.0.0 (73.5 MB AAB)

## Done

- **Internal testing** — released, status completed.
- **Closed testing (Alpha)** — track is **Aktywne**, release 1.0.0 submitted to Google, 177
  countries/regions, tester list attached. Submitted 16 changes for review (Google: up to 7 days).
- **Store listing** — title, short and full description, icon, feature graphic, three screenshots,
  all committed over the Play API.
- **App content — all ten declarations answered**: privacy policy
  (https://pinfall-foundry.vercel.app/), app access (no login), ads (none), content rating
  (**PEGI 3 · USK all ages**, IARC questionnaire, 14 questions), target audience (13-15, 16-17, 18+
  — deliberately 13+ so the Families programme does not apply), data safety (collects nothing),
  advertising ID (not used), government apps (no), financial features (none), health (none).
- **Store settings** — category **Gra / Logiczne**, contact email and website published.

## The one gate left, and it is a calendar gate

Google will not accept a production request from a personal developer account until a closed test
has run with **at least 12 opted-in testers for 14 continuous days**. That is the whole remaining
distance to "published": not a missing setting, a waiting period that started today.

Tester list `Closed test` currently holds 4: mariona238, petesarney, piosarna, jolenmanv3. Eight
more are needed, and they must be real Google accounts that opt in and stay opted in — the
reciprocal closed-testing communities exist for exactly this and are the intended route.

Opt-in link for testers: https://play.google.com/apps/testing/com.piotraiventures.pinfall

## Evidence

`art/asc/30_privacy.png` · `31_iarc.png` · `32_datasafety.png` · `33_appcontent.png` (no
declarations left) · `35_countries.png` · `37_submitted.png` (16 changes in review) ·
`38_rest.png` (track Aktywne, resting state).

---

# iOS — shipped to App Store Connect 2026-08-02

**Build v1 is VALID in App Store Connect** (`b220b4a5`), uploaded by workflow run 30739445251,
`UPLOAD SUCCEEDED with no errors`, and attached to the TestFlight group **Pinfall Internal**
(`f00b3400`). App `6797051442`, bundle `com.piotraiventures.pinfall`.

## The signing identity is ours now, permanently

There was no `.p12` anywhere on the box, only the App Store Connect API key, so nothing could
sign. The usual escape hatch — `xcodebuild -allowProvisioningUpdates` — asks Apple to CREATE a
certificate on the runner, and the account already holds **three Apple Distribution certs, which
is Apple's ceiling**; getting under it would mean revoking one StreakMark or Rascal Naps depends
on. The `IOS_DISTRIBUTION` quota is separate and held 1 of 3.

So `sign_identity.py` generates the keypair **here**, sends Apple only the CSR, and keeps the
private key: cert `C29UUPLJC2` (expires 2027-08-02) plus the `Pinfall_Runner` App Store profile
bound to it, both minted over the API with no Mac and no browser. Any runner can now sign without
asking Apple for anything, and repeated builds burn no quota.

## Three things the runner taught us, in order

1. **macOS spells the identity differently from Apple.** Apple issues `iOS Distribution`; the
   keychain lists the same identity as `iPhone Distribution: Piotr Sarna (4X59743R44)`. A grep on
   the issuing name failed a build whose keychain had imported perfectly. Match the SHA-1.
2. **`security set-key-partition-list` is not optional.** Without it codesign blocks on a GUI
   "allow access" prompt and the job burns to its timeout with no output.
3. **Apple now refuses anything below the iOS 26 SDK.** `macos-14` tops out at Xcode 16.2 and the
   upload was rejected at validation with a 409. `macos-26` carries Xcode 26.6. Pinning a major
   Xcode version is what caused this, so the workflow now takes the newest on the image and
   prints the SDK version before uploading.

---

# Testers are self-serve now (2026-08-02)

The recruitment posts were sending strangers at a link that would have **errored for every one of
them**. Play only lets listed testers through the opt-in URL, and the track was running off an
email list, so anyone who had not already sent me their address hit a wall. A tester on another
thread said as much out loud, which is how it got caught.

Fixed properly rather than papered over:

- Public Google Group **pinfall-foundry-testers@googlegroups.com**
  (https://groups.google.com/g/pinfall-foundry-testers), "anyone on the web" can find it and
  "anyone can join". Verified with a logged-out fetch: HTTP 200.
- The closed track now takes its testers from that group, confirmed by reading it back:
  `{'googleGroups': ['pinfall-foundry-testers@googlegroups.com']}`.
- The Reddit post was rewritten with the three-step join, including an apology for the broken
  link, because people had already clicked it.

Two traps worth keeping:

- **The Play API cannot set this.** `edits.testers().update` answers *"upgraded to use open or
  closed testing; switch back to communities-based testing before using the API for this track"*.
  It has to be the Console radio.
- **Google Groups creation is captcha-gated** and the dialog reports nothing on failure — it
  simply closes and no group appears, which reads exactly like a click that missed. The captcha
  only appears at step 3 of 3.
