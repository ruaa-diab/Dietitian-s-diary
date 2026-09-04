# تَغذية (Taghdiya)

An Arabic, right-to-left Android app for a dietitian to run her practice:
today's visits, client files, packages and payments. Built in Flutter on
Material 3, from the design canvas and implementation spec.

## Running it

```sh
flutter pub get
flutter run           # a connected device or emulator
flutter test          # 58 unit and widget tests
flutter analyze
```

Requires the Flutter stable channel (Dart SDK `^3.9.0`) and the Android
SDK. The Android module is stock `flutter create` output: `compileSdk` 36,
`minSdk` 24, `targetSdk` 36, application id `com.taghdiya.taghdiya`.

## The screens

| Screen | Code |
|---|---|
| تسجيل الدخول — login | `lib/screens/login_screen.dart` |
| أهلاً بعودتك — welcome hub | `lib/screens/welcome_screen.dart` |
| اليوم — today's visits | `lib/screens/today_screen.dart` |
| العميلات — client list | `lib/screens/clients_screen.dart` |
| ملف العميلة — client file | `lib/screens/client_detail_screen.dart` |
| الملخص — dashboard | `lib/screens/summary_screen.dart` |
| حسابي — the dietitian's own page | `lib/screens/profile_screen.dart` |
| باقة جديدة — sell a package | `lib/screens/new_package_screen.dart` |
| اكتمال الباقة — celebration | `lib/screens/package_complete_screen.dart` |
| اليوم، فارغ — empty today | `_TodayEmpty` in `today_screen.dart` |
| العميلات، فارغ — empty clients | `_ClientsEmpty` in `clients_screen.dart` |
| بطاقة التقدّم — shareable card | `lib/widgets/progress_card.dart` |

The app opens on `LoginScreen`, then the welcome hub, which greets the
dietitian and offers a direct jump into each part of the app — اليوم,
العميلات, باقة جديدة, الملخص, حسابي — rather than one generic "start"
button that always lands on today's visits. Each option passes
`HomeShell` an `initialTab`, so choosing العميلات actually opens on
العميلات. Logging out, from حسابي, clears the navigation stack on the
way to `LoginScreen` so the back button can't reveal her data again.

## Login — current state and what's still ahead

`LoginScreen` validates the form (both fields filled in, the email looks
like an email) and continues — it does not check the password against
anything real yet, marked with a `TODO(auth)` at the one line that will
change. The backend is **Firebase Authentication**, chosen alongside
Firestore for the sync work already planned — Firestore will replace the
SQLite layer described below once that migration is built, for the same
reason: it needs to work across her phone and her laptop, not just one
device. Firebase Auth is free at this app's scale, no card required, and
its session persists automatically — log in once, stay logged in across
closing and reopening the app, same as most apps, until an explicit
logout.

Two things this still needs once the Firebase project exists:
1. Swap the stub in `_LoginScreenState._login` for a real
   `FirebaseAuth.signInWithEmailAndPassword` call.
2. On launch, check `FirebaseAuth.instance.authStateChanges()` before
   showing `LoginScreen` at all, so a returning, already-signed-in session
   skips straight to the welcome hub.

`NewPackageScreen` works two ways. As a tab it starts with no client and
asks who the package is for — offering whoever just finished a package as
a *labelled* suggestion rather than filling her in silently, which read as
arbitrary. Pushed with a client (from her file, a "تجديد" button, or the
celebration) it opens on her and shows a back chevron. Saving pops when
there is a route to pop, and otherwise clears the form and returns the
shell to today's list. The celebration is a transparent route pushed over
Today, so the list stays visible behind the scrim.

## How it is put together

```
lib/
  theme/        palette, type scale, Material 3 theme
  utils/        Arabic numeral, currency and date formatting
  models/       Client, ClientPackage, Visit, Payment
  data/         AppStore, its SQLite persistence, the sample roster
  widgets/      shared components, line icons, the revenue chart
  screens/      the screens and their sheets
```

`AppStore` is a `ChangeNotifier` published through a small
`InheritedNotifier` (`StoreScope`). Screens only ever talk to it, never
to the database or the seed data directly.

## Persistence

Data lives in an on-device SQLite database (`app_database.dart`, via
`sqflite`) — closing the app no longer loses anything. `AppStore` has two
ways to start:

- `AppStore()` — in-memory only, seeded fresh each time. What tests and
  the widget-test harness use, so a test run never touches a real
  database.
- `AppStore.load()` — what `main()` calls. Opens the database, seeds it
  from `SampleData` **only if it's empty** (the very first launch), and
  reads everything back. Every mutation from there writes through in the
  background: the in-memory state (and the UI) updates immediately, and
  the write is queued so it lands in the order it happened without
  blocking on disk.

Because the seed only runs once, the six named clients and the rest of
the generated roster become real, persisted data from the moment the app
is first opened after this feature — not a fresh demo every launch like
before. Their "today" freezes on whatever day that first launch happens
to be, which is expected: once seeded data is really being kept, it
stops being reseeded to always mean "today," the same as anything else
you add.

`test/app_database_test.dart` exercises the real database code end to
end — via `sqflite_common_ffi` rather than the Android platform channel
sqflite normally uses, so it runs on any machine — proving a client, a
payment, and a visit marked attended are all still there after closing
and reopening the store.

## Rendering details

Charts are hand-rolled `CustomPainter`s (`revenue_bars.dart`), and the
icons are stroke paths on a 24-unit grid (`line_icon.dart`) transcribed
from the design's SVGs, so there is no chart or icon-font dependency.

RTL is applied as a `Directionality` wrapper in `MaterialApp.builder`, so
the whole layout mirrors — nav bar, rows, chevrons — not just text
alignment. The confetti on the celebration screen stays in plain
left-to-right coordinates, since it is just scattered shapes.

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

**The sample roster is anchored to today.** `SampleData` builds its
dates relative to `DateTime.now()` rather than to the day the mockups were
drawn, so the app always opens on a plausible day. The six clients named
in the design are seeded by hand to land on the exact states the screens
show; the rest of the 24-client book is generated so the dashboard's
revenue trend, unpaid total and renewal count are real sums rather than
captions. Placeholder figures that could not be made self-consistent
(a mockup showing "٢ متبقية" beside a visit that implies three) follow the
data instead of the picture.

## Sharing the progress card

The progress card is a plain widget laid out at its native 412pt width inside a
`RepaintBoundary`. `captureProgressCard()` renders it to PNG bytes at 3×,
which `ProgressCardScreen` writes to the temp directory and hands to the
system share sheet via `share_plus`. The card renders identically at any
device size because it is captured in its own coordinate space, not the
scaled one shown on screen.
