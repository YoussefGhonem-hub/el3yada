import 'dart:convert';
import 'dart:typed_data';

import '../../../core/network/api_error.dart';
import '../domain/patient_models.dart';
import 'patient_repository.dart';

/// Offline patient data for dev builds and tests, the same shape as the API's demo data
/// (`DemoDataSeeder`): two doctors, visits, prescriptions (sent and cancelled) and files.
class FakePatientRepository implements PatientRepository {
  FakePatientRepository({this.delay = const Duration(milliseconds: 250), DateTime? now})
      : _now = now ?? DateTime.now() {
    _build();
  }

  final Duration delay;
  final DateTime _now;

  static const doctorA = DoctorRef(id: 'doc-a', fullName: 'د. أحمد سامي', fullNameEn: 'Dr. Ahmed Samy', title: 'استشاري', titleEn: 'Consultant');
  static const doctorB = DoctorRef(id: 'doc-b', fullName: 'د. منى حسن', fullNameEn: 'Dr. Mona Hassan', title: 'أخصائي', titleEn: 'Specialist');
  static const _specialty = SpecialtyRef(id: 'sp-1', nameAr: 'باطنة', nameEn: 'Internal medicine');
  static const _branchA = BranchRef(id: 'br-a1', nameAr: 'فرع المعادي', nameEn: 'Maadi branch');
  static const _branchB = BranchRef(id: 'br-b1', nameAr: 'عيادة الزمالك', nameEn: 'Zamalek clinic');

  static const _addressA = Address(governorate: 'القاهرة', city: 'المعادي', area: 'المعادي', street: 'شارع 9', landmark: 'بجوار الصيدلية');
  static const _addressB = Address(governorate: 'القاهرة', city: 'الزمالك', area: 'الزمالك', street: '26 يوليو');

  static final Uint8List _png = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==');
  static final Uint8List _pdf = Uint8List.fromList(utf8.encode(
      '%PDF-1.4\n1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj\n2 0 obj<</Type/Pages/Kids[3 0 R]/Count 1>>endobj\n'
      '3 0 obj<</Type/Page/Parent 2 0 R/MediaBox[0 0 420 595]>>endobj\ntrailer<</Root 1 0 R>>\n%%EOF\n'));

  late final List<VisitDetail> _visits;
  late final List<PrescriptionDetail> _prescriptions;
  late final List<RecordDetail> _records;
  final Set<String> _seen = {};
  PatientAccount? _account;

  void _build() {
    final day = DateTime(_now.year, _now.month, _now.day);
    _records = [
      RecordDetail(
        id: 'rec-1', doctor: doctorA, sessionId: 'visit-a1', category: RecordCategory.lab,
        title: 'تحليل صورة دم', documentDate: day.subtract(const Duration(days: 9)), source: 'upload', isNew: true,
        attachments: const [Attachment(id: 'att-1', fileName: 'cbc.png', mimeType: 'image/png', sizeBytes: 68, hasThumbnail: true)],
      ),
      RecordDetail(
        id: 'rec-2', doctor: doctorB, sessionId: 'visit-b1', category: RecordCategory.other, otherType: 'report',
        title: 'تقرير طبي', documentDate: day.subtract(const Duration(days: 1)), source: 'scan',
        attachments: const [Attachment(id: 'att-2', fileName: 'report.pdf', mimeType: 'application/pdf', sizeBytes: 220, pageCount: 1)],
      ),
    ];
    _prescriptions = [
      PrescriptionDetail(
        id: 'rx-cancelled', kind: PrescriptionKind.medication, status: PrescriptionStatus.cancelled, doctor: doctorA,
        sessionId: 'visit-a1', visitDay: day.subtract(const Duration(days: 10)), diagnosis: 'ارتفاع ضغط الدم الأولي',
        sentAt: _now.subtract(const Duration(days: 10)), cancelledAt: _now.subtract(const Duration(days: 9)),
        cancelReason: 'تعديل الجرعة', replacedById: 'rx-med', hasPdf: true,
        medications: const [MedicationItem(drugName: 'Concor 10 mg', form: 'tablet', dose: '1', frequency: '1x1', timing: 'afterFood', duration: '30d')],
      ),
      PrescriptionDetail(
        id: 'rx-med', kind: PrescriptionKind.medication, status: PrescriptionStatus.sent, doctor: doctorA,
        sessionId: 'visit-a1', visitDay: day.subtract(const Duration(days: 10)), diagnosis: 'ارتفاع ضغط الدم الأولي',
        advice: 'قِس الضغط يومياً', sentAt: _now.subtract(const Duration(days: 9)), replacesId: 'rx-cancelled',
        hasPdf: true, isNew: true,
        medications: const [
          MedicationItem(drugName: 'Concor 5 mg', activeIngredient: 'bisoprolol', form: 'tablet', strength: '5 mg', dose: '1', frequency: '1x1', timing: 'afterFood', duration: 'continuous'),
          MedicationItem(drugName: 'Panadol', form: 'tablet', strength: '500 mg', dose: '1', frequency: 'when needed', duration: '5d', instructions: 'عند الصداع فقط'),
        ],
      ),
      PrescriptionDetail(
        id: 'rx-inv', kind: PrescriptionKind.investigations, status: PrescriptionStatus.sent, doctor: doctorA,
        sessionId: 'visit-a1', visitDay: day.subtract(const Duration(days: 10)), sentAt: _now.subtract(const Duration(days: 10)),
        hasPdf: true,
        investigations: const [
          InvestigationItem(category: 'lab', name: 'CBC'),
          InvestigationItem(category: 'radiology', name: 'Echocardiography', notes: 'صائم 4 ساعات'),
        ],
      ),
    ];
    _visits = [
      VisitDetail(
        id: 'visit-b1', doctor: doctorB,
        branch: const VisitBranch(id: 'br-b1', nameAr: 'عيادة الزمالك', nameEn: 'Zamalek clinic', address: _addressB,
            phones: [BranchPhone(number: '+201033333333', label: 'reception', isWhatsapp: true)]),
        type: VisitType.examination, at: _now.subtract(const Duration(days: 1)), day: day.subtract(const Duration(days: 1)),
        chiefComplaint: 'ألم في الحلق', diagnosis: 'التهاب الحلق', isNew: true,
        files: [_listItem(_records[1])],
      ),
      VisitDetail(
        id: 'visit-a1', doctor: doctorA,
        branch: const VisitBranch(id: 'br-a1', nameAr: 'فرع المعادي', nameEn: 'Maadi branch', address: _addressA,
            phones: [BranchPhone(number: '+201011111111', label: 'reception', isWhatsapp: true)]),
        type: VisitType.examination, at: _now.subtract(const Duration(days: 10)), day: day.subtract(const Duration(days: 10)),
        chiefComplaint: 'صداع متكرر', findings: 'ضغط 150/95',
        vitals: const Vitals(bpSys: 150, bpDia: 95, pulse: 84),
        diagnosis: 'ارتفاع ضغط الدم الأولي', patientNotes: 'قلل الملح وامش 30 دقيقة يومياً',
        followUpDate: day.add(const Duration(days: 20)),
        prescriptions: [for (final rx in _prescriptions) _rxItem(rx)],
        files: [_listItem(_records[0])],
      ),
    ];
    _account = PatientAccount(
      personal: _personal,
      locale: 'ar',
      themeMode: 'system',
      notifications: const NotificationPrefs(chat: true, reminders: true, showPreview: false),
    );
  }

  static final _personal = PersonalInfo(
    patientId: 'pat-1', fullName: 'محمد إبراهيم', phone: '+201000000002', gender: 'male',
    dateOfBirth: DateTime(1985, 3, 14), bloodType: 'O+',
  );

  bool _isNew(String id, bool isNew) => isNew && !_seen.contains(id);

  VisitListItem _visitItem(VisitDetail v) => VisitListItem(
        id: v.id, doctor: v.doctor, branch: BranchRef(id: v.branch.id, nameAr: v.branch.nameAr, nameEn: v.branch.nameEn),
        type: v.type, at: v.at, day: v.day, diagnosisSnippet: v.diagnosis, isNew: _isNew(v.id, v.isNew),
      );

  PrescriptionListItem _rxItem(PrescriptionDetail p) => PrescriptionListItem(
        id: p.id, kind: p.kind, status: p.status, doctor: p.doctor, sessionId: p.sessionId, sentAt: p.sentAt,
        cancelledAt: p.cancelledAt, itemCount: p.medications.length + p.investigations.length, isNew: _isNew(p.id, p.isNew),
      );

  RecordListItem _listItem(RecordDetail r) => RecordListItem(
        id: r.id, doctor: r.doctor, sessionId: r.sessionId, category: r.category, otherType: r.otherType,
        title: r.title, documentDate: r.documentDate, attachmentCount: r.attachments.length,
        cover: r.attachments.firstOrNull, isNew: _isNew(r.id, r.isNew),
      );

  Future<T> _answer<T>(T Function() value) async {
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    return value();
  }

  Paged<T> _page<T>(List<T> all, int page) {
    const size = PatientRepository.pageSize;
    final start = (page - 1) * size;
    return Paged(
      items: all.skip(start).take(size).toList(),
      page: page,
      pageSize: size,
      totalCount: all.length,
    );
  }

  bool _matches(String? doctorId, DoctorRef doctor) => doctorId == null || doctorId == doctor.id;

  @override
  Future<PatientHome> home({String? doctorId}) => _answer(() {
        final visits = _visits.where((v) => _matches(doctorId, v.doctor)).toList();
        final rx = _prescriptions.where((p) => _matches(doctorId, p.doctor)).toList()
          ..sort((a, b) => (b.sentAt ?? b.visitDay).compareTo(a.sentAt ?? a.visitDay));
        final records = _records.where((r) => _matches(doctorId, r.doctor)).toList()
          ..sort((a, b) => b.documentDate.compareTo(a.documentDate));
        final followUps = visits.where((v) => v.followUpDate != null).toList();
        return PatientHome(
          fullName: _personal.fullName,
          latestVisit: visits.isEmpty ? null : _visitItem(visits.first),
          latestPrescription: rx.isEmpty ? null : _rxItem(rx.first),
          nextFollowUp: followUps.isEmpty
              ? null
              : FollowUp(date: followUps.first.followUpDate!, doctor: followUps.first.doctor, sessionId: followUps.first.id),
          recentFiles: records.take(3).map(_listItem).toList(),
          newCounts: NewCounts(
            visits: visits.where((v) => _isNew(v.id, v.isNew)).length,
            prescriptions: rx.where((p) => _isNew(p.id, p.isNew)).length,
            files: records.where((r) => _isNew(r.id, r.isNew)).length,
          ),
        );
      });

  @override
  Future<List<MyDoctor>> myDoctors() => _answer(() => [
        MyDoctor(doctor: doctorB, specialty: _specialty, doctorStatus: 'active', fileNumber: 1, linkedAt: _now.subtract(const Duration(days: 30)),
            lastVisitAt: _visits[0].at, defaultBranch: _branchB, defaultBranchArea: 'الزمالك'),
        MyDoctor(doctor: doctorA, specialty: _specialty, doctorStatus: 'active', fileNumber: 1, linkedAt: _now.subtract(const Duration(days: 90)),
            lastVisitAt: _visits[1].at, defaultBranch: _branchA, defaultBranchArea: 'المعادي'),
      ]);

  @override
  Future<DoctorInfo> doctor(String doctorId) => _answer(() {
        if (doctorId == doctorA.id) {
          return DoctorInfo(
            doctor: doctorA, specialty: _specialty, degreesAr: 'دكتوراه الباطنة - جامعة القاهرة', doctorStatus: 'active', fileNumber: 1,
            branches: [
              BranchInfo(
                id: 'br-a1', nameAr: 'فرع المعادي', nameEn: 'Maadi branch', isDefault: true, status: BranchStatus.active,
                address: _addressA,
                phones: const [BranchPhone(number: '+201011111111', label: 'reception', isWhatsapp: true), BranchPhone(number: '+201022222222', label: 'mobile', isWhatsapp: false)],
                workingHours: [for (final d in [6, 7, 1, 2, 3]) WorkingPeriod(weekday: d, start: '17:00', end: '22:00', label: 'مساءً')],
                prices: const VisitPrices(examinationPiasters: 35000, consultationPiasters: 15000),
                paymentMethods: const ['cash', 'instapay'], amenities: const ['elevator', 'parking'],
              ),
              BranchInfo(
                id: 'br-a2', nameAr: 'فرع مدينة نصر', nameEn: 'Nasr City branch', isDefault: false, status: BranchStatus.temporarilyClosed,
                closedMessage: 'مغلق للتجديد', reopenDate: _now.add(const Duration(days: 14)),
                address: const Address(governorate: 'القاهرة', city: 'مدينة نصر', street: 'عباس العقاد'),
              ),
            ],
          );
        }
        if (doctorId == doctorB.id) {
          return DoctorInfo(
            doctor: doctorB, specialty: _specialty, doctorStatus: 'active', fileNumber: 1,
            branches: [
              BranchInfo(
                id: 'br-b1', nameAr: 'عيادة الزمالك', nameEn: 'Zamalek clinic', isDefault: true, status: BranchStatus.active,
                address: _addressB,
                phones: const [BranchPhone(number: '+201033333333', label: 'reception', isWhatsapp: true)],
                workingHours: const [WorkingPeriod(weekday: 4, start: '11:00', end: '15:00')],
                prices: const VisitPrices(examinationPiasters: 25000),
                paymentMethods: const ['cash'],
              ),
            ],
          );
        }
        throw const ApiError(ApiError.notFound, status: 404);
      });

  @override
  Future<Paged<VisitListItem>> visits(PatientListFilter filter, {int page = 1}) => _answer(() => _page(
        _visits
            .where((v) => _matches(filter.doctorId, v.doctor) && (filter.branchId == null || v.branch.id == filter.branchId))
            .map(_visitItem)
            .toList(),
        page,
      ));

  @override
  Future<VisitDetail> visit(String id) => _answer(() => _visits.firstWhere(
        (v) => v.id == id,
        orElse: () => throw const ApiError(ApiError.notFound, status: 404),
      ));

  @override
  Future<Paged<PrescriptionListItem>> prescriptions(PatientListFilter filter, {int page = 1}) => _answer(() => _page(
        _prescriptions
            .where((p) => _matches(filter.doctorId, p.doctor) && (filter.kind == null || p.kind.name == filter.kind))
            .map(_rxItem)
            .toList(),
        page,
      ));

  @override
  Future<PrescriptionDetail> prescription(String id) => _answer(() => _prescriptions.firstWhere(
        (p) => p.id == id,
        orElse: () => throw const ApiError(ApiError.notFound, status: 404),
      ));

  @override
  Future<Uint8List> prescriptionPdf(String id) => _answer(() => _pdf);

  @override
  Future<Paged<RecordListItem>> records(PatientListFilter filter, {int page = 1}) => _answer(() => _page(
        _records
            .where((r) => _matches(filter.doctorId, r.doctor) && (filter.kind == null || r.category.name == filter.kind))
            .map(_listItem)
            .toList(),
        page,
      ));

  @override
  Future<RecordCounts> recordCounts({String? doctorId}) => _answer(() {
        int count(RecordCategory c) => _records.where((r) => r.category == c && _matches(doctorId, r.doctor)).length;
        return RecordCounts(
          prescription: count(RecordCategory.prescription),
          lab: count(RecordCategory.lab),
          radiology: count(RecordCategory.radiology),
          other: count(RecordCategory.other),
        );
      });

  @override
  Future<RecordDetail> record(String id) => _answer(() => _records.firstWhere(
        (r) => r.id == id,
        orElse: () => throw const ApiError(ApiError.notFound, status: 404),
      ));

  @override
  Future<Uint8List> attachment(String recordId, String attachmentId, {bool thumbnail = false}) =>
      _answer(() => attachmentId == 'att-2' && !thumbnail ? _pdf : _png);

  @override
  Future<Uint8List> branchPhoto(String doctorId, String branchId, String photoId, {bool thumbnail = false}) => _answer(() => _png);

  @override
  Future<MedicalProfile> medicalProfile() => _answer(() => MedicalProfile(
        personal: _personal,
        doctors: const [
          DoctorMedicalProfile(
            doctor: doctorA, allergies: ['البنسلين'], chronicDiseases: ['ضغط الدم'], currentMedications: ['Concor 5 mg'],
            familyHistory: 'السكر في العائلة', notes: 'يفضل المواعيد المسائية',
          ),
          DoctorMedicalProfile(doctor: doctorB, surgeries: ['استئصال الزائدة 2015']),
        ],
      ));

  @override
  Future<void> markSeen({List<String> visits = const [], List<String> prescriptions = const [], List<String> files = const []}) =>
      _answer(() => _seen.addAll([...visits, ...prescriptions, ...files]));

  @override
  Future<PatientAccount> account() => _answer(() => _account!);

  @override
  Future<void> updateNotificationPrefs(NotificationPrefs prefs) =>
      _answer(() => _account = _account!.copyWith(notifications: prefs));

  @override
  Future<void> updateAppearance({String? locale, String? themeMode}) => _answer(() {});

  @override
  Future<void> acceptTerms() => _answer(() => _account = _account!.copyWith(acceptedTermsAt: _now));

  @override
  Future<DeletionRequest> requestAccountDeletion(String? reason) => _answer(() {
        if (_account!.hasPendingDeletion) throw const ApiError(ApiError.deletionAlreadyRequested, status: 409);
        final request = DeletionRequest(id: 'del-1', status: DeletionRequestStatus.pending, reason: reason, createdAt: _now);
        _account = _account!.copyWith(deletionRequest: request);
        return request;
      });
}
