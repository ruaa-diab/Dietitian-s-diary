# تَغذية (Taghdiya)

An Arabic, right-to-left Android app for a dietitian to run her practice:
today's visits, client files, packages and payments. Built in Flutter on
Material 3, from the design canvas and implementation spec.

## Running it

```sh
flutter pub get
flutter run           # a connected device or emulator
flutter test          # 45 unit and widget tests
flutter analyze
```

Requires the Flutter stable channel (Dart SDK `^3.9.0`) and the Android
SDK. The Android module is stock `flutter create` output: `compileSdk` 36,
`minSdk` 24, `targetSdk` 36, application id `com.taghdiya.taghdiya`.

## The screens

| Screen | Code |
|---|---|
| أهلاً بعودتك — welcome landing | `lib/screens/welcome_screen.dart` |
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

The app opens on the welcome screen, which greets the dietitian and says
what is waiting before handing off to `HomeShell`. The shell's four tabs
are اليوم, العميلات, الملخص and حسابي.

Selling a package is deliberately not a tab: a package always belongs to
one client, so it is reached from that client's file (overflow menu) or
from a "تجديد" button in the summary, both of which pass the client in.
Screen 06 is a transparent route pushed over Today, so the list stays
visible behind the scrim.

## How it is put together

```
lib/
  theme/        palette, type scale, Material 3 theme
  utils/        Arabic numeral, currency and date formatting
  models/       Client, ClientPackage, Visit, Payment, WeightLog
  data/         AppStore (in-memory state) + the sample roster
  widgets/      shared components, line icons, charts, illustrations
  screens/      the nine screens and their sheets
```

`AppStore` is a `ChangeNotifier` published through a small
`InheritedNotifier` (`StoreScope`). Screens never touch the seed data
directly, so pointing the app at a real database means replacing
`SampleData` and the mutation methods on the store — nothing else.

Charts are hand-rolled `CustomPainter`s (`weight_chart.dart`,
`revenue_bars.dart`), and the icons are stroke paths on a 24-unit grid
(`line_icon.dart`) transcribed from the design's SVGs, so there is no
chart or icon-font dependency.

RTL is applied as a `Directionality` wrapper in `MaterialApp.builder`, so
the whole layout mirrors — nav bar, rows, chevrons — not just text
alignment. The two places that stay left-to-right on purpose are the
weight chart (time runs left to right, oldest reading first, matching the
design) and the confetti coordinates.

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
