import 'dart:io';
import 'dart:ui' as ui;

import 'package:el3yada/app/app.dart';
import 'package:el3yada/core/platform/app_platform.dart';
import 'package:el3yada/core/theme/app_theme.dart';
import 'package:el3yada/features/auth/data/auth_repository.dart';
import 'package:el3yada/features/auth/domain/auth_session.dart';
import 'package:el3yada/features/auth/domain/user_role.dart';
import 'package:el3yada/features/analytics/data/analytics_repository.dart';
import 'package:el3yada/features/analytics/data/fake_analytics_repository.dart';
import 'package:el3yada/features/analytics/domain/analytics_models.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../support/admin_support.dart';
import '../support/app_overrides.dart';
import '../support/clinic_admin_support.dart';
import '../support/clinic_records_support.dart';
import '../support/rx_support.dart';
import 'capture.dart' show loadRealFonts, screenshotsEnabled;

/// App Store screenshots at the sizes App Store Connect asks for, in Arabic,
/// light, with the demo data, numbered in upload order and written to
/// `build/store/<device>/`:
///
/// - iPhone 6.3" (Dynamic Island, medium display): 1206 × 2622 px, portrait.
/// - iPad 13": 2752 × 2064 px, landscape (the side-menu layout fills it;
///   portrait leaves half of most screens empty).
///
/// ```
/// $env:EL3YADA_SCREENSHOTS=1; flutter test test/screenshots/store_screenshots_test.dart
/// ```
void main() {
  setUpAll(() async {
    if (!screenshotsEnabled) return;
    await loadRealFonts();
    await _loadStatusBarFont();
    // Real-sounding names for the two demo accounts (the tests use the
    // placeholder ones). Ahmed Samy is the patient's doctor in the patient
    // demo data, Mohamed Ibrahim that patient.
    FakeAuthRepository.accounts['doctor@el3yada.dev'] =
        const FakeAccount(UserRole.doctor, 'د. أحمد سامي', doctorStatus: DoctorStatus.active);
    FakeAuthRepository.accounts['+201000000002'] = const FakeAccount(UserRole.patient, 'محمد إبراهيم');
  });

  for (final device in StoreDevice.all) {
    Future<void> launch(WidgetTester tester, {List<Override> extra = const []}) async {
      tester.view.physicalSize = device.logical * device.ratio;
      tester.view.devicePixelRatio = device.ratio;
      // The side-menu layout (iPad) has no SafeArea yet, so there the app is
      // placed under the status bar, as SafeArea will place it.
      final insets = FakeViewPadding(
        top: device.tablet ? 0 : device.top * device.ratio,
        bottom: device.bottom * device.ratio,
      );
      tester.view.padding = insets;
      tester.view.viewPadding = insets;
      addTearDown(tester.view.reset);
      // Real shadows: the test binding draws them as hard edges otherwise.
      debugDisableShadows = false;
      await tester.pumpWidget(
        ProviderScope(
          overrides: await appOverrides(
            prefs: {'settings.locale': 'ar', 'settings.themeMode': 'light'},
            platform: AppPlatform.mobile,
            extra: extra,
          ),
          child: RepaintBoundary(
            key: _shotKey,
            child: Stack(
              textDirection: TextDirection.rtl,
              children: [
                Positioned.fill(child: ColoredBox(color: AppTheme.light().scaffoldBackgroundColor)),
                Positioned.fill(top: device.tablet ? device.top : 0, child: const El3yadaApp()),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: device.top,
                  child: IgnorePointer(child: _StatusBar(device: device)),
                ),
              ],
            ),
          ),
        ),
      );
      await _settle(tester);
    }

    Future<void> signIn(WidgetTester tester, String account) async {
      await tester.enterText(find.byType(TextFormField).at(0), account);
      await tester.enterText(find.byType(TextFormField).at(1), 'dev');
      await tester.tap(find.byType(FilledButton).first);
      await _settle(tester);
    }

    Future<void> open(WidgetTester tester, String path) async {
      goTo(tester, path);
      await _settle(tester);
    }

    /// Writes `NN_name.png` when [name] is in the device's set.
    Future<void> shot(WidgetTester tester, String name) async {
      final index = device.shots.indexOf(name);
      if (index < 0) return;
      await _capture(tester, device, '${(index + 1).toString().padLeft(2, '0')}_$name');
    }

    /// Scrolls [finder] into view, clear of the phone's floating bar.
    Future<void> reveal(WidgetTester tester, Finder finder) async {
      await tester.scrollUntilVisible(finder, 200, scrollable: find.byType(Scrollable).first);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -160));
      await _settle(tester);
    }

    testWidgets('doctor (${device.name})', skip: !screenshotsEnabled, (tester) async {
      await launch(
        tester,
        extra: [
          fakeRecordsOverride(),
          fakeClinicAdminOverride(),
          ...rxOverrides(printer: RecordingPrinter(), search: FakeCatalogSearch()),
          analyticsRepositoryProvider.overrideWithValue(_PaidUpAnalytics()),
        ],
      );
      await signIn(tester, 'doctor@el3yada.dev');
      // The live board with a current turn: the next patient goes in and
      // another one arrives.
      await tester.tap(find.text('دخول للطبيب').first);
      await _settle(tester);
      await tester.tap(find.text('وصل').first);
      await _settle(tester);
      await shot(tester, 'live');
      for (final path in ['patients', 'dashboard', 'appointments', 'revenue']) {
        await open(tester, '/doctor/$path');
        await shot(tester, path);
      }
      final mona = recordsOf(tester).patientIdByName(SeedPatients.mona);
      await open(tester, '/doctor/patients/$mona');
      await shot(tester, 'profile');
      final session = recordsOf(tester).sessionIdsOf(mona).first;
      await open(tester, '/doctor/patients/$mona/sessions/$session');
      await shot(tester, 'session');

      // A new prescription with a medicine from the catalog.
      await reveal(tester, find.text('روشتة علاج جديدة'));
      await tester.tap(find.text('روشتة علاج جديدة'));
      await _settle(tester);
      await tester.tap(find.text('إضافة دواء'));
      await _settle(tester);
      await tester.enterText(find.byType(TextField).last, 'ator');
      await _settle(tester);
      await tester.tap(find.text('Atorstat 20'));
      await _settle(tester);
      await tester.tap(find.text('إضافة').last);
      await _settle(tester);
      await shot(tester, 'rx');
      debugDisableShadows = true;
    });

    testWidgets('patient (${device.name})', skip: !screenshotsEnabled, (tester) async {
      await launch(tester);
      await signIn(tester, '01000000002');
      // First launch: the terms, once.
      if (find.byType(Checkbox).evaluate().isNotEmpty) {
        await tester.tap(find.byType(Checkbox).first);
        await _settle(tester);
        await tester.tap(find.byType(FilledButton).last);
        await _settle(tester);
      }
      await shot(tester, 'patient_home');
      await open(tester, '/patient/prescriptions/rx-med');
      await shot(tester, 'patient_rx');
      debugDisableShadows = true;
    });
  }
}

/// A device App Store Connect takes screenshots for: its size in points,
/// its pixel ratio and the safe-area insets the app lays out around.
class StoreDevice {
  const StoreDevice(
    this.name,
    this.logical,
    this.ratio, {
    required this.top,
    required this.bottom,
    required this.tablet,
    required this.shots,
  });

  static const iphone = StoreDevice(
    'iphone_6.3',
    Size(402, 874),
    3,
    top: 62,
    bottom: 34,
    tablet: false,
    shots: [
      'live',
      'profile',
      'rx',
      'patients',
      'session',
      'appointments',
      'dashboard',
      'revenue',
      'patient_home',
      'patient_rx',
    ],
  );
  static const ipad = StoreDevice(
    'ipad_13',
    Size(1376, 1032),
    2,
    top: 24,
    bottom: 20,
    tablet: true,
    // No patients table: at this width its name column is squeezed.
    shots: ['profile', 'dashboard', 'session', 'revenue', 'rx', 'live', 'patient_home'],
  );
  static const all = [iphone, ipad];

  /// The screens to keep, in upload order (App Store Connect takes up to
  /// ten; the first three show in search results).
  final List<String> shots;

  final String name;
  final Size logical;
  final double ratio;
  final double top;
  final double bottom;
  final bool tablet;
}

final _shotKey = GlobalKey();

/// The demo dashboard without its unpaid invoice card (the clinic's bill to
/// el3yada), which has no place in a store screenshot.
class _PaidUpAnalytics extends FakeAnalyticsRepository {
  @override
  Future<Dashboard> dashboard(AnalyticsFilter filter) async {
    final d = await super.dashboard(filter);
    return Dashboard(
      period: d.period,
      access: d.access,
      tiles: d.tiles,
      revenueSeries: d.revenueSeries,
      visitsSeries: d.visitsSeries,
      patientsPerWeek: d.patientsPerWeek,
      months: d.months,
      heatmap: d.heatmap,
      newVsReturning: d.newVsReturning,
      typeSplit: d.typeSplit,
      branches: d.branches,
      funnel: d.funnel,
      sources: d.sources,
      notSeen: d.notSeen,
      waitingTimes: d.waitingTimes,
      insights: d.insights,
    );
  }
}

/// Pumps fixed frames instead of waiting to settle: the live board and the
/// login mark keep animating.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _capture(WidgetTester tester, StoreDevice device, String name) async {
  final boundary = _shotKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: device.ratio);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    File('build/store/${device.name}/$name.png')
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync(data!.buffer.asUint8List());
  });
}

const _statusFont = 'StoreStatusBar';

/// iOS draws the status bar in SF Pro, which can't be bundled; Segoe UI
/// Semibold (Windows) is close. Without it the bar falls back to Alexandria.
Future<void> _loadStatusBarFont() async {
  final file = File('${Platform.environment['WINDIR'] ?? r'C:\Windows'}/Fonts/seguisb.ttf');
  final loader = FontLoader(_statusFont);
  loader.addFont(
    file.existsSync()
        ? Future.value(ByteData.sublistView(file.readAsBytesSync()))
        : rootBundle.load('assets/fonts/Alexandria-SemiBold.ttf'),
  );
  await loader.load();
}

/// The iOS status bar (time, signal, Wi-Fi, battery), mirrored for Arabic
/// like iOS does: the time on the right.
class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.device});

  final StoreDevice device;

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF000000);
    final phone = !device.tablet;
    final time = Text(
      '9:41',
      textDirection: TextDirection.ltr,
      style: TextStyle(
        fontFamily: _statusFont,
        fontSize: phone ? 17 : 14,
        height: 1,
        color: ink,
        letterSpacing: phone ? -0.2 : 0,
      ),
    );
    final icons = Row(
      mainAxisSize: MainAxisSize.min,
      textDirection: TextDirection.ltr,
      children: [
        if (phone) ...[
          const CustomPaint(size: Size(18, 12), painter: _SignalPainter(ink)),
          const SizedBox(width: 6),
        ],
        CustomPaint(size: const Size(16, 12), painter: _WifiPainter(ink)),
        SizedBox(width: phone ? 6 : 7),
        if (!phone) ...[
          const Text(
            '100%',
            textDirection: TextDirection.ltr,
            style: TextStyle(fontFamily: _statusFont, fontSize: 13, height: 1, color: ink),
          ),
          const SizedBox(width: 4),
        ],
        CustomPaint(size: const Size(27, 13), painter: _BatteryPainter(ink)),
      ],
    );
    return Padding(
      padding: phone ? const EdgeInsets.fromLTRB(36, 22, 40, 0) : const EdgeInsets.fromLTRB(22, 7, 22, 0),
      child: Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          height: phone ? 20 : 16,
          child: Row(
            // RTL: the time is on the right, the icons on the left.
            textDirection: TextDirection.rtl,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Padding(padding: EdgeInsets.only(right: phone ? 14 : 0), child: time),
              icons,
            ],
          ),
        ),
      ),
    );
  }
}

class _SignalPainter extends CustomPainter {
  const _SignalPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    const bar = 3.0;
    const gap = 1.8;
    for (var i = 0; i < 4; i++) {
      final h = size.height * (0.4 + 0.2 * i);
      final x = i * (bar + gap);
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(x, size.height - h, bar, h), const Radius.circular(1)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_SignalPainter old) => old.color != color;
}

class _WifiPainter extends CustomPainter {
  const _WifiPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.1
      ..strokeCap = StrokeCap.round;
    final center = Offset(size.width / 2, size.height - 0.5);
    const sweep = 1.55;
    for (final r in [size.height * 0.95, size.height * 0.62]) {
      canvas.drawArc(Rect.fromCircle(center: center, radius: r - 1), -1.5708 - sweep / 2, sweep, false, paint);
    }
    // The dot: a filled wedge.
    final wedge = Path()
      ..moveTo(center.dx, center.dy)
      ..arcTo(Rect.fromCircle(center: center, radius: size.height * 0.32), -1.5708 - sweep / 2, sweep, false)
      ..close();
    canvas.drawPath(wedge, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_WifiPainter old) => old.color != color;
}

class _BatteryPainter extends CustomPainter {
  const _BatteryPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final body = Rect.fromLTWH(0, 0, size.width - 2.5, size.height);
    canvas.drawRRect(
      RRect.fromRectAndRadius(body.deflate(0.5), const Radius.circular(4)),
      Paint()
        ..color = color.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    canvas.drawRRect(RRect.fromRectAndRadius(body.deflate(2), const Radius.circular(2.5)), Paint()..color = color);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width - 1.5, size.height * 0.33, 1.5, size.height * 0.34),
        const Radius.circular(1),
      ),
      Paint()..color = color.withValues(alpha: 0.4),
    );
  }

  @override
  bool shouldRepaint(_BatteryPainter old) => old.color != color;
}
