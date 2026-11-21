import 'dart:convert';
import 'dart:typed_data';

import 'package:el3yada/core/platform/app_platform.dart';
import 'package:el3yada/features/admin_billing/data/admin_billing_repository.dart';
import 'package:el3yada/features/admin_billing/data/fake_admin_billing_repository.dart';
import 'package:el3yada/features/admin_billing/domain/admin_billing_models.dart';
import 'package:el3yada/features/analytics/application/analytics_providers.dart';
import 'package:el3yada/features/analytics/data/analytics_repository.dart';
import 'package:el3yada/features/analytics/data/fake_analytics_repository.dart';
import 'package:el3yada/features/analytics/domain/analytics_models.dart';
import 'package:el3yada/features/billing/application/screenshot_picker.dart';
import 'package:el3yada/features/billing/data/billing_repository.dart';
import 'package:el3yada/features/billing/data/fake_billing_repository.dart';
import 'package:el3yada/features/billing/domain/billing_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/admin_support.dart';
import '../support/app_flow.dart';

const _phone = Size(400, 800);
const _desktop = Size(1400, 900);

/// A 1×1 PNG, so Image.memory has something to draw.
final _png = Uint8List.fromList(
  base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
  ),
);

class _OnePicture implements ScreenshotPicker {
  @override
  Future<List<ScreenshotFile>> pick({required int max}) async => [
    ScreenshotFile(name: 'transfer.png', bytes: _png),
  ];
}

/// Pumps the app on [size] and signs in as [who]. The Phase 7 repositories are the offline ones, passed in so a
/// test can read what they hold afterwards.
Future<void> _open(
  WidgetTester tester,
  String who, {
  Size size = _phone,
  Map<String, Object> prefs = const {'settings.locale': 'en'},
  FakeBillingRepository? billing,
  FakeAnalyticsRepository? analytics,
  FakeAdminBillingRepository? admin,
}) async {
  await pumpApp(
    tester,
    size: size,
    prefs: prefs,
    platform: size.width >= 1024 ? AppPlatform.desktop : AppPlatform.mobile,
    extra: [
      billingRepositoryProvider.overrideWithValue(
        billing ?? FakeBillingRepository(),
      ),
      analyticsRepositoryProvider.overrideWithValue(
        analytics ?? FakeAnalyticsRepository(),
      ),
      adminBillingRepositoryProvider.overrideWithValue(
        admin ?? FakeAdminBillingRepository(),
      ),
      screenshotPickerProvider.overrideWithValue(_OnePicture()),
    ],
  );
  if (prefs['settings.locale'] == 'ar') {
    await tester.enterText(find.byType(TextFormField).at(0), who);
    await tester.enterText(find.byType(TextFormField).at(1), 'dev');
    await tester.tap(find.byType(FilledButton).first);
    await settle(tester);
  } else {
    await signIn(tester, who);
  }
}

Future<void> _go(WidgetTester tester, String path) async {
  goTo(tester, path);
  await settle(tester);
}

void main() {
  group('D18–D20: billing', () {
    testWidgets(
      'D18 shows the invoice to pay first, the running month and every invoice',
      (tester) async {
        await _open(tester, 'doctor@el3yada.dev');
        await _go(tester, '/doctor/billing');

        expect(find.text('Billing'), findsWidgets);
        expect(find.widgetWithText(FilledButton, 'Pay'), findsOneWidget);
        expect(find.text('This month so far'), findsOneWidget);
        // The overdue month is the one to pay first (the oldest unpaid); the unpaid one is in the list.
        expect(find.text('Overdue'), findsWidgets);
        expect(find.text('Unpaid'), findsWidgets);
        expect(find.text('Paid'), findsWidgets);
      },
    );

    testWidgets(
      'paying: a screenshot is required, then the invoice goes under review',
      (tester) async {
        final billing = FakeBillingRepository();
        await _open(
          tester,
          'doctor@el3yada.dev',
          billing: billing,
          size: const Size(400, 1800),
        );
        await _go(tester, '/doctor/billing');

        await tester.tap(find.widgetWithText(FilledButton, 'Pay'));
        await settle(tester);
        expect(find.text('Submit a payment'), findsOneWidget);
        expect(find.text('Where to send the money'), findsOneWidget);
        expect(find.text('el3yada@instapay'), findsOneWidget);

        // No screenshot yet.
        await tester.ensureVisible(find.text('Send for review'));
        await tester.tap(find.text('Send for review'));
        await tester.pump();
        expect(
          find.text('Add at least one screenshot of the transfer'),
          findsOneWidget,
        );

        await tester.tap(find.text('Add a screenshot'));
        await tester.pumpAndSettle();
        expect(find.byType(Image), findsWidgets);
        await tester.ensureVisible(find.text('Send for review'));
        await tester.tap(find.text('Send for review'));
        await settle(tester);

        // Back on D19, now under review, with the submitted payment listed.
        expect(find.text('Pending review'), findsWidgets);
        expect(find.widgetWithText(FilledButton, 'Pay'), findsNothing);
        final list = await billing.invoices();
        expect(list.underReview, isNotNull);
        expect(list.underReview!.status, InvoiceStatus.pendingReview);
      },
    );

    testWidgets('an invalid amount is refused before anything is sent', (
      tester,
    ) async {
      final billing = FakeBillingRepository();
      await _open(
        tester,
        'doctor@el3yada.dev',
        billing: billing,
        size: const Size(400, 1800),
      );
      final first = (await billing.invoices()).attention!;
      await _go(tester, '/doctor/billing/${first.id}/pay');

      await tester.enterText(find.byType(TextFormField).first, '0');
      await tester.ensureVisible(find.text('Add a screenshot'));
      await tester.tap(find.text('Add a screenshot'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Send for review'));
      await tester.tap(find.text('Send for review'));
      await tester.pump();

      expect(find.text('Enter the amount you transferred'), findsOneWidget);
      expect((await billing.invoice(first.id)).invoice.status, first.status);
    });

    testWidgets('D18 in Arabic on a phone', (tester) async {
      await _open(
        tester,
        'doctor@el3yada.dev',
        prefs: const {'settings.locale': 'ar'},
      );
      await _go(tester, '/doctor/billing');

      expect(find.text('الفواتير'), findsWidgets);
      expect(find.text('سداد'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });

  group('D1 and D35: analytics', () {
    testWidgets(
      'D1 shows the filter bar, the KPI tiles, the insights and the charts',
      (tester) async {
        await _open(tester, 'doctor@el3yada.dev', size: _desktop);
        await _go(tester, '/doctor/dashboard');

        expect(find.text('This month'), findsWidgets);
        expect(find.text('Clinic revenue'), findsOneWidget);
        expect(find.text('Net income'), findsOneWidget);
        expect(find.text('Platform fees'), findsWidgets);
        expect(find.text('Insights'), findsOneWidget);
        expect(find.text('Revenue over time'), findsOneWidget);
        expect(find.text('Patients not seen recently'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'changing the visit type changes the filter and what is asked for',
      (tester) async {
        await _open(tester, 'doctor@el3yada.dev', size: _desktop);
        await _go(tester, '/doctor/dashboard');

        await tester.tap(find.widgetWithText(ChoiceChip, 'Consultation'));
        await settle(tester);

        expect(
          appContainer(tester).read(analyticsFilterProvider).type,
          SessionType.consultation,
        );
        // Only consultations remain, so the type split has no examinations.
        final dashboard = await appContainer(
          tester,
        ).read(dashboardProvider.future);
        expect(dashboard.typeSplit!.examinations, 0);
      },
    );

    testWidgets('without revenueView no money is shown, hidden and not zero', (
      tester,
    ) async {
      await _open(
        tester,
        'doctor@el3yada.dev',
        size: _desktop,
        analytics: FakeAnalyticsRepository(revenue: false, billing: false),
      );
      await _go(tester, '/doctor/dashboard');

      expect(find.text('Clinic revenue'), findsNothing);
      expect(find.text('Net income'), findsNothing);
      expect(find.text('Revenue over time'), findsNothing);
      expect(find.text('Visits'), findsWidgets);
    });

    testWidgets('D35 lists the months, and a month opens its days', (
      tester,
    ) async {
      await _open(tester, 'doctor@el3yada.dev', size: _phone);
      await _go(tester, '/doctor/revenue');

      expect(find.text('Revenue'), findsWidgets);
      expect(find.text('By month'), findsOneWidget);
      expect(find.text('Totals'), findsWidgets);

      final month = ClinicMonth.thisMonthLabel(tester);
      await tester.tap(find.text(month).first);
      await settle(tester);
      expect(
        find.text('Day by day. Tap a day for its sessions.'),
        findsOneWidget,
      );
    });
  });

  group('AD1, AD4–AD10: the admin', () {
    testWidgets(
      'AD1 shows the platform tiles, the charts and the action lists',
      (tester) async {
        await _open(tester, 'admin@el3yada.dev', size: _desktop);
        await _go(tester, '/admin/dashboard');

        expect(find.text('Dashboard'), findsWidgets);
        expect(find.text('Payments to review'), findsWidgets);
        expect(find.text('Overdue doctors'), findsOneWidget);
        expect(
          find.text('Invoiced and collected, last 12 months'),
          findsOneWidget,
        );
        expect(
          find.text('Latest sign-ups', skipOffstage: false),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'AD7 and AD8: a payment is reviewed and approved, and leaves the queue',
      (tester) async {
        final admin = FakeAdminBillingRepository();
        await _open(tester, 'admin@el3yada.dev', size: _desktop, admin: admin);
        await _go(tester, '/admin/payments');

        expect(find.text('2 waiting, oldest first'), findsOneWidget);
        // The second payment's amount differs from its invoice.
        expect(find.text('Amount differs'), findsOneWidget);

        await tester.tap(find.text('Dr Ahmed Ali').first);
        await settle(tester);
        expect(find.text('Review payment'), findsOneWidget);
        await tester.tap(find.widgetWithText(FilledButton, 'Approve'));
        await settle(tester);
        await tester.tap(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.widgetWithText(FilledButton, 'Approve'),
          ),
        );
        await settle(tester);

        expect(find.text('1 waiting, oldest first'), findsOneWidget);
        final left = await admin.payments(status: PaymentStatus.pendingReview);
        expect(left.items.map((p) => p.paymentId), ['p2']);
      },
    );

    testWidgets('AD8: a rejection needs a reason', (tester) async {
      final admin = FakeAdminBillingRepository();
      await _open(tester, 'admin@el3yada.dev', size: _desktop, admin: admin);
      await _go(tester, '/admin/payments/p2');

      await tester.tap(find.widgetWithText(OutlinedButton, 'Reject'));
      await settle(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, 'Reject'),
        ),
      );
      await tester.pump();
      expect(find.text('Write at least 3 characters'), findsOneWidget);

      await tester.tap(find.text('Screenshot unclear'));
      await tester.pump();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, 'Reject'),
        ),
      );
      await settle(tester);

      final review = await admin.payment('p2');
      expect(review.payment.status, PaymentStatus.rejected);
      expect(review.payment.rejectionReason, 'Screenshot unclear');
    });

    testWidgets(
      'AD9 filters by status and AD10 waives an overdue invoice with a reason',
      (tester) async {
        final admin = FakeAdminBillingRepository();
        await _open(tester, 'admin@el3yada.dev', size: _desktop, admin: admin);
        await _go(tester, '/admin/invoices');

        expect(find.text('Invoices'), findsWidgets);
        await tester.tap(find.widgetWithText(ChoiceChip, 'Overdue'));
        await settle(tester);
        expect(find.text('Dr Mona Hassan'), findsOneWidget);
        expect(find.text('Dr Ahmed Ali'), findsNothing);

        await tester.tap(find.text('Dr Mona Hassan'));
        await settle(tester);
        await tester.tap(find.widgetWithText(OutlinedButton, 'Waive'));
        await settle(tester);
        await tester.enterText(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(TextField),
          ),
          'Special circumstances',
        );
        await tester.tap(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.widgetWithText(FilledButton, 'Waive'),
          ),
        );
        await settle(tester);

        expect(
          (await admin.invoice('i2')).invoice.status,
          InvoiceStatus.waived,
        );
        expect(find.text('Waived'), findsWidgets);
      },
    );

    testWidgets(
      'AD4 and AD5: search the doctors, open one, and suspend them with a reason',
      (tester) async {
        final admin = FakeAdminBillingRepository();
        await _open(tester, 'admin@el3yada.dev', size: _desktop, admin: admin);
        await _go(tester, '/admin/doctors');

        expect(find.text('Dr Karim Samir'), findsOneWidget);
        await tester.enterText(find.byType(TextField).first, 'karim');
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();
        expect(find.text('Dr Ahmed Ali'), findsNothing);

        await tester.tap(find.text('Dr Karim Samir'));
        await settle(tester);
        expect(find.text('Profile'), findsWidgets);
        await tester.tap(find.widgetWithText(FilledButton, 'Suspend'));
        await settle(tester);
        await tester.enterText(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(TextField),
          ),
          'Complaint from a patient',
        );
        await tester.tap(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.widgetWithText(FilledButton, 'Suspend'),
          ),
        );
        await settle(tester);

        final doctors = await admin.doctors(
          const DoctorFilter(search: 'karim'),
        );
        expect(doctors.items.single.status, 'suspended');
      },
    );

    testWidgets('AD7 in Arabic on a phone', (tester) async {
      await _open(
        tester,
        'admin@el3yada.dev',
        prefs: const {'settings.locale': 'ar'},
      );
      await _go(tester, '/admin/payments');

      expect(find.text('مدفوعات للمراجعة'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });
}

/// The label D35 prints for this month's row.
abstract final class ClinicMonth {
  static String thisMonthLabel(WidgetTester tester) {
    final now = DateTime.now().toUtc().add(const Duration(hours: 2));
    const names = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${names[now.month - 1]} ${now.year}';
  }
}
