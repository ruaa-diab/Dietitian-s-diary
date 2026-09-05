# تَغذية (Taghdiya)

An Arabic, right-to-left Android app for a dietitian to run her practice:
today's visits, the schedule, client files and payments. Built in Flutter on
Material 3, from the design canvas and implementation spec.

## Running it

```sh
flutter pub get
flutter run           # a connected device or emulator
flutter test          # 102 unit and widget tests
flutter analyze
```

Requires the Flutter stable channel (Dart SDK `^3.9.0`) and the Android
SDK. The Android module is stock `flutter create` output: `compileSdk` 36,
`minSdk` 24, `targetSdk` 36, application id `com.taghdiya.taghdiya`.

**One setup step before it actually connects to anything real:** the app
talks to Firebase (Firestore + Authentication), and `lib/firebase_options.dart`
as committed is a placeholder — it compiles, and every test passes against
it (see [Backend](#backend) below), but it doesn't point at a real
project yet. Once a Firebase project exists:

```sh
dart pub global activate flutterfire_cli   # once
flutterfire configure                       # from the project root
```

That overwrites `lib/firebase_options.dart` with the real project's
values; nothing else needs to change. Also paste `firestore.rules` into
the project's Firestore → Rules tab (or deploy it with the Firebase CLI)
— without it the database has no access rules at all.

## The screens

| Screen | Code |
|---|---|
| تسجيل الدخول — login | `lib/screens/login_screen.dart` |
| أهلاً بعودتك — welcome hub | `lib/screens/welcome_screen.dart` |
| اليوم — today's visits | `lib/screens/today_screen.dart` |
| المواعيد — the calendar | `lib/screens/schedule_screen.dart` |
| العميلات — client list | `lib/screens/clients_screen.dart` |
| ملف العميلة — client file | `lib/screens/client_detail_screen.dart` |
| الملخص — dashboard | `lib/screens/summary_screen.dart` |
| حسابي — the dietitian's own page | `lib/screens/profile_screen.dart` |
| الدفعات — who owes what | `lib/screens/payment_screen.dart` |
| موعد جديد / تعديل الموعد | `lib/screens/appointment_sheet.dart` |
| عميلة جديدة / تعديل بياناتها | `lib/screens/new_client_sheet.dart` |
| اكتمال الباقة — celebration | `lib/screens/package_complete_screen.dart` |
| تسجيل دفعة | `lib/screens/record_payment_sheet.dart` |
| اليوم، فارغ — empty today | `_TodayEmpty` in `today_screen.dart` |
| العميلات، فارغ — empty clients | `_ClientsEmpty` in `clients_screen.dart` |
| بطاقة التقدّم — shareable card | `lib/widgets/progress_card.dart` |

The app opens on `LoginScreen`, then the welcome hub, which greets the
dietitian and offers a direct jump into each part of the app — اليوم,
المواعيد, العميلات, باقة جديدة, الملخص, حسابي — rather than one generic
"start" button that always lands on today's visits. Each option passes
`HomeShell` an `initialTab`, so choosing العميلات actually opens on
العميلات. Logging out, from حسابي, clears the navigation stack on the
way to `LoginScreen` so the back button can't reveal her data again.

## Backend

Both the account and the data are real Firebase, not a stub — the only
thing not real yet is *which* Firebase project, since that's created
through Firebase's own console by whoever owns the account (see
[Running it](#running-it) above).

- **`FirebaseAuth`** — email/password. `LoginScreen` calls
  `signInWithEmailAndPassword` for real and maps its error codes to
  Arabic messages (wrong password, bad email format, too many attempts,
  offline). There's no self-serve sign-up screen: with exactly one
  account meant to ever exist, it's created once by hand in the Firebase
  console (Authentication → Users → Add user), not built as an in-app
  flow.
- **`AuthGate`** (`lib/screens/auth_gate.dart`) sits at the very top of
  the app and owns everything downstream of "who's signed in." It
  listens to `authStateChanges()` — which is what makes "stay logged in"
  work: Firebase caches the session on-device, so a relaunch reports the
  existing user almost immediately and skips `LoginScreen` entirely — and
  on every change it remounts the whole `MaterialApp` under a
  `KeyedSubtree` keyed to the account's identity, rather than trying to
  patch the live route stack in place. That matters: a signed-in
  screen's `StoreScope` ancestor disappearing while that screen is still
  finishing a transition out is exactly the kind of "worked in the
  simple case, crashed the first time a real animation was mid-flight"
  bug that's easy to ship and a pain to reproduce later — remounting
  outright avoids the whole class of it, since old widgets are unmounted
  wholesale rather than rebuilt against an ancestor that just changed.
- **`Firestore`** — see `Persistence` below. Access is locked down by
  `firestore.rules`: every document lives under `practices/{uid}/...`,
  and the rule is simply "only that uid, signed in, may touch it."

There is one package — **٤ زيارات for ١٠٠ ₪** (`AppStore.packageRate`) —
and it is a *rate*, not a record. Nothing is stored per package; a
client's attended visits are counted and divided by it.

الدفعات is the tab that replaced a "sell a package" screen. Nothing is
sold in advance any more, so a form for creating a package had nothing to
do: the useful screen is the list of people whose visits have run past
what they have paid, tap-to-collect. The celebration is a transparent
route pushed over Today, so the list stays visible behind the scrim, and
it now offers تسجيل دفعة rather than a sale.

## How it is put together

```
lib/
  theme/        palette, type scale, Material 3 theme
  utils/        Arabic numeral, currency and date formatting
  models/       Client, ClientPackage, Visit, Payment
  data/         AppStore, its Firestore persistence, the sample roster
  widgets/      shared components, line icons, the revenue chart
  screens/      the screens and their sheets, and AuthGate
```

`AppStore` is a `ChangeNotifier` published through a small
`InheritedNotifier` (`StoreScope`). Screens only ever talk to it, never
to Firestore or the seed data directly.

## Persistence

Real data lives in Firestore, not on the device — that's the point:
edit on the phone, the change is there on the laptop too, because
they're both just showing the same account's data live, not two
separate local copies. `AppStore` has two ways to start:

- `AppStore()` — in-memory only, seeded fresh each time from
  `SampleData`. What the tests and demo mode use, so neither ever
  touches a real network. Nothing here persists or syncs.
- `AppStore.forUser(firestore, uid)` — what `AuthGate` builds the moment
  someone signs in. Starts **empty**, deliberately: a real account gets
  her real clients, not a demo roster of fictional ones she'd have to
  delete. It opens three live Firestore listeners (`CloudStore.watchClients/
  watchVisits/watchPayments` in `cloud_store.dart`) and rebuilds the
  in-memory lists — and calls `notifyListeners()` — every time any of
  them fires, which happens for a change made on *this* device and one
  made on any other device signed into the same account alike.

Three collections under `practices/{uid}/`: `clients`, `visits`,
`payments`. Payments are their own collection rather than nested inside
a package document, because there are no package documents — what a
payment settles is a running balance.

Every mutation (`markVisit`, `recordPayment`, `sellPackage`, …) updates
the in-memory lists immediately either way, so the UI never waits on a
round-trip to feel like it responded; in cloud mode the matching write is
queued in the same call (`AppStore._persist`), and the live listener
above reconciles shortly after — visually a no-op when it's just
confirming your own write, an actual update on screen when it's someone
else's.

`test/screens_test.dart`'s `login` and `AuthGate` groups exercise the
real Firestore and Firebase Auth code paths — against
`fake_cloud_firestore` and `firebase_auth_mocks`, in-memory fakes
implementing the same client APIs, so no real project or network is
needed — proving sign-in, sign-out, a fresh account opening empty, and a
wrong-credentials error message all actually work end to end, not just
that the screens render.

## Rendering details

Charts are hand-rolled `CustomPainter`s (`revenue_bars.dart`), and the
icons are stroke paths on a 24-unit grid (`line_icon.dart`) transcribed
from the design's SVGs, so there is no chart or icon-font dependency.

RTL is applied as a `Directionality` wrapper in `MaterialApp.builder`, so
the whole layout mirrors — nav bar, rows, chevrons — not just text
alignment. The confetti on the celebration screen stays in plain
left-to-right coordinates, since it is just scattered shapes.

## How visits are counted, and how money follows

**Appointments and money are not linked.** An appointment belongs to a
client, not to a package — because the real order of events is *book,
come, then pay*, and an appointment that had to belong to a package she
hadn't bought yet couldn't be booked at all. There are no package
records: `Visit` and `Payment` each carry a `clientId` and nothing else.

Everything else is arithmetic on those two lists:

| Question | Answer |
|---|---|
| How many visits has she had? | attended visits + `Client.priorVisits` |
| Which visit of four is she on? | `((attended − 1) % 4) + 1` |
| How many left before the next ١٠٠ ₪? | `4 − visitInPackage` |
| What has she cost? | `ceil(attended / 4) × ١٠٠ ₪` |
| What does she owe? | that, minus everything she has paid |

So being a package behind is a number, not a state — and being *two*
behind, which happens, needs no special case. The fifth visit starts the
second package and adds the second ١٠٠ ₪; the ninth starts the third.

**A missed appointment costs nothing.** She bought four visits; only a
visit she actually attended spends one. Marking لم تحضر records the miss
— it stays in her file, dated, and the row says "لم تُحتسب" so it can't
be misread — but her count doesn't move, and neither does her balance.
That is why every figure above counts `attended` and `visitNumber`
returns null for a no-show.

Because it is all derived, correcting anything just works. Change a
حضرت back to a لم تحضر, delete an appointment, fix a payment's amount:
the counts, the balance and the "needs to renew" flag all fall out of the
same arithmetic on the next read. Nothing has to be reconciled, because
nothing was cached.

**A client who was already coming.** `Client.priorVisits` and
`priorPaid` are opening balances for someone entered mid-relationship —
she has been coming for months and is only now being written down, or a
few visits never got recorded. They count alongside the dated rows, so
her position in the current package is right from the first day. Held as
numbers rather than invented visit records, because those would need
dates nobody has; the client file shows them as "٣ زيارة سابقة" instead.
Both are editable afterwards, since the answer is often "actually,
three".

## The schedule

المواعيد is a month grid with a dot on every day that has someone on it,
the selected day's appointments underneath, and full control over each
one: book, move the time or the date, hand it to a different client,
change what happened, or cancel it.

- **Nothing has to be bought first.** A brand-new client can be booked
  the moment she is written down — `حفظ وحجز موعد` on the new-client
  sheet does both in one go.
- **Any time, to the minute.** A visit is a point in the day, not a slot
  out of a fixed grid; nothing rounds what she picks. A new appointment
  opens on the next quarter hour rather than a fixed 10:00, so the sheet
  never opens already invalid.
- **Forwards or backwards.** A future date is a booking. A past one is
  something she is writing up after the fact — "she came last Tuesday and
  I never wrote it down", or "she came without an appointment at all" —
  so the sheet carries a حضرت / لم تحضر / موعد status field and defaults
  a past date to حضرت. Only a *scheduled* appointment is required to be
  in the future; a recorded one can sit wherever it happened.
- **Nothing is frozen.** An appointment already marked حضرت can still
  have its date, time, client or outcome changed. An earlier version
  locked those, on the theory that a recorded visit is history — but
  "I wrote that down wrong" is the normal case, not an edge one.

## Correcting things## Correcting things

Nothing entered is a one-way door:

| Wrong | Fixed from |
|---|---|
| Attendance ("she came" — she didn't) | ملف العميلة → تعديل on the visit row, or المواعيد → tap it |
| A visit that was never recorded | المواعيد → إضافة موعد, back-date it, mark حضرت |
| How many visits she had before all this | ملف العميلة → ⋯ → تعديل البيانات |
| A name, phone or age | ملف العميلة → ⋯ → تعديل البيانات |
| A client who shouldn't be there | ملف العميلة → ⋯ → حذف العميلة (takes her appointments and payments with her) |
| A payment's amount, date or method | ملف العميلة → tap the payment |
| A payment that shouldn't exist | ملف العميلة → الدفعات → 🗑 (the balance goes straight back up) |
| An appointment's time, date or client | المواعيد → tap it |
| An appointment that shouldn't exist | المواعيد → tap it → حذف الموعد |
| Her own name, her password | حسابي → الحساب |

## Design values

Colours (`lib/theme/app_colors.dart`) and type (`app_text_styles.dart`)
are the values from the spec, named after the roles they play, with the
Arabic design vocabulary kept where the spec used it — طيني clay
`#C2685E`, مريمي sage `#5F7D5A`, عسلي honey `#E9A93C`.

Both fonts are bundled as assets for offline use: **Baloo Bhaijaan 2**
(600/700/800) for display, **IBM Plex Sans Arabic** (400/500/600/700) for
body. Baloo ships as a variable font upstream, so the three static weights
in `assets/fonts/` were instanced from it.

## Two decisions worth knowing about

**Arabic-Indic digits are on by default.** The spec left digit
localization open. The mockups render every figure in ٠١٢٣, so that is the
default, and it is one switch away from Western digits: set
`AppNumerals.useArabicIndic = false`. Every user-facing number in the app
goes through `lib/utils/formatting.dart`, so nothing else has to change —
there is a test covering both settings.

**No weight tracking.** An earlier version logged weights and charted
them; that was removed at the client's request, along with the goal
field, the weight card and the chart on the progress card. If it ever
comes back it wants a `WeightLog` model and a store list beside the
existing ones — nothing else was entangled with it.

**A real signed-in account starts empty — the sample roster only exists
for tests and the mockup review, now.** Early on, `SampleData`'s 24
fictional clients were also what a real launch of the app seeded into
its (then-local) database, so the app never opened on a blank screen.
Once persistence became a real account rather than a local file, that
stopped being appropriate — nobody wants to delete نور خالد and 23 others
before entering her actual first client. `AppStore.forUser` never seeds
anything; a fresh account meets the empty-state screens (٧ and ٨) and
adds real people from there. `SampleData` is still exactly as useful as
before for what it was actually for: the in-memory `AppStore()` tests
use, anchored to `DateTime.now()` (not the day the mockups were drawn)
so a test run always exercises a plausible "today." The six clients
named in the design are seeded by hand there to land on the exact states
the screens show; the rest of the 24-client book is generated so the
dashboard's revenue trend, unpaid total and renewal count are real sums
rather than captions.

## Sharing the progress card

The progress card is a plain widget laid out at its native 412pt width inside a
`RepaintBoundary`. `captureProgressCard()` renders it to PNG bytes at 3×,
which `ProgressCardScreen` writes to the temp directory and hands to the
system share sheet via `share_plus`. The card renders identically at any
device size because it is captured in its own coordinate space, not the
scaled one shown on screen.
