import 'package:dio/dio.dart';
import 'package:el3yada/core/network/api_error_text.dart';
import 'package:el3yada/core/network/api_exception.dart';
import 'package:el3yada/features/clinic/domain/clinic_permissions.dart';
import 'package:el3yada/features/clinic_admin/data/clinic_admin_repository.dart';
import 'package:el3yada/features/clinic_admin/domain/account_models.dart';
import 'package:el3yada/features/clinic_admin/domain/activity_models.dart';
import 'package:el3yada/features/clinic_admin/domain/assistant_models.dart';
import 'package:el3yada/features/clinic_admin/domain/branch_models.dart';
import 'package:el3yada/features/clinic_admin/domain/price_models.dart';
import 'package:el3yada/features/clinic_admin/domain/weekly_hours.dart';
import 'package:el3yada/features/clinic_admin/presentation/activity/activity_text.dart';
import 'package:el3yada/features/clinic_admin/presentation/assistants/assistant_editor.dart';
import 'package:el3yada/features/clinic_admin/presentation/branches/branch_drafts.dart';
import 'package:el3yada/l10n/gen/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// The clinic admin data layer (backend/docs/api-phase-2-clinic.md): JSON
/// from the contract's examples, the app's own checks (hours, prices), the
/// D26 permission logic, the API client's requests and refusals, and texts.
void main() {
  group('models read the contract', () {
    test('D28 branch list', () {
      final list = BranchList.fromJson({
        'items': [
          {
            'id': 'b1',
            'nameAr': 'فرع المعادي',
            'nameEn': null,
            'governorate': 'القاهرة',
            'city': 'المعادي',
            'area': null,
            'status': 'active',
            'closedMessage': null,
            'reopenDate': null,
            'isDefault': true,
            'assigned': true,
            'todayPeriods': [
              {
                'weekday': 7,
                'startLocal': '10:00',
                'endLocal': '14:00',
                'endsNextDay': false,
                'label': 'صباحي',
                'capacity': 20,
              },
              {
                'weekday': 7,
                'startLocal': '18:00',
                'endLocal': '01:00',
                'endsNextDay': true,
                'label': 'مسائي',
                'capacity': null,
              },
            ],
            'upcomingBookings': 0,
          },
        ],
        'count': 2,
        'limit': 5,
        'canAdd': true,
        'today': '2026-11-15',
        'todayWeekday': 7,
      });
      expect(list.count, 2);
      expect(list.canAdd, isTrue);
      expect(list.today, DateTime(2026, 11, 15));
      final card = list.items.single;
      expect(card.isDefault, isTrue);
      expect(card.name('en'), 'فرع المعادي');
      expect(card.todayPeriods.last.endsNextDay, isTrue);
      expect(card.todayPeriods.last.capacity, isNull);
      expect(card.todayPeriods.first.label, 'صباحي');
    });

    test('D29 branch details', () {
      final branch = BranchDetails.fromJson({
        'id': 'b2',
        'isDefault': false,
        'status': 'temporarilyClosed',
        'closedMessage': 'مغلق للتجديدات',
        'reopenDate': '2026-11-25',
        'assigned': true,
        'info': {
          'nameAr': 'فرع الدقي',
          'nameEn': 'Dokki',
          'description': 'عيادة الأطفال بالدور الثاني',
        },
        'address': {
          'governorate': 'الجيزة',
          'city': 'الدقي',
          'area': 'ميدان المساحة',
          'details': '12 شارع التحرير، الدور التاني، شقة 4',
          'landmark': 'بجوار البنك الأهلي',
          'mapUrl': 'https://maps.app.goo.gl/AbCd1234XyZ',
        },
        'contact': {
          'phones': [
            {
              'number': '+20233351234',
              'label': 'landline',
              'isWhatsapp': false,
            },
            {'number': '+201012345678', 'label': 'mobile', 'isWhatsapp': true},
          ],
          'email': 'dokki@clinic.example',
        },
        'workingHours': {
          'bookingMode': 'queue',
          'defaultCapacity': 30,
          'periods': [
            {
              'weekday': 6,
              'startLocal': '10:00',
              'endLocal': '14:00',
              'endsNextDay': false,
              'label': 'صباحي',
              'capacity': 25,
            },
          ],
        },
        'clinicInfo': {
          'prices': {
            'examinationPricePiasters': 40000,
            'consultationPricePiasters': null,
            'usesDoctorPrices': false,
            'effectiveExaminationPricePiasters': 40000,
            'effectiveConsultationPricePiasters': 15000,
          },
          'paymentMethods': ['cash', 'instapay'],
          'amenities': ['elevator'],
        },
        'createdAt': '2026-11-15T10:04:00.000Z',
        'updatedAt': '2026-11-15T10:04:00.000Z',
      });
      expect(branch.temporarilyClosed, isTrue);
      expect(branch.reopenDate, DateTime(2026, 11, 25));
      expect(branch.name('en'), 'Dokki');
      expect(branch.address.details, '12 شارع التحرير، الدور التاني، شقة 4');
      expect(branch.address.mapUrl, 'https://maps.app.goo.gl/AbCd1234XyZ');
      expect(branch.address.toJson().keys, [
        'governorate',
        'city',
        'area',
        'details',
        'landmark',
        'mapUrl',
      ]);
      expect(branch.contact.phones.last.isWhatsapp, isTrue);
      expect(branch.workingHours.queueMode, isTrue);
      expect(branch.clinicInfo.prices.usesDoctorPrices, isFalse);
      expect(
        branch.clinicInfo.prices.effectiveConsultationPricePiasters,
        15000,
      );
      expect(branch.clinicInfo.paymentMethods, ['cash', 'instapay']);
    });

    test('D37 prices and their history', () {
      final prices = PricesOverview.fromJson({
        'doctor': {
          'examinationPricePiasters': 30000,
          'consultationPricePiasters': 15000,
        },
        'branches': [
          {
            'branchId': 'b1',
            'nameAr': 'فرع المعادي',
            'nameEn': null,
            'status': 'active',
            'isDefault': true,
            'assigned': false,
            'prices': {
              'examinationPricePiasters': null,
              'consultationPricePiasters': null,
              'usesDoctorPrices': true,
              'effectiveExaminationPricePiasters': 30000,
              'effectiveConsultationPricePiasters': 15000,
            },
          },
        ],
        'history': {
          'items': [
            {
              'id': 'h1',
              'changedAt': '2026-11-15T10:04:00.000Z',
              'changedBy': {
                'userId': 'u1',
                'name': 'منى سمير',
                'role': 'assistant',
              },
              'branch': {'id': 'b2', 'nameAr': 'فرع الدقي', 'nameEn': 'Dokki'},
              'before': {
                'examinationPricePiasters': null,
                'consultationPricePiasters': null,
              },
              'after': {
                'examinationPricePiasters': 40000,
                'consultationPricePiasters': null,
              },
            },
            {
              'id': 'h2',
              'changedAt': '2026-11-14T09:00:00.000Z',
              'changedBy': {
                'userId': 'u2',
                'name': 'أحمد علي',
                'role': 'doctor',
              },
              'branch': null,
              'before': {
                'examinationPricePiasters': 25000,
                'consultationPricePiasters': 15000,
              },
              'after': {
                'examinationPricePiasters': 30000,
                'consultationPricePiasters': 15000,
              },
            },
          ],
          'page': 1,
          'pageSize': 25,
          'totalCount': 2,
          'totalPages': 1,
        },
      });
      expect(prices.doctor.examinationPricePiasters, 30000);
      expect(prices.branches.single.assigned, isFalse);
      expect(prices.branches.single.prices.usesDoctorPrices, isTrue);
      expect(prices.history.items.first.branchName('en'), 'Dokki');
      expect(prices.history.items.first.before.isEmpty, isTrue);
      expect(prices.history.items.last.branchId, isNull);
      expect(prices.history.totalCount, 2);
    });

    test('D22 profile and the notification preferences', () {
      final profile = DoctorProfile.fromJson({
        'doctorId': 'd1',
        'fullName': 'أحمد علي',
        'fullNameEn': 'Ahmed Ali',
        'title': 'استشاري',
        'titleEn': 'Consultant',
        'degreesAr': 'دكتوراه الباطنة',
        'degreesEn': null,
        'specialty': {
          'id': 's1',
          'nameAr': 'باطنة',
          'nameEn': 'Internal Medicine',
        },
        'specialtyId': 's1',
        'extraSpecialties': [
          {'id': 's2', 'nameAr': 'قلب', 'nameEn': 'Cardiology'},
        ],
        'extraSpecialtyIds': ['s2'],
        'email': 'ahmed@example.com',
        'emailVerified': true,
        'phone': '+201012345678',
        'licenseNumber': '45678',
        'status': 'active',
        'updatedAt': '2026-11-15T10:04:00.000Z',
      });
      expect(profile.specialty!.name('en'), 'Internal Medicine');
      expect(profile.extraSpecialtyIds, ['s2']);
      expect(profile.degreesEn, isNull);

      const defaults = NotificationPrefs();
      expect(
        (
          defaults.chat,
          defaults.reminders,
          defaults.showPreview,
          defaults.bookings,
        ),
        (true, true, false, false),
      );
      final prefs = NotificationPrefs.fromJson({
        'chat': false,
        'reminders': true,
        'showPreview': true,
        'bookings': false,
      });
      expect(prefs.copyWith(bookings: true).toJson(), {
        'chat': false,
        'reminders': true,
        'showPreview': true,
        'bookings': true,
      });
    });

    test('D25 assistants: permissions become the set of keys that are on', () {
      final list = AssistantList.fromJson({
        'items': [
          {
            'userId': 'a1',
            'fullName': 'سارة محمود',
            'phone': '+201012345678',
            'preset': 'reception',
            'status': 'active',
            'allBranches': false,
            'branches': [
              {
                'id': 'b1',
                'nameAr': 'فرع المعادي',
                'nameEn': null,
                'status': 'active',
              },
            ],
            'branchIds': ['b1'],
            'permissions': {
              'patientsManage': true,
              'sessionsDelete': false,
              'appointmentsView': true,
            },
            'mustChangePassword': true,
            'lastActiveAt': null,
            'createdAt': '2026-11-15T10:04:00.000Z',
            'updatedAt': '2026-11-15T10:04:00.000Z',
            'removedAt': null,
          },
        ],
        'count': 2,
        'limit': 5,
        'canAdd': true,
      });
      final assistant = list.items.single;
      expect(assistant.permissions, {'patientsManage', 'appointmentsView'});
      expect(assistant.branches.single.name('ar'), 'فرع المعادي');
      expect(assistant.mustChangePassword, isTrue);
      expect(assistant.isActive, isTrue);
      expect(
        AssistantDraft.of(assistant).permissionMap.length,
        ClinicPermission.all.length,
      );
    });

    test('D27 activity: people and actions come with the page', () {
      final page = ActivityPage.fromJson({
        'items': [
          {
            'id': 812,
            'at': '2026-11-15T10:04:00.000Z',
            'actor': {
              'userId': 'u1',
              'name': 'سارة محمود',
              'role': 'assistant',
            },
            'action': 'patientCreated',
            'targetType': 'patient',
            'targetId': 'p1',
            'patient': {'id': 'p1', 'name': 'منى حسن', 'fileNumber': 17},
            'details': {'fileNumber': 17},
          },
          {
            'id': 811,
            'at': '2026-11-15T09:58:00.000Z',
            'actor': {'role': 'system'},
            'action': 'passwordResetRequested',
            'targetType': 'user',
            'targetId': 'u1',
            'patient': null,
            'details': null,
          },
        ],
        'page': 1,
        'pageSize': 25,
        'totalCount': 2,
        'totalPages': 1,
        'people': [
          {
            'userId': 'd1',
            'name': 'أحمد علي',
            'role': 'doctor',
            'status': null,
          },
          {
            'userId': 'u1',
            'name': 'سارة محمود',
            'role': 'assistant',
            'status': 'active',
          },
        ],
        'actions': ['passwordResetRequested', 'patientCreated'],
      });
      expect(page.page.items.first.patient!.fileNumber, 17);
      expect(page.page.items.last.actor.isSystem, isTrue);
      expect(page.page.items.last.details, isEmpty);
      expect(page.people.last.status, 'active');
      expect(page.actions, hasLength(2));
    });

    test('the activity filter sends Cairo dates', () {
      final filter = const ActivityFilter()
          .withActor('u1', 'سارة')
          .withAction('pricesUpdated')
          .withDates(DateTime(2026, 11, 1), DateTime(2026, 11, 15));
      expect(filter.toQuery(), {
        'actorUserId': 'u1',
        'action': 'pricesUpdated',
        'from': '2026-11-01',
        'to': '2026-11-15',
      });
      expect(const ActivityFilter().isEmpty, isTrue);
    });
  });

  group('working hours (spec section 11)', () {
    BranchPeriod p(
      int day,
      String start,
      String end, {
      bool next = false,
      String? label,
      int? capacity,
    }) => BranchPeriod(
      weekday: day,
      startLocal: start,
      endLocal: end,
      endsNextDay: next,
      label: label,
      capacity: capacity,
    );

    test('a normal week passes, and periods that touch are fine', () {
      expect(
        WeeklyHours.check([
          p(6, '10:00', '14:00'),
          p(6, '14:00', '18:00'),
          p(7, '10:00', '14:00'),
        ]),
        isEmpty,
      );
    });

    test('a period that ends before it starts needs «ends the next day»', () {
      expect(WeeklyHours.check([p(6, '20:00', '01:00')]), [
        const PeriodProblem(0, 'endLocal', 'PERIOD_END_BEFORE_START'),
      ]);
      expect(WeeklyHours.check([p(6, '20:00', '01:00', next: true)]), isEmpty);
    });

    test('a period lasts 15 minutes to 16 hours', () {
      expect(WeeklyHours.check([p(6, '10:00', '10:10')]), [
        const PeriodProblem(0, 'endLocal', 'PERIOD_LENGTH_OUT_OF_RANGE'),
      ]);
      expect(WeeklyHours.check([p(6, '06:00', '23:00')]), [
        const PeriodProblem(0, 'endLocal', 'PERIOD_LENGTH_OUT_OF_RANGE'),
      ]);
      expect(
        WeeklyHours.check([p(6, '10:00', '10:15'), p(7, '06:00', '22:00')]),
        isEmpty,
      );
    });

    test(
      'overlaps are found on the later period, across midnight and from Sunday into Monday',
      () {
        expect(
          WeeklyHours.check([p(6, '10:00', '14:00'), p(6, '13:00', '15:00')]),
          [const PeriodProblem(1, '', 'PERIODS_OVERLAP')],
        );
        // Saturday 20:00–01:00 runs into Sunday 00:30.
        expect(
          WeeklyHours.check([
            p(6, '20:00', '01:00', next: true),
            p(7, '00:30', '03:00'),
          ]),
          [const PeriodProblem(1, '', 'PERIODS_OVERLAP')],
        );
        // Sunday 23:00–02:00 runs into Monday 01:00.
        expect(
          WeeklyHours.check([
            p(1, '01:00', '03:00'),
            p(7, '23:00', '02:00', next: true),
          ]),
          [const PeriodProblem(1, '', 'PERIODS_OVERLAP')],
        );
      },
    );

    test('field problems come first and stop the order checks', () {
      expect(WeeklyHours.check([p(6, '25:00', '14:00'), p(6, '', '10:00')]), [
        const PeriodProblem(0, 'startLocal', 'INVALID_VALUE'),
        const PeriodProblem(1, 'startLocal', 'REQUIRED'),
      ]);
      expect(
        WeeklyHours.check([
          p(6, '10:00', '14:00', label: 'ف' * 31, capacity: 201),
        ]),
        [
          const PeriodProblem(0, 'label', 'TOO_LONG'),
          const PeriodProblem(0, 'capacity', 'OUT_OF_RANGE'),
        ],
      );
    });

    test('at most 10 periods a day', () {
      final day = [
        for (var h = 0; h < 11; h++)
          p(6, WeeklyHours.format(h * 60), WeeklyHours.format(h * 60 + 30)),
      ];
      expect(WeeklyHours.check(day), [
        const PeriodProblem(-1, '', 'INVALID_VALUE'),
      ]);
    });

    test('Arabic-Indic digits are read; the week starts on Saturday', () {
      expect(WeeklyHours.parse('١٠:٣٠'), 630);
      expect(WeeklyHours.format(630), '10:30');
      expect(WeeklyHours.weekOrder.first, DateTime.saturday);
      expect(WeeklyHours.weekOrder.last, DateTime.friday);
    });

    test('copy Saturday to all days', () {
      final week = WeeklyHours.copyDayToAll([
        p(6, '10:00', '14:00', label: 'صباحي'),
        p(1, '18:00', '22:00'),
      ]);
      expect(week, hasLength(7));
      expect(week.map((x) => x.weekday).toList(), WeeklyHours.weekOrder);
      expect(
        week.every((x) => x.startLocal == '10:00' && x.label == 'صباحي'),
        isTrue,
      );
    });
  });

  group('visit prices (EGP with up to 2 decimals → piasters)', () {
    test('amounts', () {
      expect(PriceRules.toPiasters('300'), 30000);
      expect(PriceRules.toPiasters('150.5'), 15050);
      expect(PriceRules.toPiasters('150.05'), 15005);
      expect(PriceRules.toPiasters('٣٠٠'), 30000);
      expect(PriceRules.toPiasters('1,250.75'), 125075);
      expect(PriceRules.toPiasters('0'), 0);
      expect(PriceRules.toPiasters('100000'), 10000000);
      expect(PriceRules.toPiasters('  '), isNull);
    });

    test('refused', () {
      expect(() => PriceRules.toPiasters('1.234'), throwsFormatException);
      expect(() => PriceRules.toPiasters('100000.01'), throwsFormatException);
      expect(() => PriceRules.toPiasters('-5'), throwsFormatException);
      expect(() => PriceRules.toPiasters('abc'), throwsFormatException);
      expect(PriceRules.check('12.5'), isNull);
      expect(PriceRules.check('12.555'), PriceProblem.invalid);
    });

    test('back to what the field shows', () {
      expect(PriceRules.toInput(30000), '300');
      expect(PriceRules.toInput(15050), '150.50');
      expect(PriceRules.toInput(null), '');
    });
  });

  group('D29 address (the same rules as BranchInput.cs)', () {
    test(
      'governorate, city and the detailed address are required; the map link is optional',
      () {
        final draft = AddressDraft();
        addTearDown(draft.dispose);
        expect(draft.check(), {
          'address.governorate': BranchProblem.required,
          'address.city': BranchProblem.required,
          'address.details': BranchProblem.required,
        });

        draft
          ..setGovernorate('الجيزة')
          ..city.text = 'الدقي'
          ..details.text = '  12 شارع التحرير، الدور التاني\nشقة 4  ';
        expect(draft.check(), isEmpty);
        final address = draft.build();
        expect(address.details, '12 شارع التحرير، الدور التاني\nشقة 4');
        expect(address.mapUrl, isNull);
      },
    );

    test(
      'the map link must be Google Maps; a pasted share text keeps only the link',
      () {
        final draft = AddressDraft(
          const BranchAddress(
            governorate: 'الجيزة',
            city: 'الدقي',
            details: 'شارع التحرير',
          ),
        );
        addTearDown(draft.dispose);

        draft.mapUrl.text = 'https://example.com/maps/clinic';
        expect(draft.check(), {'address.mapUrl': BranchProblem.invalidMapLink});
        draft.mapUrl.text = 'https://maps.app.goo.gl/${'x' * 500}';
        expect(draft.check(), {'address.mapUrl': BranchProblem.tooLong});
        draft.details.text = 'ع' * 301;
        expect(draft.check()['address.details'], BranchProblem.tooLong);

        draft
          ..details.text = 'شارع التحرير'
          ..mapUrl.text = 'عيادة الدقي https://maps.app.goo.gl/AbCd1234';
        expect(draft.build().mapUrl, 'https://maps.app.goo.gl/AbCd1234');
        expect(draft.changes, 1);
      },
    );
  });

  group('D26 presets and dependencies', () {
    test('a new assistant starts as Reception', () {
      final form = AssistantForm();
      addTearDown(form.dispose);
      expect(form.preset, AssistantPreset.reception);
      expect(
        form.permissions,
        AssistantPreset.permissions[AssistantPreset.reception],
      );
    });

    test(
      'changing any box makes it Custom, even when it matches another preset again',
      () {
        final form = AssistantForm();
        addTearDown(form.dispose);
        form.toggle(ClinicPermission.chat, true);
        expect(form.preset, AssistantPreset.custom);
        form.toggle(ClinicPermission.chat, false);
        expect(
          form.permissions,
          AssistantPreset.permissions[AssistantPreset.reception],
        );
        expect(form.preset, AssistantPreset.custom);
        form.pickPreset(AssistantPreset.officeManager);
        expect(form.preset, AssistantPreset.officeManager);
        expect(form.permissions, contains(ClinicPermission.pricesManage));
      },
    );

    test('dependencies switch on with a box and off with what they need', () {
      final form = AssistantForm();
      addTearDown(form.dispose);
      form.toggle(ClinicPermission.billingPay, true);
      expect(
        form.permissions,
        containsAll([
          ClinicPermission.billingPay,
          ClinicPermission.billingView,
        ]),
      );
      expect(form.lastDependency?.$1, ClinicPermission.billingPay);
      expect(form.lastDependency?.$2, {ClinicPermission.billingView});
      expect(form.lastDependency?.$3, isTrue);

      form.toggle(ClinicPermission.appointmentsView, false);
      expect(
        form.permissions,
        isNot(contains(ClinicPermission.appointmentsManage)),
      );
      expect(form.lastDependency?.$2, {ClinicPermission.appointmentsManage});
      expect(form.lastDependency?.$3, isFalse);

      form.toggle(ClinicPermission.scheduleManage, true);
      expect(
        form.permissions,
        containsAll([
          ClinicPermission.appointmentsManage,
          ClinicPermission.appointmentsView,
        ]),
      );

      form.toggle(ClinicPermission.patientsManage, false);
      expect(form.lastDependency, isNull);
    });

    test('checks the name, the mobile and the branches before sending', () {
      final form = AssistantForm();
      addTearDown(form.dispose);
      expect(form.check(), {
        'fullName': 'REQUIRED',
        'phone': 'REQUIRED',
        'branchIds': 'REQUIRED',
      });
      form.fullName.text = 'سارة';
      form.phone.text = '0123';
      form.setAllBranches(true);
      expect(form.check(), {
        'fullName': 'INVALID_NAME',
        'phone': 'INVALID_MOBILE',
      });
      form.fullName.text = 'سارة  محمود';
      form.phone.text = '01012345678';
      expect(form.check(), isEmpty);
      expect(form.build().toCreateJson()['fullName'], 'سارة محمود');
      expect(form.build().toCreateJson()['branchIds'], isEmpty);
    });
  });

  group('the API client', () {
    late List<RequestOptions> sent;

    ApiClinicAdminRepository repository(
      Object Function(RequestOptions request) answer,
    ) {
      sent = [];
      final dio = Dio(BaseOptions(baseUrl: 'https://api.test/api'));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            sent.add(options);
            final result = answer(options);
            if (result is DioException) {
              handler.reject(result);
            } else {
              handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: result,
                ),
              );
            }
          },
        ),
      );
      return ApiClinicAdminRepository(dio);
    }

    DioException refusal(
      RequestOptions options,
      int status,
      Map<String, dynamic> body,
    ) => DioException.badResponse(
      statusCode: status,
      requestOptions: options,
      response: Response(
        requestOptions: options,
        statusCode: status,
        data: body,
      ),
    );

    test('BRANCH_HAS_BOOKINGS carries the bookings', () async {
      final api = repository(
        (o) => refusal(o, 409, {
          'status': 409,
          'code': 'BRANCH_HAS_BOOKINGS',
          'totalCount': 3,
          'bookings': [
            {
              'id': 'k1',
              'localDate': '2026-11-17',
              'periodStartLocal': '10:00',
              'startUtc': '2026-11-17T08:00:00.000Z',
              'status': 'confirmed',
              'visitType': 'examination',
              'patientId': null,
              'name': 'ضيف',
              'isGuest': true,
            },
          ],
        }),
      );
      final error = await api
          .setBranchStatus('b1', BranchStatuses.archived)
          .then<Object?>((_) => null, onError: (Object e) => e);
      expect(error, isA<BranchHasBookingsException>());
      final bookings = error! as BranchHasBookingsException;
      expect(bookings.totalCount, 3);
      expect(bookings.bookings.single.isGuest, isTrue);
      expect(bookings.bookings.single.localDate, DateTime(2026, 11, 17));
      // The whole answer too, like any ApiException (the start time isn't in the model).
      expect(bookings.details['totalCount'], 3);
      expect(
        ((bookings.details['bookings']! as List).single as Map)['startUtc'],
        '2026-11-17T08:00:00.000Z',
      );
      expect(sent.single.data, {'branchId': 'b1', 'status': 'archived'});
    });

    test('other refusals keep their code and field errors', () async {
      final api = repository(
        (o) => refusal(o, 400, {
          'status': 400,
          'code': 'VALIDATION_FAILED',
          'errorCodes': {
            'contact.phones[1].number': ['INVALID_PHONE'],
            'address.mapUrl': ['INVALID_MAP_LINK'],
          },
        }),
      );
      final error = await api
          .updateBranch('b1', info: const BranchInfo(nameAr: 'فرع المعادي'))
          .then<Object?>((_) => null, onError: (Object e) => e);
      expect(error, isA<ApiException>());
      expect((error! as ApiException).fieldCodes, {
        'contact.phones[1].number': 'INVALID_PHONE',
        'address.mapUrl': 'INVALID_MAP_LINK',
      });
    });

    test('a closure sends the message and the Cairo date', () async {
      final api = repository((o) => throw StateError('answer not needed'));
      await api
          .setBranchStatus(
            'b1',
            BranchStatuses.temporarilyClosed,
            closedMessage: 'مغلق',
            reopenDate: DateTime(2026, 11, 25),
          )
          .then<void>((_) {}, onError: (_) {});
      expect(sent.single.data, {
        'branchId': 'b1',
        'status': 'temporarilyClosed',
        'closedMessage': 'مغلق',
        'reopenDate': '2026-11-25',
      });
    });

    test(
      'updateAssistant sends only the parts given, and the whole permission map',
      () async {
        final api = repository((o) => throw StateError('answer not needed'));
        await api
            .updateAssistant('a1', permissions: {ClinicPermission.chat})
            .then<void>((_) {}, onError: (_) {});
        final body = sent.single.data as Map<String, dynamic>;
        expect(body.keys, ['assistantId', 'permissions']);
        final permissions = body['permissions'] as Map<String, bool>;
        expect(permissions.length, ClinicPermission.all.length);
        expect(permissions.entries.where((e) => e.value).map((e) => e.key), [
          ClinicPermission.chat,
        ]);
      },
    );

    test('updatePrices sends both prices, null for "not set"', () async {
      final api = repository((o) => throw StateError('answer not needed'));
      await api
          .updatePrices(branchId: 'b1', examinationPricePiasters: 40000)
          .then<void>((_) {}, onError: (_) {});
      expect(sent.single.data, {
        'branchId': 'b1',
        'examinationPricePiasters': 40000,
        'consultationPricePiasters': null,
      });
    });
  });

  group('texts', () {
    final en = lookupAppLocalizations(const Locale('en'));
    final ar = lookupAppLocalizations(const Locale('ar'));

    test('every new error code has a message in both languages', () {
      for (final code in [
        'BRANCH_LIMIT_REACHED',
        'CANNOT_ARCHIVE_DEFAULT_BRANCH',
        'LAST_ACTIVE_BRANCH',
        'BRANCH_HAS_BOOKINGS',
        'BRANCH_NOT_ACTIVE',
        'ASSISTANT_LIMIT_REACHED',
        'ASSISTANT_PHONE_TAKEN',
        'ASSISTANT_REMOVED',
      ]) {
        final error = ApiException(
          kind: ApiErrorKind.http,
          status: 409,
          code: code,
        );
        expect(en.apiError(error), isNot(en.errorUnknown), reason: code);
        expect(ar.apiError(error), isNot(ar.errorUnknown), reason: code);
      }
      for (final code in [
        'INVALID_BRANCH',
        'PERIOD_END_BEFORE_START',
        'PERIOD_LENGTH_OUT_OF_RANGE',
        'PERIODS_OVERLAP',
        'INVALID_MAP_LINK',
      ]) {
        expect(en.fieldError(code), isNotNull, reason: code);
        expect(ar.fieldError(code), isNotNull, reason: code);
      }
      expect(ar.fieldError('PERIODS_OVERLAP'), 'الفترات متداخلة');
      expect(ar.fieldError('INVALID_MAP_LINK'), 'ده مش لينك جوجل ماب.');
      expect(
        ar.apiError(
          const ApiException(
            kind: ApiErrorKind.http,
            code: 'ASSISTANT_LIMIT_REACHED',
          ),
        ),
        'وصلت للحد الأقصى لعدد المساعدين',
      );
    });

    test('activity rows read as sentences, and unknown actions still read', () {
      const names = ActivityNames(
        branches: {'b1': 'Maadi'},
        people: {'a1': 'Sara'},
      );
      ActivityEntry row(
        String action, {
        String? target,
        Map<String, dynamic> details = const {},
      }) => ActivityEntry(
        id: 1,
        at: DateTime.utc(2026, 11, 15),
        actor: const ActivityActor(userId: 'd1', name: 'Ahmed', role: 'doctor'),
        action: action,
        targetType: '',
        targetId: target,
        details: details,
      );
      expect(
        en.activitySentence(row('branchHoursUpdated', target: 'b1'), names),
        'Changed the working hours of Maadi',
      );
      expect(
        en.activitySentence(row('assistantPasswordReset', target: 'a1'), names),
        "Reset Sara's password",
      );
      expect(
        en.activitySentence(
          row(
            'branchStatusChanged',
            target: 'b1',
            details: {'before': 'active', 'after': 'archived'},
          ),
          names,
        ),
        'Maadi: Open → Archived',
      );
      expect(
        en.activitySentence(
          row('sessionCreated', details: {'type': 'consultation'}),
          names,
        ),
        'Recorded a consultation',
      );
      expect(
        en.activitySentence(row('patientCreated'), names),
        'Added a new patient',
      );
      expect(en.activityActionName('sessionDeleted'), 'Visit deleted');
      expect(
        en.activitySentence(row('somethingNew'), names),
        'Other action: something new',
      );
      expect(en.activityActionName('somethingNew'), 'something new');
      expect(
        humanizeAction('assistantPermissionsChanged'),
        'assistant permissions changed',
      );
    });
  });

  test(
    'D27 rows open their patient or visit (a deleted visit opens the patient)',
    () {
      ActivityEntry row(String type, String action, String? target) =>
          ActivityEntry(
            id: 1,
            at: DateTime.utc(2026, 11, 15),
            actor: const ActivityActor(
              userId: 'd1',
              name: 'Ahmed',
              role: 'doctor',
            ),
            action: action,
            targetType: type,
            targetId: target,
            patient: const ActivityPatient(id: 'p1'),
          );
      expect(
        activityTargetPath(row('patient', 'patientCreated', 'p1')),
        '/doctor/patients/p1',
      );
      expect(
        activityTargetPath(row('session', 'sessionCreated', 's1')),
        '/doctor/patients/p1/sessions/s1',
      );
      expect(
        activityTargetPath(row('session', 'sessionDeleted', 's1')),
        '/doctor/patients/p1',
      );
    },
  );
}
