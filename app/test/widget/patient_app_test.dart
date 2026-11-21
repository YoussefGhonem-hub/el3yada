import 'package:el3yada/app/app.dart';
import 'package:el3yada/features/patient/application/patient_providers.dart';
import 'package:el3yada/features/patient/data/fake_patient_repository.dart';
import 'package:el3yada/features/patient/data/patient_repository.dart';
import 'package:el3yada/features/patient/presentation/medical_file_screen.dart';
import '../support/app_flow.dart' show settle;
import '../support/app_overrides.dart';
import 'package:el3yada/core/widgets/navigation/app_bottom_bar.dart';
import 'package:el3yada/core/widgets/navigation/nav_rail.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Signs in as the demo patient on a phone and accepts the terms (A9 / P14).
Future<void> pumpPatientApp(
  WidgetTester tester, {
  String locale = 'en',
  String theme = 'light',
  Size size = const Size(400, 860),
  bool acceptTerms = true,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...await appOverrides(
          prefs: {'settings.locale': locale, 'settings.themeMode': theme},
        ),
        patientRepositoryProvider.overrideWithValue(
          FakePatientRepository(delay: Duration.zero),
        ),
      ],
      child: const El3yadaApp(),
    ),
  );
  await settle(tester);

  await tester.enterText(find.byType(TextFormField).at(0), '01000000002');
  await tester.enterText(find.byType(TextFormField).at(1), 'dev');
  await tester.tap(find.byType(FilledButton).first);
  await tester.pumpAndSettle();

  if (acceptTerms) {
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    await tester.tap(
      find.widgetWithText(FilledButton, locale == 'ar' ? 'متابعة' : 'Continue'),
    );
    await tester.pumpAndSettle();
  }
}

/// Lets the batched "mark seen" call run, so no timer is left pending.
Future<void> settleSeen(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('first login asks to accept the terms before the home screen', (
    tester,
  ) async {
    await pumpPatientApp(tester, acceptTerms: false);
    expect(find.text('Before you start'), findsOneWidget);
    final continueButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Continue'),
    );
    expect(continueButton.onPressed, isNull);
  });

  testWidgets('home shows the cards and the doctor selector', (tester) async {
    await pumpPatientApp(tester);

    expect(find.text('Hello, محمد'), findsOneWidget);
    expect(find.text('Latest visit'), findsOneWidget);
    expect(find.text('Latest prescription'), findsOneWidget);
    expect(find.text('Next follow-up'), findsOneWidget);
    expect(find.byType(ChoiceChip), findsNWidgets(3)); // All, Dr A, Dr B
    expect(find.byType(AppBottomBar), findsOneWidget);

    // Selecting a doctor limits the cards to that doctor.
    await tester.tap(find.widgetWithText(ChoiceChip, 'Dr. Mona Hassan'));
    await tester.pumpAndSettle();
    expect(find.text('Latest prescription'), findsNothing);
  });

  testWidgets('visits list opens the visit details and clears the badge', (
    tester,
  ) async {
    await pumpPatientApp(tester);
    await tester.tap(find.byTooltip('Medical file'));
    await tester.pumpAndSettle();

    expect(find.text('Dr. Ahmed Samy · Maadi branch'), findsOneWidget);
    expect(find.text('Dr. Mona Hassan · Zamalek clinic'), findsOneWidget);
    expect(find.text('New'), findsOneWidget);

    await tester.tap(find.text('Dr. Ahmed Samy · Maadi branch'));
    await tester.pumpAndSettle();
    expect(find.text('Visit details'), findsOneWidget);
    expect(find.text('ارتفاع ضغط الدم الأولي'), findsWidgets);
    expect(find.text('150/95'), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dr. Mona Hassan · Zamalek clinic'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BackButton));
    await settleSeen(tester);
    expect(find.text('New'), findsNothing);
  });

  testWidgets(
    'a cancelled prescription is struck through and links to its new copy',
    (tester) async {
      await pumpPatientApp(tester);
      await tester.tap(find.byTooltip('Medical file'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Prescriptions'));
      await tester.pumpAndSettle();

      expect(find.text('Cancelled'), findsOneWidget);
      await tester.tap(find.text('Cancelled'));
      await tester.pumpAndSettle();

      expect(find.text('This prescription was cancelled'), findsOneWidget);
      expect(find.text('Reason: تعديل الجرعة'), findsOneWidget);
      await tester.tap(find.text('Open the new copy'));
      await tester.pumpAndSettle();

      expect(
        find.text('Concor 5 mg 5 mg'),
        findsNothing,
      ); // strength already in the name
      expect(find.text('Concor 5 mg'), findsOneWidget);
      expect(
        find.text('1 tablet · 1x1 · After food · Continuous'),
        findsOneWidget,
      );
      expect(find.text('View PDF'), findsOneWidget);
      await settleSeen(tester);
    },
  );

  testWidgets('visits filter by branch, and a doctor change drops a branch it lacks (P4)', (
    tester,
  ) async {
    await pumpPatientApp(tester);
    await tester.tap(find.byTooltip('Medical file'));
    await tester.pumpAndSettle();

    // All doctors: the branches with visits, most visited first.
    expect(find.widgetWithText(ChoiceChip, 'All branches'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Maadi branch'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Zamalek clinic'));
    await tester.pumpAndSettle();
    expect(find.text('Dr. Mona Hassan · Zamalek clinic'), findsOneWidget);
    expect(find.text('Dr. Ahmed Samy · Maadi branch'), findsNothing);

    // Dr Ahmed has one branch: no filter row, and Zamalek no longer filters.
    await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'Dr. Ahmed Samy'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Dr. Ahmed Samy'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ChoiceChip, 'All branches'), findsNothing);
    expect(find.text('Dr. Ahmed Samy · Maadi branch'), findsOneWidget);
  });

  testWidgets('files filter by document date and the tab counts follow (P8)', (
    tester,
  ) async {
    await pumpPatientApp(tester);
    await tester.tap(find.byTooltip('Medical file'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Files'));
    await tester.pumpAndSettle();

    // The chip opens the range picker.
    await tester.tap(find.widgetWithText(InputChip, 'Any date'));
    await tester.pumpAndSettle();
    expect(find.text('Filter by date'), findsWidgets);
    await tester.tap(find.byTooltip('Close').evaluate().isNotEmpty ? find.byTooltip('Close') : find.text('Cancel'));
    await tester.pumpAndSettle();

    // The last five days: the report from yesterday, not the lab test from 9 days ago.
    final container = ProviderScope.containerOf(tester.element(find.byType(FilesTab)));
    final today = DateUtils.dateOnly(DateTime.now());
    container.read(fileDateRangeProvider.notifier).set((from: today.subtract(const Duration(days: 5)), to: today));
    await tester.pumpAndSettle();
    expect(find.text('Lab tests (0)'), findsOneWidget);
    expect(find.text('Other (1)'), findsOneWidget);
    expect(find.text('No files in these dates.'), findsOneWidget);

    await tester.tap(find.byTooltip('Clear dates'));
    await tester.pumpAndSettle();
    expect(find.text('Lab tests (1)'), findsOneWidget);
    expect(find.widgetWithText(InputChip, 'Any date'), findsOneWidget);
  });

  testWidgets('files tab shows category counts', (tester) async {
    await pumpPatientApp(tester);
    await tester.tap(find.byTooltip('Medical file'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Files'));
    await tester.pumpAndSettle();

    expect(find.text('Lab tests (1)'), findsOneWidget);
    expect(find.text('Other (1)'), findsOneWidget);
    expect(find.text('Prescriptions (0)'), findsOneWidget);
  });

  testWidgets('account: request deletion, then it shows as pending', (
    tester,
  ) async {
    await pumpPatientApp(tester, size: const Size(400, 1400));
    await tester.tap(find.byTooltip('Account'));
    await tester.pumpAndSettle();

    expect(find.text('محمد إبراهيم'), findsOneWidget);
    await tester.tap(find.text('Request account deletion'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'لم أعد أحتاجه');
    await tester.tap(find.text('Send request'));
    await tester.pumpAndSettle();

    expect(find.text('Deletion request under review'), findsOneWidget);
  });

  testWidgets(
    'doctor info shows branches, a closed branch and the price fallback',
    (tester) async {
      await pumpPatientApp(tester, size: const Size(400, 2400));
      await tester.tap(find.text('My doctors'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dr. Ahmed Samy'));
      await tester.pumpAndSettle();

      expect(find.text('Maadi branch'), findsOneWidget);
      expect(find.text('350 EGP'), findsOneWidget);
      expect(find.text('150 EGP'), findsOneWidget);
      expect(find.textContaining('Temporarily closed'), findsOneWidget);
    },
  );

  testWidgets('Arabic and dark: home renders right to left', (tester) async {
    await pumpPatientApp(tester, locale: 'ar', theme: 'dark');

    expect(find.text('أهلاً، محمد'), findsOneWidget);
    expect(find.text('آخر زيارة'), findsOneWidget);
    final direction = Directionality.of(tester.element(find.text('آخر زيارة')));
    expect(direction, TextDirection.rtl);
    final brightness = Theme.of(
      tester.element(find.text('آخر زيارة')),
    ).brightness;
    expect(brightness, Brightness.dark);
  });

  testWidgets('medical profile on a tablet shows allergies', (tester) async {
    await pumpPatientApp(tester, size: const Size(900, 1200));
    expect(find.byType(AppNavRail), findsOneWidget);
    await tester.tap(find.text('Medical profile'));
    await tester.pumpAndSettle();

    expect(find.text('Allergies'), findsOneWidget);
    expect(find.text('البنسلين'), findsOneWidget);
    expect(
      find.text('To update this information, contact your doctor.'),
      findsOneWidget,
    );
  });
}
