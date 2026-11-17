import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/network/api_exception.dart';
import '../../clinic/domain/clinic_permissions.dart';
import '../../patients/data/fake_clinic_records.dart';
import '../domain/prescription_models.dart';
import 'prescriptions_repository.dart';

/// The offline prescriptions for `config/dev-offline.json` and tests. It
/// answers like the API (backend/docs/api-phase-3-prescriptions.md): who may
/// do what (6.10), the statuses (BR-RX2), at least one item to send (BR-RX3),
/// the item history counted on send, templates and the D22 settings.
class FakePrescriptions implements PrescriptionsRepository {
  FakePrescriptions({
    required this.caller,
    required this.records,
    this.delay = const Duration(milliseconds: 250),
    DateTime Function()? now,
    bool seed = true,
  }) : _now = now ?? DateTime.now {
    if (seed) _seed();
  }

  final FakeCaller? Function() caller;
  final FakeClinicRecords records;
  final Duration delay;
  final DateTime Function() _now;

  final _items = <String, _Rx>{};
  final _pdfs = <String, Uint8List>{};
  final _history = <String, ItemHistoryEntry>{};
  final _templates = <String, PrescriptionTemplate>{};
  final _images = <RxImageKind, Uint8List>{};
  RxSettings _settings = const RxSettings();
  final _random = Random(11);
  int _nextId = 1;

  /// Every PDF sent, by prescription (tests read it).
  Map<String, Uint8List> get sentPdfs => Map.unmodifiable(_pdfs);

  // ---------------------------------------------------------------------------
  // Drafts

  @override
  Future<Prescription> createDraft({required String sessionId, required PrescriptionKind kind, String? copyFromId}) async {
    await _wait();
    final who = _drafter();
    _blockWhileSuspended(who);
    final session = records.sessionBasics(sessionId);
    if (session == null) _invalid({'sessionId': 'INVALID_SESSION'});
    final now = _now();
    final rx = _Rx(
      id: _id('rx'),
      patientId: session.patientId,
      sessionId: sessionId,
      kind: kind,
      code: _code(),
      preparedBy: PreparedBy(userId: who.userId, role: who.isDoctor ? 'doctor' : 'assistant', name: who.name),
      createdAt: now,
    )
      ..diagnosis = session.diagnosis
      ..followUpDate = kind == PrescriptionKind.medication ? session.followUpDate : null;
    if (copyFromId != null) {
      final source = _items[copyFromId];
      if (source == null ||
          source.kind != kind ||
          source.patientId != session.patientId ||
          !(source.status == PrescriptionStatus.sent || source.status == PrescriptionStatus.cancelled)) {
        throw const ApiException(kind: ApiErrorKind.http, status: 400, code: 'INVALID_COPY_SOURCE');
      }
      rx
        ..diagnosis = source.diagnosis
        ..advice = source.advice
        ..followUpDate = source.followUpDate
        ..medications = [...source.medications]
        ..investigations = [...source.investigations]
        ..replacesRxId = source.id;
    }
    _items[rx.id] = rx;
    return _view(rx);
  }

  @override
  Future<Prescription> updateDraft(String prescriptionId, PrescriptionKind kind, PrescriptionDraftInput input) async {
    await _wait();
    final who = _drafter();
    _blockWhileSuspended(who);
    final rx = _editable(prescriptionId);
    final errors = <String, String>{};
    if ((input.diagnosis?.length ?? 0) > 1000) errors['diagnosis'] = 'TOO_LONG';
    if ((input.advice?.length ?? 0) > 1000) errors['advice'] = 'TOO_LONG';
    if (rx.kind == PrescriptionKind.medication) {
      if (input.medications.length > 30) errors['items'] = 'TOO_MANY';
      for (final (i, item) in input.medications.indexed) {
        if (item.drugName.trim().isEmpty) errors['items[$i].drugName'] = 'REQUIRED';
      }
    } else {
      if (input.investigations.length > 50) errors['items'] = 'TOO_MANY';
      for (final (i, item) in input.investigations.indexed) {
        if (item.name.trim().isEmpty) errors['items[$i].name'] = 'REQUIRED';
      }
    }
    if (errors.isNotEmpty) _invalid(errors);
    rx
      ..diagnosis = _clean(input.diagnosis)
      ..advice = _clean(input.advice)
      ..followUpDate = input.followUpDate
      ..medications = rx.kind == PrescriptionKind.medication ? [...input.medications] : const []
      ..investigations = rx.kind == PrescriptionKind.investigations ? [...input.investigations] : const []
      ..updatedAt = _now();
    return _view(rx);
  }

  @override
  Future<void> deleteDraft(String prescriptionId) async {
    await _wait();
    final who = _drafter();
    _blockWhileSuspended(who);
    _editable(prescriptionId);
    _items.remove(prescriptionId);
  }

  @override
  Future<Prescription> submitForReview(String prescriptionId) async {
    await _wait();
    final who = _caller();
    if (who.isDoctor) _denied('assistantOnly');
    if (!who.can(ClinicPermission.prescriptionsDraft)) _denied(ClinicPermission.prescriptionsDraft);
    _blockWhileSuspended(who);
    final rx = _editable(prescriptionId);
    if (rx.isEmpty) throw const ApiException(kind: ApiErrorKind.http, status: 409, code: 'PRESCRIPTION_EMPTY');
    rx
      ..status = PrescriptionStatus.readyForReview
      ..updatedAt = _now();
    return _view(rx);
  }

  @override
  Future<Prescription> send(String prescriptionId, Uint8List pdf) async {
    await _wait();
    final who = _doctor();
    _blockWhileSuspended(who);
    final rx = _editable(prescriptionId);
    if (rx.isEmpty) throw const ApiException(kind: ApiErrorKind.http, status: 409, code: 'PRESCRIPTION_EMPTY');
    if (pdf.length < 5 || String.fromCharCodes(pdf.sublist(0, 5)) != '%PDF-') {
      _invalid({'pdf': 'FILE_TYPE_NOT_ALLOWED'});
    }
    final now = _now();
    rx
      ..status = PrescriptionStatus.sent
      ..sentAt = now
      ..updatedAt = now;
    _pdfs[rx.id] = pdf;
    _countUse(rx, now);
    return _view(rx);
  }

  @override
  Future<Prescription> cancel(String prescriptionId, String reason) async {
    await _wait();
    _doctor();
    final rx = _items[prescriptionId] ?? _notFound();
    if (reason.trim().length < 3) _invalid({'reason': 'REASON_REQUIRED'});
    if (rx.status != PrescriptionStatus.sent) {
      throw ApiException(kind: ApiErrorKind.http, status: 409, code: 'PRESCRIPTION_NOT_SENT', details: {'status': rx.status.wire});
    }
    final now = _now();
    rx
      ..status = PrescriptionStatus.cancelled
      ..cancelledAt = now
      ..cancelReason = reason.trim()
      ..updatedAt = now;
    return _view(rx);
  }

  // ---------------------------------------------------------------------------
  // Reads

  @override
  Future<Prescription> prescription(String prescriptionId) async {
    await _wait();
    final who = _reader();
    final rx = _items[prescriptionId];
    if (rx == null || !_visible(who, rx)) _notFound();
    return _view(rx);
  }

  @override
  Future<List<Prescription>> sessionPrescriptions(String sessionId) async {
    await _wait();
    final who = _reader();
    final rows = _items.values.where((rx) => rx.sessionId == sessionId && _visible(who, rx)).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return [for (final rx in rows) _view(rx)];
  }

  @override
  Future<Paged<Prescription>> patientPrescriptions(String patientId, {PrescriptionKind? kind, int page = 1, int pageSize = 25}) async {
    await _wait();
    final who = _reader();
    final rows = _items.values
        .where((rx) => rx.patientId == patientId && (kind == null || rx.kind == kind) && _visible(who, rx))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final start = (page - 1) * pageSize;
    final items = rows.skip(start).take(pageSize).map(_view).toList();
    return Paged(
      items: items,
      page: page,
      pageSize: pageSize,
      totalCount: rows.length,
      totalPages: rows.isEmpty ? 0 : (rows.length + pageSize - 1) ~/ pageSize,
    );
  }

  @override
  Future<Uint8List> pdf(String prescriptionId) async {
    await _wait();
    final who = _reader();
    final rx = _items[prescriptionId];
    if (rx == null || !_visible(who, rx) || !rx.hasPdf) _notFound();
    return _pdfs[rx.id] ??= await _placeholderPdf(rx);
  }

  // ---------------------------------------------------------------------------
  // History and templates

  @override
  Future<List<ItemHistoryEntry>> itemHistory() async {
    await _wait();
    _drafter();
    final rows = _history.values.toList()
      ..sort((a, b) {
        final byCount = b.useCount.compareTo(a.useCount);
        return byCount != 0 ? byCount : b.lastUsedAt.compareTo(a.lastUsedAt);
      });
    return rows.take(1000).toList();
  }

  @override
  Future<void> deleteHistoryItem(String itemId) async {
    await _wait();
    _doctor();
    final key = _history.entries.where((e) => e.value.itemId == itemId).map((e) => e.key).firstOrNull ?? _notFound();
    _history.remove(key);
  }

  @override
  Future<List<PrescriptionTemplate>> templates({PrescriptionKind? kind}) async {
    await _wait();
    _doctor();
    final rows = _templates.values.where((t) => kind == null || t.kind == kind).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return rows;
  }

  @override
  Future<PrescriptionTemplate> createTemplate({
    required String name,
    required PrescriptionKind kind,
    required PrescriptionDraftInput items,
    String? advice,
  }) async {
    await _wait();
    _doctor();
    if (name.trim().isEmpty) _invalid({'name': 'REQUIRED'});
    final count = kind == PrescriptionKind.medication ? items.medications.length : items.investigations.length;
    if (count == 0) _invalid({'items': 'REQUIRED'});
    final template = PrescriptionTemplate(
      templateId: _id('template'),
      kind: kind,
      name: name.trim(),
      medications: kind == PrescriptionKind.medication ? items.medications : const [],
      investigations: kind == PrescriptionKind.investigations ? items.investigations : const [],
      advice: _clean(advice),
      updatedAt: _now(),
    );
    _templates[template.templateId] = template;
    return template;
  }

  @override
  Future<PrescriptionTemplate> updateTemplate(PrescriptionTemplate template, {required String name}) async {
    await _wait();
    _doctor();
    if (!_templates.containsKey(template.templateId)) _notFound();
    if (name.trim().isEmpty) _invalid({'name': 'REQUIRED'});
    final updated = PrescriptionTemplate(
      templateId: template.templateId,
      kind: template.kind,
      name: name.trim(),
      medications: template.medications,
      investigations: template.investigations,
      advice: template.advice,
      updatedAt: _now(),
    );
    _templates[template.templateId] = updated;
    return updated;
  }

  @override
  Future<void> deleteTemplate(String templateId) async {
    await _wait();
    _doctor();
    if (_templates.remove(templateId) == null) _notFound();
  }

  // ---------------------------------------------------------------------------
  // D22

  @override
  Future<RxSettings> rxSettings() async {
    await _wait();
    _doctor();
    return _currentSettings();
  }

  @override
  Future<RxSettings> updateRxSettings(RxSettings settings) async {
    await _wait();
    _doctor();
    final errors = <String, String>{};
    if (!RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(settings.accentColor)) errors['accentColor'] = 'INVALID_VALUE';
    if (settings.paperSize == RxPaperSize.custom) {
      final w = settings.customWidthMm;
      final h = settings.customHeightMm;
      if (w == null) {
        errors['customWidthMm'] = 'REQUIRED';
      } else if (w < 90 || w > 300) {
        errors['customWidthMm'] = 'OUT_OF_RANGE';
      }
      if (h == null) {
        errors['customHeightMm'] = 'REQUIRED';
      } else if (h < 120 || h > 420) {
        errors['customHeightMm'] = 'OUT_OF_RANGE';
      }
    }
    for (final (field, value) in [('marginTopMm', settings.marginTopMm), ('marginBottomMm', settings.marginBottomMm)]) {
      if (value != null && (value < 0 || value > 100)) errors[field] = 'OUT_OF_RANGE';
    }
    if ((settings.footerText?.length ?? 0) > 300) errors['footerText'] = 'TOO_LONG';
    if (errors.isNotEmpty) _invalid(errors);
    _settings = settings.copyWith(accentColor: settings.accentColor.toUpperCase());
    return _currentSettings();
  }

  @override
  Future<RxSettings> uploadRxImage(RxImageKind kind, Uint8List bytes, String fileName) async {
    await _wait();
    _doctor();
    if (bytes.length > 2 * 1024 * 1024) _invalid({'file': 'FILE_TOO_LARGE'});
    _images[kind] = bytes;
    return _currentSettings();
  }

  @override
  Future<Uint8List?> rxImage(RxImageKind kind) async {
    await _wait();
    _doctor();
    return _images[kind];
  }

  @override
  Future<RxSettings> deleteRxImage(RxImageKind kind) async {
    await _wait();
    _doctor();
    _images.remove(kind);
    return _currentSettings();
  }

  // ---------------------------------------------------------------------------
  // Tests

  /// A prescription as stored (tests).
  Prescription? stored(String prescriptionId) => _items[prescriptionId] == null ? null : _view(_items[prescriptionId]!);

  /// Every prescription of a patient, newest first (tests).
  List<Prescription> ofPatient(String patientId) {
    final rows = _items.values.where((rx) => rx.patientId == patientId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return [for (final rx in rows) _view(rx)];
  }

  // ---------------------------------------------------------------------------

  RxSettings _currentSettings() => _settings.copyWith(
        hasLogo: _images.containsKey(RxImageKind.logo),
        hasSignature: _images.containsKey(RxImageKind.signature),
      );

  void _countUse(_Rx rx, DateTime now) {
    final keys = <String>{};
    void count(String kind, String name, String? catalogId, String form, String strength) {
      final key = '$kind|${name.toLowerCase()}|${form.toLowerCase()}|${strength.toLowerCase()}';
      if (!keys.add(key)) return;
      final old = _history[key];
      _history[key] = ItemHistoryEntry(
        itemId: old?.itemId ?? _id('history'),
        kind: kind,
        name: name,
        catalogId: catalogId ?? old?.catalogId,
        form: form,
        strength: strength,
        useCount: (old?.useCount ?? 0) + 1,
        lastUsedAt: now,
      );
    }

    for (final item in rx.medications) {
      count('drug', item.drugName, item.catalogId, item.form ?? '', item.strength ?? '');
    }
    for (final item in rx.investigations) {
      count(item.category.wire, item.name, item.loincCode, '', '');
    }
  }

  bool _visible(FakeCaller who, _Rx rx) {
    if (who.isDoctor || who.can(ClinicPermission.clinicalView)) return true;
    return rx.status == PrescriptionStatus.sent;
  }

  FakeCaller _caller() {
    final who = caller();
    if (who == null) throw const ApiException(kind: ApiErrorKind.http, status: 403, code: ApiCodes.forbidden);
    if (who.trialEnded) throw const ApiException(kind: ApiErrorKind.http, status: 403, code: ApiCodes.trialEnded);
    return who;
  }

  FakeCaller _doctor() {
    final who = _caller();
    if (!who.isDoctor) _denied('doctorOnly');
    return who;
  }

  FakeCaller _drafter() {
    final who = _caller();
    if (!who.can(ClinicPermission.prescriptionsDraft)) _denied(ClinicPermission.prescriptionsDraft);
    return who;
  }

  FakeCaller _reader() {
    final who = _caller();
    if (!who.can(ClinicPermission.clinicalView) && !who.can(ClinicPermission.prescriptionsPrint)) {
      _denied(ClinicPermission.prescriptionsPrint);
    }
    return who;
  }

  _Rx _editable(String prescriptionId) {
    final rx = _items[prescriptionId] ?? _notFound();
    if (!rx.status.editable) {
      throw ApiException(kind: ApiErrorKind.http, status: 409, code: 'PRESCRIPTION_NOT_EDITABLE', details: {'status': rx.status.wire});
    }
    return rx;
  }

  void _blockWhileSuspended(FakeCaller who) {
    if (who.suspended) throw const ApiException(kind: ApiErrorKind.http, status: 403, code: ApiCodes.doctorSuspended);
  }

  Never _denied(String permission) => throw ApiException(
        kind: ApiErrorKind.http,
        status: 403,
        code: ApiCodes.permissionDenied,
        details: {'permission': permission},
      );

  Never _notFound() => throw const ApiException(kind: ApiErrorKind.http, status: 404, code: ApiCodes.notFound);

  Never _invalid(Map<String, String> fields) =>
      throw ApiException(kind: ApiErrorKind.http, status: 400, code: ApiCodes.validationFailed, fieldCodes: fields);

  Future<void> _wait() => Future<void>.delayed(delay);

  String _id(String prefix) => 'dev-$prefix-${_nextId++}';

  String _code() {
    const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    return String.fromCharCodes([for (var i = 0; i < 12; i++) alphabet.codeUnitAt(_random.nextInt(alphabet.length))]);
  }

  Prescription _view(_Rx rx) {
    final replacedBy = _items.values.where((other) => other.replacesRxId == rx.id).map((other) => other.id).firstOrNull;
    return Prescription(
      prescriptionId: rx.id,
      patientId: rx.patientId,
      sessionId: rx.sessionId,
      kind: rx.kind,
      status: rx.status,
      diagnosis: rx.diagnosis,
      advice: rx.advice,
      followUpDate: rx.followUpDate,
      medications: rx.medications,
      investigations: rx.investigations,
      preparedBy: rx.preparedBy,
      sentAt: rx.sentAt,
      cancelledAt: rx.cancelledAt,
      cancelReason: rx.cancelReason,
      replacesRxId: rx.replacesRxId,
      replacedById: replacedBy,
      qrShortCode: rx.code,
      qrUrl: 'https://el3yada.app/rx/${rx.code}',
      hasPdf: rx.hasPdf,
      createdAt: rx.createdAt,
      updatedAt: rx.updatedAt,
    );
  }

  /// The seeded sent documents have no stored PDF of their own: a plain
  /// page stands in for it offline.
  Future<Uint8List> _placeholderPdf(_Rx rx) async {
    final doc = pw.Document()
      ..addPage(pw.Page(
        pageFormat: PdfPageFormat.a5,
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('el3yada - offline prescription', style: const pw.TextStyle(fontSize: 14)),
            pw.SizedBox(height: 12),
            for (final item in rx.medications) pw.Text('${item.drugName} ${item.strength ?? ''}'),
            for (final item in rx.investigations) pw.Text(item.name),
          ],
        ),
      ));
    return doc.save();
  }

  String? _clean(String? value) {
    final text = value?.trim();
    return text == null || text.isEmpty ? null : text;
  }

  /// A sent medication prescription for the first seeded patient with a
  /// session, plus a draft request on the same session.
  void _seed() {
    final monaId = _patientIdOrNull('منى حسن إبراهيم');
    if (monaId == null) return;
    final sessions = records.sessionIdsOf(monaId);
    if (sessions.isEmpty) return;
    final sessionId = sessions.last;
    final base = _now().subtract(const Duration(days: 3));
    final doctor = PreparedBy(userId: FakeClinicRecords.doctorUserId, role: 'doctor', name: FakeClinicRecords.doctorName);
    final sent = _Rx(id: _id('rx'), patientId: monaId, sessionId: sessionId, kind: PrescriptionKind.medication, code: _code(), preparedBy: doctor, createdAt: base)
      ..diagnosis = 'التهاب الحلق'
      ..advice = 'راحة وسوائل دافئة'
      ..medications = const [
        MedicationItem(
          drugName: 'Augmentin 1g',
          activeIngredient: 'amoxicillin + clavulanic acid',
          form: DrugForms.tablet,
          strength: '1 g',
          dose: 'قرص',
          frequency: 'كل 12 ساعة',
          timing: MedicationTiming.afterFood,
          duration: '7 أيام',
        ),
        MedicationItem(
          drugName: 'Panadol Extra',
          activeIngredient: 'paracetamol + caffeine',
          form: DrugForms.tablet,
          strength: '500 mg',
          dose: 'قرص',
          frequency: 'عند اللزوم',
          duration: '5 أيام',
          instructions: 'بحد أقصى 4 أقراص في اليوم',
        ),
      ]
      ..status = PrescriptionStatus.sent
      ..sentAt = base.add(const Duration(minutes: 20));
    _items[sent.id] = sent;
    _countUse(sent, sent.sentAt!);
    final draft = _Rx(id: _id('rx'), patientId: monaId, sessionId: sessionId, kind: PrescriptionKind.investigations, code: _code(), preparedBy: doctor, createdAt: base.add(const Duration(minutes: 25)))
      ..investigations = const [
        InvestigationItem(category: InvestigationCategory.lab, name: 'CBC', notes: 'صائم 8 ساعات'),
        InvestigationItem(category: InvestigationCategory.radiology, name: 'Chest X-ray PA view'),
      ];
    _items[draft.id] = draft;
  }

  String? _patientIdOrNull(String name) {
    try {
      return records.patientIdByName(name);
    } on StateError {
      return null;
    }
  }
}

class _Rx {
  _Rx({
    required this.id,
    required this.patientId,
    required this.sessionId,
    required this.kind,
    required this.code,
    required this.preparedBy,
    required this.createdAt,
  }) : updatedAt = createdAt;

  final String id;
  final String patientId;
  final String sessionId;
  final PrescriptionKind kind;
  final String code;
  final PreparedBy preparedBy;
  final DateTime createdAt;
  DateTime updatedAt;
  PrescriptionStatus status = PrescriptionStatus.draft;
  String? diagnosis;
  String? advice;
  DateTime? followUpDate;
  List<MedicationItem> medications = const [];
  List<InvestigationItem> investigations = const [];
  DateTime? sentAt;
  DateTime? cancelledAt;
  String? cancelReason;
  String? replacesRxId;

  bool get hasPdf => status == PrescriptionStatus.sent || status == PrescriptionStatus.cancelled;

  bool get isEmpty => kind == PrescriptionKind.medication ? medications.isEmpty : investigations.isEmpty;
}

/// The offline prescriptions, sharing the offline clinic's patients and
/// sessions.
final fakePrescriptionsProvider = Provider<FakePrescriptions>(
  (ref) {
    final records = ref.watch(fakeClinicRecordsProvider);
    return FakePrescriptions(caller: () => fakeCallerOf(ref), records: records, delay: records.delay);
  },
);

