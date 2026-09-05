import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mock_exceptions/mock_exceptions.dart';
import 'package:taghdiya/data/app_store.dart';
import 'package:taghdiya/data/sample_data.dart';
import 'package:taghdiya/main.dart';
import 'package:taghdiya/models/models.dart';
import 'package:taghdiya/screens/appointment_sheet.dart';
import 'package:taghdiya/screens/auth_gate.dart';
import 'package:taghdiya/screens/client_detail_screen.dart';
import 'package:taghdiya/screens/home_shell.dart';
import 'package:taghdiya/screens/login_screen.dart';
import 'package:taghdiya/screens/new_client_sheet.dart';
import 'package:taghdiya/screens/package_complete_screen.dart';
import 'package:taghdiya/screens/payment_screen.dart';
import 'package:taghdiya/screens/welcome_screen.dart';
import 'package:taghdiya/utils/formatting.dart';
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
  visits: <Visit>[],
  payments: <Payment>[],
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
      expect(find.text('تسجيل دفعة'), findsOneWidget);
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

  group('empty states in a short window', () {
    /// A browser window is any height its owner drags it to, and the
    /// empty states are a fixed stack of illustration, headline, sentence
    /// and button. At 560px that stack is taller than the space, which
    /// used to overflow — the yellow-and-black striped bar, and a button
    /// half off the bottom. Widget tests fail on an overflow, so pumping
    /// them short is the whole check.
    Future<void> pumpShort(WidgetTester tester, Widget child, AppStore store) async {
      tester.view.physicalSize = const Size(1366, 560);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(TaghdiyaApp(store: store, home: child));
      await tester.pump();
    }

    testWidgets('اليوم fits, and still offers the appointment button',
        (tester) async {
      await pumpShort(tester, const HomeShell(), AppStore(seed: _emptySeed));

      expect(find.text('لا زيارات اليوم'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('إضافة موعد'), 100);
      expect(find.text('إضافة موعد'), findsOneWidget);
    });

    testWidgets('العميلات fits too', (tester) async {
      final store = AppStore(seed: _emptySeed);
      await pumpShort(tester, const HomeShell(), store);
      await tester.tap(find.text('العميلات').last);
      await tester.pumpAndSettle();

      expect(find.text('لم تضيفي عميلات بعد'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('إضافة أول عميلة'), 100);
      expect(find.text('إضافة أول عميلة'), findsOneWidget);
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

      expect(find.text('موعد جديد'), findsOneWidget);
      expect(find.text('اختاري العميلة'), findsOneWidget);
    });
  });

  group('المواعيد · the schedule', () {
    /// The picker floats over the day's own list, which shows some of the
    /// same names — scope to the sheet or the finders count both.
    Finder inPicker(String text) => find.descendant(
          of: find.byType(ClientPickerSheet),
          matching: find.text(text),
        );

    /// Same problem for the appointment sheet: its status control says
    /// حضرت / لم تحضر, and so do the rows on the day behind it.
    Finder inSheet(String text) => find.descendant(
          of: find.byType(AppointmentSheet),
          matching: find.text(text),
        );

    Future<AppStore> openSchedule(WidgetTester tester, {AppStore? store}) async {
      final appStore = await tester.pumpScreen(const HomeShell(), store: store);
      await tester.tap(find.text('المواعيد').last);
      await tester.pumpAndSettle();
      return appStore;
    }

    testWidgets('opens on the current month with today selected', (tester) async {
      final store = await openSchedule(tester);
      final today = DateTime.now();

      expect(find.text('المواعيد'), findsWidgets);
      expect(find.text(ArabicDates.monthYear(today)), findsOneWidget);
      expect(find.text(ArabicDates.weekdayDayMonth(today)), findsOneWidget);
      // Today's four appointments are listed under the calendar.
      expect(
        find.text(ArabicDates.visits(store.visitsOn(today).length)),
        findsWidgets,
      );
      expect(find.text('إضافة موعد'), findsOneWidget);
    });

    testWidgets('stepping months moves the header', (tester) async {
      await openSchedule(tester);
      final today = DateTime.now();

      await tester.tap(find.byTooltip('الشهر التالي'));
      await tester.pumpAndSettle();
      expect(
        find.text(ArabicDates.monthYear(DateTime(today.year, today.month + 1))),
        findsOneWidget,
      );

      await tester.tap(find.byTooltip('الشهر السابق'));
      await tester.pumpAndSettle();
      expect(find.text(ArabicDates.monthYear(today)), findsOneWidget);
    });

    testWidgets('a day already gone can be read but not booked into',
        (tester) async {
      await openSchedule(tester);
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      // Only reachable by tapping a cell when yesterday is in this month.
      if (yesterday.month != DateTime.now().month) return;

      await tester.tap(find.text(fmtInt(yesterday.day)).first);
      await tester.pumpAndSettle();

      expect(find.text('لا يمكن حجز موعد في يوم مضى. اختاري اليوم أو يوماً قادماً.'),
          findsOneWidget);
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'إضافة موعد'),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('booking searches by name and lands on the chosen day',
        (tester) async {
      final store = await openSchedule(tester);
      final before = store.visitsForClient('c-heba').length;

      // A busy day pushes the button below the fold, where a tap lands
      // on nothing.
      await tester.ensureVisible(find.text('إضافة موعد'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('إضافة موعد'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('اختاري العميلة').last);
      await tester.pumpAndSettle();

      // The picker searches rather than making her scroll 24 names.
      await tester.enterText(find.byType(TextField).first, 'هبة');
      await tester.pumpAndSettle();
      expect(inPicker('هبة منصور'), findsOneWidget);
      expect(inPicker('نور خالد'), findsNothing);
      await tester.tap(inPicker('هبة منصور'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('حفظ الموعد'));
      await tester.pumpAndSettle();

      expect(store.visitsForClient('c-heba').length, before + 1);
      expect(find.text('هبة منصور'), findsWidgets);
    });

    testWidgets('a search with no match offers to add her', (tester) async {
      final store = await openSchedule(tester);

      // A busy day pushes the button below the fold, where a tap lands
      // on nothing.
      await tester.ensureVisible(find.text('إضافة موعد'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('إضافة موعد'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('اختاري العميلة').last);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'سناء');
      await tester.pumpAndSettle();
      expect(find.text('لا توجد عميلة بهذا الاسم.'), findsOneWidget);

      await tester.tap(find.text('إضافة عميلة جديدة'));
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

      expect(store.clients.last.name, 'سناء قدري');
      // She comes back as the picked client, and the appointment saves —
      // nothing has to be bought first.
      expect(find.text('سناء قدري'), findsWidgets);
      await tester.tap(find.text('حفظ الموعد'));
      await tester.pumpAndSettle();
      expect(store.visitsForClient(store.clients.last.id), hasLength(1));
    });

    testWidgets('an appointment can be moved, and cancelled', (tester) async {
      final store = await openSchedule(tester);
      final at = DateTime.now().add(const Duration(days: 2));
      final booked = store.scheduleVisit(clientId: 'c-nour', at: at);
      await tester.pumpAndSettle();

      await tester.tap(find.text(fmtInt(at.day)).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('نور خالد'));
      await tester.pumpAndSettle();
      expect(find.text('تعديل الموعد'), findsOneWidget);

      // Move it to another client, then cancel it outright.
      await tester.tap(find.text('نور خالد').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'هبة');
      await tester.pumpAndSettle();
      await tester.tap(inPicker('هبة منصور'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('حفظ التعديلات'));
      await tester.pumpAndSettle();
      expect(store.visit(booked.id).clientId, 'c-heba');

      await tester.tap(find.text('هبة منصور'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('حذف الموعد'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('حذف'));
      await tester.pumpAndSettle();

      expect(store.visits.map((v) => v.id), isNot(contains(booked.id)));
    });

    testWidgets('an appointment already recorded can still be corrected',
        (tester) async {
      final store = await openSchedule(tester);
      final recorded =
          store.todayVisits.firstWhere((v) => v.status == VisitStatus.attended);
      final client = store.client(recorded.clientId);
      final before = store.attendedCount(client.id);

      await tester.tap(find.text(client.name).last);
      await tester.pumpAndSettle();

      // "She didn't actually come" — the outcome is a field like any other.
      expect(find.text('تعديل الموعد'), findsOneWidget);
      await tester.tap(inSheet('لم تحضر'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('حفظ التعديلات'));
      await tester.pumpAndSettle();

      expect(store.visit(recorded.id).status, VisitStatus.noShow);
      expect(store.attendedCount(client.id), before - 1);
    });

    testWidgets('a visit that already happened can be written up',
        (tester) async {
      final store = await openSchedule(tester);
      final before = store.attendedCount('c-heba');

      // Step back a month, so every day on the grid is in the past.
      await tester.tap(find.byTooltip('الشهر السابق'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(fmtInt(15)).first);
      await tester.pumpAndSettle();

      // A past day can't be *booked* into, but it can be written up.
      expect(
        find.text('لا يمكن حجز موعد في يوم مضى. اختاري اليوم أو يوماً قادماً.'),
        findsOneWidget,
      );

      // So do it the other way: open the sheet on today, and mark it as
      // attended — the outcome is a field, not a consequence of the date.
      // (First match is the screen's own "back to today"; the last is the
      // nav tab.)
      await tester.tap(find.text('اليوم').first);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('إضافة موعد'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('إضافة موعد'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('اختاري العميلة').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'هبة');
      await tester.pumpAndSettle();
      await tester.tap(inPicker('هبة منصور'));
      await tester.pumpAndSettle();
      await tester.tap(inSheet('حضرت'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('حفظ الموعد'));
      await tester.pumpAndSettle();

      expect(store.attendedCount('c-heba'), before + 1);
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
    testWidgets('identity, balance and the visit record', (tester) async {
      final store = await tester.pumpScreen(
        const ClientDetailScreen(clientId: 'c-nour'),
      );

      expect(find.text('نور خالد'), findsOneWidget);
      expect(find.text('٠٥٤ ١٢٣ ٤٥٦٧ · ٣٤ سنة'), findsOneWidget);
      expect(find.text('رصيد مستحق'), findsOneWidget);
      expect(find.text('١٠٠ ₪'), findsWidgets);
      expect(find.text('تسجيل دفعة'), findsOneWidget);
      // Her fourth visit is still to come, so she has one left.
      expect(find.text('١ متبقية'), findsOneWidget);
      // When she last paid — the question the balance alone can't answer.
      // نور has never paid, and the card says so rather than leaving it blank.
      expect(find.text('آخر دفعة'), findsOneWidget);
      expect(store.lastPaymentFor('c-nour'), isNull);
      expect(find.text('لم تدفع بعد'), findsWidgets);
      // The arithmetic behind the balance is spelled out.
      expect(
        find.text('٣ زيارات · باقة واحدة × ١٠٠ ₪ = ١٠٠ ₪ · دُفع ٠ ₪'),
        findsOneWidget,
      );
      expect(find.text('سجل الزيارات'), findsOneWidget);
    });

    testWidgets('a client who has paid shows when she last did', (tester) async {
      final store = await tester.pumpScreen(
        const ClientDetailScreen(clientId: 'c-heba'),
      );

      final last = store.lastPaymentFor('c-heba')!;
      expect(find.text('آخر دفعة'), findsOneWidget);
      expect(
        find.text('${ArabicDates.dayMonth(last.date)} · ${fmtCurrency(last.amount)}'),
        findsOneWidget,
      );
      expect(find.text('لا يوجد مستحق'), findsOneWidget);
    });

    testWidgets('every visit shows its day and date', (tester) async {
      final store = await tester.pumpScreen(
        const ClientDetailScreen(clientId: 'c-nour'),
      );

      final visits = store.visitsForClient('c-nour');
      expect(visits, isNotEmpty);
      for (final visit in visits.take(3)) {
        expect(
          find.text('${ArabicDates.weekdayDayMonth(visit.scheduledAt)}'
              ' · ${ArabicDates.time(visit.scheduledAt)}'),
          findsOneWidget,
        );
      }
      // Each attended visit is labelled with its own place in its own
      // package — the record spans every package she has ever had.
      for (final visit in visits.take(3).where((v) => v.status == VisitStatus.attended)) {
        final number = store.visitNumber(visit);
        expect(
          find.text('حضرت · الزيارة ${fmtInt(number!)} من '
              '${fmtInt(AppStore.packageRate.visitCount)}'),
          findsWidgets,
        );
      }
    });

    testWidgets('the packages her visits add up to are listed', (tester) async {
      await tester.pumpScreen(const ClientDetailScreen(clientId: 'c-nour'));

      await tester.scrollUntilVisible(find.text('الباقات'), 200);
      await tester.pumpAndSettle();

      // نور is three visits into her first package and has paid nothing.
      expect(find.text('الباقات'), findsOneWidget);
      expect(find.text('٣ زيارات من ٤ · جارية'), findsOneWidget);
      expect(find.text('غير مدفوعة'), findsOneWidget);
    });

    testWidgets('a wrongly-marked attendance can be corrected here',
        (tester) async {
      final store = await tester.pumpScreen(
        const ClientDetailScreen(clientId: 'c-nour'),
      );
      final attended = store
          .visitsForClient('c-nour')
          .firstWhere((v) => v.status == VisitStatus.attended);
      expect(store.attendedCount('c-nour'), 3);

      // "قلت إنها حضرت وتبيّن أنها لم تحضر."
      final editRow = find.byKey(ValueKey('edit-visit-${attended.id}'));
      await tester.ensureVisible(editRow);
      await tester.pumpAndSettle();
      await tester.tap(editRow);
      await tester.pumpAndSettle();
      expect(find.text('تعديل الزيارة'), findsOneWidget);
      await tester.tap(find.text('لم تحضر'));
      await tester.pumpAndSettle();

      // The visit goes back to the package rather than being spent.
      expect(store.attendedCount('c-nour'), 2);
      expect(store.remainingVisits('c-nour'), 2);
      await tester.scrollUntilVisible(find.text('٢ متبقية'), -200);
      expect(find.text('٢ متبقية'), findsOneWidget);
      expect(find.text('لم تحضر · لم تُحتسب من الباقة'), findsWidgets);
    });

    testWidgets('editing her details from the overflow menu', (tester) async {
      final store = await tester.pumpScreen(
        const ClientDetailScreen(clientId: 'c-nour'),
      );

      await tester.tap(_overflowMenu, warnIfMissed: false);
      await tester.pumpAndSettle();
      await tester.tap(find.text('تعديل البيانات'));
      await tester.pumpAndSettle();

      // The sheet opens on her current details, not an empty form.
      expect(find.text('تعديل بيانات العميلة'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'نور خالد'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'نور خالد الأحمد');
      await tester.tap(find.text('حفظ التعديلات'));
      await tester.pumpAndSettle();

      expect(store.client('c-nour').name, 'نور خالد الأحمد');
      expect(store.client('c-nour').phone, '0541234567');
      expect(find.text('نور خالد الأحمد'), findsOneWidget);
    });

    testWidgets('deleting her asks first, then clears her out',
        (tester) async {
      final store = await tester.pumpScreen(
        const ClientDetailScreen(clientId: 'c-nour'),
      );

      await tester.tap(_overflowMenu, warnIfMissed: false);
      await tester.pumpAndSettle();
      await tester.tap(find.text('حذف العميلة'));
      await tester.pumpAndSettle();

      expect(find.text('حذف نور خالد؟'), findsOneWidget);
      await tester.tap(find.text('إلغاء'));
      await tester.pumpAndSettle();
      expect(store.clientOrNull('c-nour'), isNotNull);

      await tester.tap(_overflowMenu, warnIfMissed: false);
      await tester.pumpAndSettle();
      await tester.tap(find.text('حذف العميلة'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('حذف'));
      await tester.pumpAndSettle();

      expect(store.clientOrNull('c-nour'), isNull);
      expect(store.paymentsFor('c-nour'), isEmpty);
      expect(store.visitsForClient('c-nour'), isEmpty);
    });

    testWidgets('marking a visit attended updates the client file',
        (tester) async {
      final store = AppStore();
      await tester.pumpScreen(const HomeShell(), store: store);

      // نور's file before: her fourth visit is still outstanding.
      expect(store.attendedCount('c-nour'), 3);

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

      expect(store.attendedCount('c-nour'), 4);
      // Her four are done, so the file says the next package is next.
      expect(find.text('أكملت باقتها'), findsOneWidget);
      expect(find.text('الباقة التالية'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('الباقات'), 200);
      expect(find.text('٤ زيارات · ١٠٠ ₪'), findsWidgets);
    });

    testWidgets('the overflow menu opens', (tester) async {
      await tester.pumpScreen(const ClientDetailScreen(clientId: 'c-nour'));

      await tester.tap(_overflowMenu, warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.text('موعد جديد'), findsOneWidget);
      expect(find.text('تسجيل دفعة'), findsWidgets);
      expect(find.text('تعديل البيانات'), findsOneWidget);
      expect(find.text('مشاركة تقدّمها'), findsOneWidget);
      expect(find.text('حذف العميلة'), findsOneWidget);
    });

    testWidgets('recording a payment clears the balance card', (tester) async {
      final store = await tester.pumpScreen(
        const ClientDetailScreen(clientId: 'c-nour'),
      );

      await tester.tap(find.widgetWithText(FilledButton, 'تسجيل دفعة'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('حفظ الدفعة'));
      await tester.pumpAndSettle();

      // The sheet defaults to a package's price, which is exactly what
      // her three visits have cost.
      expect(store.balanceDueFor('c-nour'), 0);
      expect(find.text('رصيد مستحق'), findsNothing);
    });
  });

  group('04 · الدفعات', () {
    testWidgets('lists who owes what', (tester) async {
      final store = await tester.pumpScreen(const PaymentScreen());

      expect(find.text('الدفعات'), findsOneWidget);
      expect(find.text('عليهنّ مستحقات'), findsOneWidget);
      expect(find.text('إجمالي المستحق'), findsOneWidget);
      expect(find.text(fmtCurrency(store.totalOutstanding)), findsWidgets);
      // The three who owe, and nobody else.
      expect(find.text('نور خالد'), findsOneWidget);
      expect(find.text('لمى صبري'), findsOneWidget);
      expect(find.text('أمل حجازي'), findsOneWidget);
      expect(find.text('هبة منصور'), findsNothing);
    });

    testWidgets('a client two packages behind is called out', (tester) async {
      final store = AppStore();
      store.addClient(name: 'وفاء نمر', phone: '0521234000', priorVisits: 8);
      await tester.pumpScreen(const PaymentScreen(), store: store);

      expect(find.text('٨ زيارات · متأخرة بـباقتين'), findsOneWidget);
    });

    testWidgets('tapping a row records the payment against her', (tester) async {
      final store = await tester.pumpScreen(const PaymentScreen());
      expect(store.balanceDueFor('c-nour'), 100);

      await tester.tap(find.text('نور خالد'));
      await tester.pumpAndSettle();
      expect(find.text('المستحق عليها'), findsOneWidget);

      await tester.tap(find.text('حفظ الدفعة'));
      await tester.pumpAndSettle();

      expect(store.balanceDueFor('c-nour'), 0);
      expect(find.text('نور خالد'), findsNothing);
    });

    testWidgets('everything settled says so', (tester) async {
      final store = AppStore(seed: _emptySeed);
      await tester.pumpScreen(const PaymentScreen(), store: store);

      expect(find.text('لا مستحقات على أحد. كل الحسابات مسدّدة.'), findsOneWidget);
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
      expect(find.text('دفعة'), findsWidgets);

      await tester.scrollUntilVisible(find.text('أرصدة مستحقة'), 200);
      expect(find.text('أرصدة مستحقة'), findsOneWidget);
    });
  });

  group('06 · اكتمال الباقة', () {
    testWidgets('celebrates the finished package', (tester) async {
      final store = AppStore();
      await tester.pumpScreen(
        const PackageCompleteScreen(clientId: 'c-salma'),
        store: store,
      );
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.textContaining('الباقة اكتملت'), findsOneWidget);
      expect(find.text('أنهت سلمى باقتها'), findsOneWidget);
      // She is paid up, so it offers the next package's payment.
      expect(find.text('تسجيل دفعة الباقة التالية'), findsOneWidget);
      // And she missed one appointment along the way.
      expect(find.text('غابت زيارة واحدة'), findsOneWidget);
    });

    testWidgets('names what she owes when she is behind', (tester) async {
      final store = AppStore();
      // نور's fourth visit finishes her package, unpaid.
      final visit = store.todayVisits.firstWhere((v) => v.clientId == 'c-nour');
      store.markVisit(visit.id, VisitStatus.attended);

      await tester.pumpScreen(
        const PackageCompleteScreen(clientId: 'c-nour'),
        store: store,
      );
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.textContaining('المستحق عليها الآن ١٠٠ ₪'), findsOneWidget);
      expect(find.text('تسجيل دفعة'), findsOneWidget);
    });
  });

  group('09 · بطاقة التقدّم', () {
    testWidgets('renders the shareable card at its native width',
        (tester) async {
      final store = AppStore();
      final client = store.client('c-nour');

      await tester.pumpScreen(
        Scaffold(
          body: Center(
            child: FittedBox(
              child: ProgressCard(
                client: client,
                packageNumber: 3,
                packageSize: 4,
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

    testWidgets('renaming herself changes the greeting too', (tester) async {
      final store = await tester.pumpScreen(const HomeShell());

      await tester.tap(find.text('حسابي').last);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('تعديل الاسم'), 200);
      await tester.tap(find.text('تعديل الاسم'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'د. سارة العلي');
      await tester.tap(find.text('حفظ'));
      await tester.pumpAndSettle();

      expect(store.dietitianName, 'د. سارة العلي');
      // The identity card is back at the top of the page we scrolled down.
      await tester.scrollUntilVisible(find.text('د. سارة العلي'), -200);
      expect(find.text('د. سارة العلي'), findsOneWidget);

      // And the welcome screen greets her by the new given name.
      await tester.pumpScreen(const WelcomeScreen(), store: store);
      expect(find.text('سارة'), findsOneWidget);
    });

    testWidgets('the change-password sheet validates before submitting',
        (tester) async {
      await tester.pumpScreen(const HomeShell());

      await tester.tap(find.text('حسابي').last);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('تغيير كلمة المرور'), 200);
      await tester.tap(find.text('تغيير كلمة المرور'));
      await tester.pumpAndSettle();

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'old-password');
      await tester.enterText(fields.at(1), '123');
      await tester.enterText(fields.at(2), '123');
      await tester.tap(find.text('حفظ كلمة المرور'));
      await tester.pumpAndSettle();
      expect(find.text('كلمة المرور الجديدة ٦ خانات على الأقل.'), findsOneWidget);

      await tester.enterText(fields.at(1), 'new-password');
      await tester.enterText(fields.at(2), 'new-passwrod');
      await tester.tap(find.text('حفظ كلمة المرور'));
      await tester.pumpAndSettle();
      expect(find.text('كلمتا المرور غير متطابقتين.'), findsOneWidget);
    });

    // Signing out for real — AuthGate reacting to an actual auth-state
    // change and replacing the whole screen — is covered under the
    // AuthGate group below. A plain in-memory AppStore(), which is all
    // pumpScreen's harness gives ProfileScreen here, has no FirebaseAuth
    // of its own to sign out of, so tapping تسجيل الخروج is correctly a
    // no-op in that setup, not something to assert navigation on.
  });

  group('shell', () {
    testWidgets('الدفعات is a tab of its own', (tester) async {
      await tester.pumpScreen(const HomeShell());

      await tester.tap(find.text('دفعات').last);
      await tester.pumpAndSettle();

      expect(find.byType(PaymentScreen), findsOneWidget);
      expect(find.text('عليهنّ مستحقات'), findsOneWidget);
      // A tab has nothing to go back to, so no back chevron is offered.
      expect(find.byTooltip('رجوع'), findsNothing);
    });
  });

  group('login', () {
    // LoginScreen reads FirebaseAuth.instance the moment it's constructed
    // if no auth is supplied, and that singleton has no real project to
    // talk to in a test environment — every test here supplies a mock.
    testWidgets('greets Raneen with the credential form', (tester) async {
      await tester.pumpScreen(LoginScreen(auth: MockFirebaseAuth()));

      expect(find.text('أهلاً بعودتك'), findsOneWidget);
      expect(find.text('رنين'), findsOneWidget);
      expect(find.text('البريد الإلكتروني'), findsOneWidget);
      expect(find.text('كلمة المرور'), findsOneWidget);
      expect(find.text('تسجيل الدخول'), findsOneWidget);
    });

    testWidgets('rejects empty fields without calling Firebase at all',
        (tester) async {
      final auth = MockFirebaseAuth();
      await tester.pumpScreen(LoginScreen(auth: auth));

      await tester.tap(find.text('تسجيل الدخول'));
      await tester.pumpAndSettle();

      expect(find.text('أدخلي البريد الإلكتروني وكلمة المرور.'), findsOneWidget);
      expect(auth.currentUser, isNull);
    });

    testWidgets('rejects a malformed email', (tester) async {
      await tester.pumpScreen(LoginScreen(auth: MockFirebaseAuth()));

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'not-an-email');
      await tester.enterText(fields.at(1), 'whatever');
      await tester.tap(find.text('تسجيل الدخول'));
      await tester.pumpAndSettle();

      expect(find.text('تحققي من صيغة البريد الإلكتروني.'), findsOneWidget);
    });

    testWidgets('valid credentials sign her in', (tester) async {
      final auth = MockFirebaseAuth(
        mockUser: MockUser(uid: 'raneen-uid', email: 'raneen@example.com'),
      );
      await tester.pumpScreen(LoginScreen(auth: auth));

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'raneen@example.com');
      await tester.enterText(fields.at(1), 'whatever');
      await tester.tap(find.text('تسجيل الدخول'));
      await tester.pumpAndSettle();

      // LoginScreen doesn't navigate itself — AuthGate does, tested
      // separately — but it must have actually signed her in.
      expect(auth.currentUser?.uid, 'raneen-uid');
      expect(find.textContaining('تعذّر'), findsNothing);
    });

    testWidgets('shows a friendly message for wrong credentials',
        (tester) async {
      final auth = MockFirebaseAuth();
      whenCalling(Invocation.method(#signInWithEmailAndPassword, null))
          .on(auth)
          .thenThrow(FirebaseAuthException(code: 'invalid-credential'));
      await tester.pumpScreen(LoginScreen(auth: auth));

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'raneen@example.com');
      await tester.enterText(fields.at(1), 'wrong');
      await tester.tap(find.text('تسجيل الدخول'));
      await tester.pumpAndSettle();

      expect(find.text('البريد الإلكتروني أو كلمة المرور غير صحيحة.'), findsOneWidget);
      expect(auth.currentUser, isNull);
    });

    testWidgets('typing again clears a shown error', (tester) async {
      await tester.pumpScreen(LoginScreen(auth: MockFirebaseAuth()));

      await tester.tap(find.text('تسجيل الدخول'));
      await tester.pumpAndSettle();
      expect(find.text('أدخلي البريد الإلكتروني وكلمة المرور.'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'r');
      await tester.pump();

      expect(find.text('أدخلي البريد الإلكتروني وكلمة المرور.'), findsNothing);
    });
  });

  group('AuthGate', () {
    // AuthGate builds its own MaterialApp rather than going through
    // pumpScreen's helper, so the reference-frame size is set by hand —
    // otherwise a screen taller than the default test surface (حسابي's
    // included) never gets its lower widgets built into the tree at
    // all, sliver viewport culling being what it is.
    Future<void> pumpSized(WidgetTester tester, Widget widget) async {
      tester.view.physicalSize = _frame;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(widget);
    }

    testWidgets('signed out shows the login screen', (tester) async {
      final auth = MockFirebaseAuth();
      await pumpSized(tester, AuthGate(auth: auth, firestore: FakeFirebaseFirestore()));
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('an already-signed-in session skips straight past login',
        (tester) async {
      final auth = MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'raneen-uid', email: 'raneen@example.com'),
      );
      await pumpSized(tester, AuthGate(auth: auth, firestore: FakeFirebaseFirestore()));
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsNothing);
      expect(find.byType(WelcomeScreen), findsOneWidget);
    });

    testWidgets('a fresh account opens on the empty state, not sample data',
        (tester) async {
      final auth = MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'raneen-uid', email: 'raneen@example.com'),
      );
      await pumpSized(tester, AuthGate(auth: auth, firestore: FakeFirebaseFirestore()));
      await tester.pumpAndSettle();

      expect(find.text('لا زيارات اليوم'), findsOneWidget);
    });

    testWidgets('signing out from حسابي returns to the login screen',
        (tester) async {
      final auth = MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'raneen-uid', email: 'raneen@example.com'),
      );
      await pumpSized(tester, AuthGate(auth: auth, firestore: FakeFirebaseFirestore()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('حسابي'));
      await tester.pumpAndSettle();

      // The page ends with the logout button, below the account card.
      await tester.scrollUntilVisible(find.text('تسجيل الخروج'), 200);
      await tester.tap(find.text('تسجيل الخروج'));
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(auth.currentUser, isNull);
    });
  });

  group('welcome', () {
    testWidgets('greets Raneen and offers every section', (tester) async {
      final store = await tester.pumpScreen(const WelcomeScreen());

      expect(find.text('أهلاً بعودتك'), findsOneWidget);
      expect(find.text('رنين'), findsOneWidget);
      expect(find.text('زيارتان بانتظارك'), findsOneWidget);
      expect(find.text('${fmtInt(store.clients.length)} عميلة'), findsOneWidget);

      for (final label in [
        'اليوم',
        'المواعيد',
        'العميلات',
        'الدفعات',
        'الملخص',
        'حسابي',
      ]) {
        expect(find.text(label), findsOneWidget);
      }
    });

    testWidgets('a quiet day says so on the اليوم option', (tester) async {
      await tester.pumpScreen(
        const WelcomeScreen(),
        store: AppStore(seed: _emptySeed),
      );

      expect(find.text('لا زيارات اليوم'), findsOneWidget);
    });

    testWidgets('اليوم opens the shell on that tab', (tester) async {
      await tester.pumpScreen(const WelcomeScreen());

      await tester.tap(find.text('اليوم'));
      await tester.pumpAndSettle();

      expect(find.byType(HomeShell), findsOneWidget);
      expect(find.byType(WelcomeScreen), findsNothing);
      // The Today screen's own heading confirms which tab is selected.
      expect(find.text('٤ زيارات'), findsOneWidget);
    });

    testWidgets('العميلات opens the shell straight on that tab',
        (tester) async {
      await tester.pumpScreen(const WelcomeScreen());

      await tester.tap(find.text('العميلات'));
      await tester.pumpAndSettle();

      expect(find.byType(HomeShell), findsOneWidget);
      expect(find.text('ابحثي عن عميلة بالاسم'), findsOneWidget);
    });
  });
}
