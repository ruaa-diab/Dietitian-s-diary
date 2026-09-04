import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taghdiya/data/app_store.dart';
import 'package:taghdiya/data/sample_data.dart';
import 'package:taghdiya/main.dart';
import 'package:taghdiya/screens/home_shell.dart';
import 'package:taghdiya/models/models.dart';
import 'package:taghdiya/screens/client_detail_screen.dart';
import 'package:taghdiya/screens/new_client_sheet.dart';
import 'package:taghdiya/screens/welcome_screen.dart';
import 'package:taghdiya/utils/formatting.dart';
import 'package:taghdiya/screens/new_package_screen.dart';
import 'package:taghdiya/screens/package_complete_screen.dart';
import 'package:taghdiya/widgets/app_bottom_nav.dart';
import 'package:taghdiya/widgets/progress_card.dart';

/// The reference device frame from the spec.
const _frame = Size(412, 892);

/// The client file's overflow menu, which is typed with a private enum.
final _overflowMenu = find.byWidgetPredicate(
  (widget) => widget.runtimeType.toString().startsWith('PopupMenuButton<'),
);

const SampleSeed _emptySeed = (
  clients: <Client>[],
  packages: <ClientPackage>[],
  visits: <Visit>[],
);

extension on WidgetTester {
  /// Sizes the surface to the reference device and mounts [child] in the
  /// app's theme and RTL directionality.
  Future<AppStore> pumpScreen(Widget child, {AppStore? store}) async {
    view.physicalSize = _frame;
    view.devicePixelRatio = 1.0;
    addTearDown(view.resetPhysicalSize);
    addTearDown(view.resetDevicePixelRatio);

    final appStore = store ?? AppStore();
    // Mount the real app widget, not a hand-rolled MaterialApp: locale,
    // localizations delegates and theme must be the ones that ship.
    await pumpWidget(TaghdiyaApp(store: appStore, home: child));
    await pump();
    return appStore;
  }
}

void main() {
  group('01 · اليوم', () {
    testWidgets('lists today\'s visits with their actions', (tester) async {
      await tester.pumpScreen(const HomeShell());

      expect(find.text('اليوم'), findsWidgets);
      expect(find.text('٤ زيارات'), findsOneWidget);
      expect(find.text('نور خالد'), findsOneWidget);
      expect(find.text('الزيارة ٤ من ٤'), findsOneWidget);
      expect(find.text('حضرت'), findsWidgets);
      expect(find.text('لم تحضر'), findsWidgets);
      // Resolved visits collapse to a single line with an undo action.
      expect(find.text('تراجع'), findsNWidgets(2));
      expect(find.byType(AppBottomNav), findsOneWidget);
    });

    testWidgets('marking the last visit raises the celebration', (tester) async {
      await tester.pumpScreen(const HomeShell());

      await tester.tap(find.text('حضرت').first);
      // The card floats on a repeating animation, so it never "settles".
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(PackageCompleteScreen), findsOneWidget);
      expect(find.text('٤ من ٤ — الباقة اكتملت'), findsOneWidget);
      expect(find.text('أنهت نور باقتها'), findsOneWidget);
      expect(find.text('بيع الباقة التالية'), findsOneWidget);
      expect(find.text('مشاركة تقدّمها'), findsOneWidget);
      expect(find.text('لاحقاً'), findsOneWidget);
    });

    testWidgets('undo puts a resolved visit back', (tester) async {
      final store = await tester.pumpScreen(const HomeShell());
      final resolved = store.todayVisits.where((v) => v.isResolved).length;

      await tester.tap(find.text('تراجع').first);
      await tester.pumpAndSettle();

      expect(store.todayVisits.where((v) => v.isResolved).length, resolved - 1);
    });
  });

  group('07 · اليوم — فارغ', () {
    testWidgets('shows the quiet-day empty state', (tester) async {
      await tester.pumpScreen(
        const HomeShell(),
        store: AppStore(seed: _emptySeed),
      );

      expect(find.text('لا زيارات اليوم'), findsOneWidget);
      expect(find.text('إضافة موعد'), findsOneWidget);
    });
  });

  group('02 · العميلات', () {
    Future<void> openClients(WidgetTester tester) async {
      await tester.tap(find.text('العميلات').last);
      await tester.pumpAndSettle();
    }

    testWidgets('search, filters and the sticky CTA', (tester) async {
      await tester.pumpScreen(const HomeShell());
      await openClients(tester);

      expect(find.text('ابحثي عن عميلة بالاسم'), findsOneWidget);
      expect(find.text('الكل ٢٤'), findsOneWidget);
      expect(find.text('عميلة جديدة'), findsOneWidget);

      // 24 rows scroll, so reach نور through the search field.
      await tester.enterText(find.byType(TextField).first, 'نور');
      await tester.pumpAndSettle();
      expect(find.text('نور خالد'), findsOneWidget);
      expect(find.text('١ متبقية'), findsOneWidget);
    });

    testWidgets('the balance-due filter narrows the list', (tester) async {
      await tester.pumpScreen(const HomeShell());
      await openClients(tester);

      await tester.tap(find.text('رصيد مستحق ٣'));
      await tester.pumpAndSettle();

      expect(find.text('نور خالد'), findsOneWidget);
      expect(find.text('هبة منصور'), findsNothing);
    });

    testWidgets('search filters by name', (tester) async {
      await tester.pumpScreen(const HomeShell());
      await openClients(tester);

      await tester.enterText(find.byType(TextField).first, 'هبة');
      await tester.pumpAndSettle();

      expect(find.text('هبة منصور'), findsOneWidget);
      expect(find.text('نور خالد'), findsNothing);
    });
  });

  group('sheets', () {
    testWidgets('the new-client sheet opens and saves', (tester) async {
      final store = await tester.pumpScreen(const HomeShell());
      await tester.tap(find.text('العميلات').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('عميلة جديدة'));
      await tester.pumpAndSettle();

      final fields = find.descendant(
        of: find.byType(NewClientSheet),
        matching: find.byType(TextField),
      );
      await tester.enterText(fields.at(0), 'سناء قدري');
      await tester.enterText(fields.at(1), '0521119876');
      await tester.pumpAndSettle();
      await tester.tap(find.text('حفظ'));
      await tester.pumpAndSettle();

      expect(store.clients.length, 25);
      expect(store.clients.last.name, 'سناء قدري');
    });

    testWidgets('the add-appointment sheet opens from the empty day',
        (tester) async {
      await tester.pumpScreen(
        const HomeShell(),
        store: AppStore(seed: _emptySeed),
      );

      await tester.tap(find.text('إضافة موعد'));
      await tester.pumpAndSettle();

      expect(find.text('إضافة موعد اليوم'), findsOneWidget);
    });
  });

  group('08 · العميلات — فارغ', () {
    testWidgets('invites the first client', (tester) async {
      await tester.pumpScreen(
        const HomeShell(),
        store: AppStore(seed: _emptySeed),
      );
      await tester.tap(find.text('العميلات').last);
      await tester.pumpAndSettle();

      expect(find.text('لم تضيفي عميلات بعد'), findsOneWidget);
      expect(find.text('إضافة أول عميلة'), findsOneWidget);
    });
  });

  group('03 · ملف العميلة', () {
    testWidgets('identity, balance, weight and package history', (tester) async {
      await tester.pumpScreen(const ClientDetailScreen(clientId: 'c-nour'));

      expect(find.text('نور خالد'), findsOneWidget);
      expect(find.text('٠٥٤ ١٢٣ ٤٥٦٧ · ٣٤ سنة'), findsOneWidget);
      expect(find.text('رصيد مستحق'), findsOneWidget);
      expect(find.text('١٠٠ ₪'), findsWidgets);
      expect(find.text('تسجيل دفعة'), findsOneWidget);
      expect(find.text('سجل الباقات'), findsOneWidget);
      expect(find.text('غير مدفوعة'), findsOneWidget);
      expect(find.text('مدفوعة'), findsNWidgets(2));
    });

    testWidgets('marking a visit attended updates the client file',
        (tester) async {
      final store = AppStore();
      await tester.pumpScreen(const HomeShell(), store: store);

      // نور's file before: her fourth visit is still outstanding.
      final pkg = store.activePackage('c-nour')!;
      expect(store.attendedCount(pkg.id), 3);

      await tester.tap(find.text('حضرت').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      // Dismiss the celebration that the closing visit raises.
      await tester.tap(find.text('لاحقاً'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.text('العميلات').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'نور');
      await tester.pumpAndSettle();
      await tester.tap(find.text('نور خالد'));
      await tester.pumpAndSettle();

      expect(store.attendedCount(pkg.id), 4);
      // The package closed, so the file now offers a renewal.
      expect(find.text('تحتاج تجديد'), findsOneWidget);
      expect(find.text('٤ زيارات · ١٠٠ ₪'), findsWidgets);
    });

    testWidgets('the overflow menu opens', (tester) async {
      await tester.pumpScreen(const ClientDetailScreen(clientId: 'c-nour'));

      await tester.tap(_overflowMenu, warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.text('باقة جديدة'), findsOneWidget);
      expect(find.text('مشاركة تقدّمها'), findsOneWidget);
    });

    testWidgets('recording a payment clears the balance card', (tester) async {
      final store = await tester.pumpScreen(
        const ClientDetailScreen(clientId: 'c-nour'),
      );

      await tester.tap(find.text('تسجيل دفعة'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('حفظ الدفعة'));
      await tester.pumpAndSettle();

      expect(store.balanceDueFor('c-nour'), 0);
      expect(find.text('رصيد مستحق'), findsNothing);
    });
  });

  group('04 · باقة جديدة', () {
    testWidgets('as a tab it asks who the package is for', (tester) async {
      final store = await tester.pumpScreen(const NewPackageScreen());

      expect(find.text('باقة جديدة'), findsOneWidget);
      expect(find.text('بيع باقة زيارات لإحدى العميلات.'), findsOneWidget);
      // No client is chosen for her, and the suggestion is labelled.
      expect(find.text('اختاري العميلة'), findsOneWidget);
      expect(
        find.text('مقترحة: ${store.renewalCandidate!.name}'),
        findsOneWidget,
      );
      expect(find.text('٤ زيارات'), findsOneWidget);
      expect(find.text('٨ زيارات'), findsOneWidget);
      expect(find.text('٢٥ ₪ للزيارة'), findsOneWidget);
      expect(find.text('مدفوع كامل'), findsOneWidget);
      expect(find.text('الإجمالي'), findsOneWidget);
    });

    testWidgets('saving is blocked until a client is chosen', (tester) async {
      await tester.pumpScreen(const NewPackageScreen());

      final save = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'حفظ الباقة'),
      );
      expect(save.onPressed, isNull);
    });

    testWidgets('taking the suggestion fills the client in', (tester) async {
      final store = await tester.pumpScreen(const NewPackageScreen());
      final suggested = store.renewalCandidate!;

      await tester.tap(find.text('مقترحة: ${suggested.name}'));
      await tester.pumpAndSettle();

      expect(find.text(suggested.name), findsOneWidget);
      expect(find.text('اختاري العميلة'), findsNothing);

      final save = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'حفظ الباقة'),
      );
      expect(save.onPressed, isNotNull);
    });

    testWidgets('opened for a client it starts on her', (tester) async {
      await tester.pumpScreen(const NewPackageScreen(clientId: 'c-doaa'));

      expect(find.text('دعاء شاهين'), findsOneWidget);
      expect(find.text('اختاري العميلة'), findsNothing);
    });

    testWidgets('picking the eight-visit package updates the total',
        (tester) async {
      await tester.pumpScreen(const NewPackageScreen(clientId: 'c-doaa'));

      await tester.tap(find.text('٨ زيارات'));
      await tester.pumpAndSettle();

      expect(find.text('١٩٠ ₪'), findsWidgets);
    });

    testWidgets('saving sells the package', (tester) async {
      final store = AppStore();
      await tester.pumpScreen(
        const NewPackageScreen(clientId: 'c-doaa'),
        store: store,
      );
      final before = store.packagesFor('c-doaa').length;

      await tester.tap(find.text('حفظ الباقة'));
      await tester.pumpAndSettle();

      expect(store.packagesFor('c-doaa').length, before + 1);
      expect(store.activePackage('c-doaa'), isNotNull);
    });

    testWidgets('saving from the tab clears the form and hands back',
        (tester) async {
      final store = AppStore();
      var handedBack = false;
      await tester.pumpScreen(
        NewPackageScreen(onSaved: () => handedBack = true),
        store: store,
      );

      await tester.tap(find.text('مقترحة: ${store.renewalCandidate!.name}'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('حفظ الباقة'));
      await tester.pumpAndSettle();

      expect(handedBack, isTrue);
      // Ready for the next sale rather than holding the last client.
      expect(find.text('اختاري العميلة'), findsOneWidget);
    });
  });

  group('05 · الملخص', () {
    testWidgets('revenue hero, stat tiles, renewals and balances',
        (tester) async {
      await tester.pumpScreen(const HomeShell());
      await tester.tap(find.text('الملخص').last);
      await tester.pumpAndSettle();

      expect(find.text('إيرادات هذا الشهر'), findsOneWidget);
      expect(find.text('رصيد غير مدفوع'), findsOneWidget);
      expect(find.text('٣٠٠ ₪'), findsOneWidget);
      expect(find.text('تحتاج تجديد'), findsWidgets);
      expect(find.text('تجديد'), findsWidgets);

      await tester.scrollUntilVisible(find.text('أرصدة مستحقة'), 200);
      expect(find.text('أرصدة مستحقة'), findsOneWidget);
    });
  });

  group('06 · اكتمال الباقة', () {
    testWidgets('celebrates the finished package', (tester) async {
      final store = AppStore();
      final pkg = store.packagesFor('c-salma').first;
      await tester.pumpScreen(
        PackageCompleteScreen(packageId: pkg.id),
        store: store,
      );
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.textContaining('الباقة اكتملت'), findsOneWidget);
      expect(find.text('أنهت سلمى باقتها'), findsOneWidget);
      expect(find.text('بيع الباقة التالية'), findsOneWidget);
      // سلمى missed her final visit, so attendance is not full.
      expect(find.text('حضور ٣ من ٤'), findsOneWidget);
    });
  });

  group('09 · بطاقة التقدّم', () {
    testWidgets('renders the shareable card at its native width',
        (tester) async {
      final store = AppStore();
      final client = store.client('c-nour');
      final pkg = store.packagesFor('c-nour').first;

      await tester.pumpScreen(
        Scaffold(
          body: Center(
            child: FittedBox(
              child: ProgressCard(
                client: client,
                package: pkg,
                packageNumber: 3,
                days: 21,
                attendedVisits: 3,
              ),
            ),
          ),
        ),
        store: store,
      );

      expect(find.text('تَغذية'), findsOneWidget);
      expect(find.text('أ. رنين دياب · أخصائية تغذية'), findsOneWidget);
      expect(find.text('الباقة الثالثة'), findsOneWidget);
      expect(find.text('نور خالد'), findsOneWidget);
      expect(find.text('زيارات'), findsOneWidget);

      expect(
        tester.getSize(find.byType(ProgressCard)).width,
        412,
      );
    });
  });

  group('حسابي · profile tab', () {
    testWidgets('shows the practice at a glance', (tester) async {
      await tester.pumpScreen(const HomeShell());

      await tester.tap(find.text('حسابي').last);
      await tester.pumpAndSettle();

      expect(find.text('أ. رنين دياب'), findsOneWidget);
      expect(find.text('أخصائية تغذية'), findsOneWidget);
      expect(find.text('٢٤'), findsOneWidget);
      expect(find.text('هذا الشهر'), findsOneWidget);
      expect(find.text('٣٠٠ ₪'), findsOneWidget);
    });
  });

  group('shell', () {
    testWidgets('باقة جديدة is a tab again', (tester) async {
      await tester.pumpScreen(const HomeShell());

      await tester.tap(find.text('باقة جديدة').last);
      await tester.pumpAndSettle();

      expect(find.byType(NewPackageScreen), findsOneWidget);
      expect(find.text('اختاري العميلة'), findsOneWidget);
      // A tab has nothing to go back to, so no back chevron is offered.
      expect(find.byTooltip('رجوع'), findsNothing);
    });
  });

  group('welcome', () {
    testWidgets('greets Raneen and reports what is waiting', (tester) async {
      final store = await tester.pumpScreen(const WelcomeScreen());

      expect(find.text('أهلاً بعودتك'), findsOneWidget);
      expect(find.text('رنين'), findsOneWidget);
      expect(find.text('زيارتان بانتظارك'), findsOneWidget);
      expect(
        find.text('${fmtInt(store.needsRenewal.length)} تحتاج تجديد'),
        findsOneWidget,
      );
    });

    testWidgets('the CTA opens the shell', (tester) async {
      await tester.pumpScreen(const WelcomeScreen());

      await tester.tap(find.text('ابدئي اليوم'));
      await tester.pumpAndSettle();

      expect(find.byType(HomeShell), findsOneWidget);
      expect(find.byType(WelcomeScreen), findsNothing);
    });

    testWidgets('a quiet day says so', (tester) async {
      await tester.pumpScreen(
        const WelcomeScreen(),
        store: AppStore(seed: _emptySeed),
      );

      expect(find.text('لا شيء عاجل اليوم. يوم هادئ.'), findsOneWidget);
    });
  });
}
