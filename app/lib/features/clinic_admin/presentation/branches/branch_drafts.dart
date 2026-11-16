import 'dart:convert';

import 'package:flutter/widgets.dart';

import '../../../../core/validation/egyptian_phone.dart';
import '../../../../core/validation/map_links.dart';
import '../../../../core/validation/validators.dart';
import '../../domain/branch_models.dart';
import '../../domain/weekly_hours.dart';

/// Why a branch field isn't accepted, before the API is asked (the same
/// rules as `BranchInput.cs`). Screens turn these into ARB messages.
enum BranchProblem { required, nameLength, tooLong, invalidPhone, phoneRequired, invalidEmail, invalidMapLink }

/// The editable state of one D29 group. A draft starts from the saved
/// group ([fill]), reports whether it changed ([changes]) and what is
/// wrong ([check], by the API's field path), and builds what is sent.
abstract class BranchDraft extends ChangeNotifier {
  /// Field path → problem, for example `info.nameAr` → [BranchProblem.required].
  Map<String, BranchProblem> check();

  /// How many fields differ from the saved group.
  int get changes;

  /// Listens to every text field.
  Listenable get edits;
}

String? _optional(String text) => text.trim().isEmpty ? null : text.trim();

/// Info: name (2–60), English name (≤ 60), description (≤ 500).
class InfoDraft extends BranchDraft {
  InfoDraft([BranchInfo? saved]) {
    if (saved != null) fill(saved);
  }

  final nameAr = TextEditingController();
  final nameEn = TextEditingController();
  final description = TextEditingController();
  BranchInfo? _saved;

  void fill(BranchInfo info) {
    _saved = info;
    nameAr.text = info.nameAr;
    nameEn.text = info.nameEn ?? '';
    description.text = info.description ?? '';
    notifyListeners();
  }

  BranchInfo build() => BranchInfo(nameAr: nameAr.text.trim(), nameEn: _optional(nameEn.text), description: _optional(description.text));

  @override
  Listenable get edits => Listenable.merge([nameAr, nameEn, description, this]);

  @override
  int get changes {
    final saved = _saved;
    if (saved == null) return [nameAr, nameEn, description].where((c) => c.text.trim().isNotEmpty).length;
    final now = build();
    return [now.nameAr != saved.nameAr, now.nameEn != saved.nameEn, now.description != saved.description].where((c) => c).length;
  }

  @override
  Map<String, BranchProblem> check() {
    final name = nameAr.text.trim();
    return {
      if (name.isEmpty)
        'info.nameAr': BranchProblem.required
      else if (name.length < 2 || name.length > 60)
        'info.nameAr': BranchProblem.nameLength,
      if (nameEn.text.trim().length > 60) 'info.nameEn': BranchProblem.tooLong,
      if (description.text.trim().length > 500) 'info.description': BranchProblem.tooLong,
    };
  }

  @override
  void dispose() {
    nameAr.dispose();
    nameEn.dispose();
    description.dispose();
    super.dispose();
  }
}

/// Address and map: governorate, city and the detailed address required;
/// the Google Maps link is optional.
class AddressDraft extends BranchDraft {
  AddressDraft([BranchAddress? saved]) {
    if (saved != null) fill(saved);
  }

  static const maxLength = {
    'governorate': 50,
    'city': 60,
    'area': 60,
    'details': 300,
    'landmark': 150,
    'mapUrl': MapLinks.maxLength,
  };

  String? governorate;
  final city = TextEditingController();
  final area = TextEditingController();

  /// «العنوان بالتفصيل»: street, building, floor and apartment in one text.
  final details = TextEditingController();
  final landmark = TextEditingController();

  /// «لينك جوجل ماب».
  final mapUrl = TextEditingController();
  BranchAddress? _saved;

  List<TextEditingController> get _texts => [city, area, details, landmark, mapUrl];

  void fill(BranchAddress address) {
    _saved = address;
    governorate = address.governorate;
    city.text = address.city;
    area.text = address.area ?? '';
    details.text = address.details;
    landmark.text = address.landmark ?? '';
    mapUrl.text = address.mapUrl ?? '';
    notifyListeners();
  }

  void setGovernorate(String value) {
    governorate = value;
    notifyListeners();
  }

  BranchAddress build() => BranchAddress(
        governorate: (governorate ?? '').trim(),
        city: city.text.trim(),
        area: _optional(area.text),
        details: details.text.trim(),
        landmark: _optional(landmark.text),
        mapUrl: _optional(MapLinks.extract(mapUrl.text)),
      );

  @override
  Listenable get edits => Listenable.merge([..._texts, this]);

  @override
  int get changes {
    final saved = _saved;
    if (saved == null) return [governorate == null ? '' : 'x', ..._texts.map((c) => c.text.trim())].where((t) => t.isNotEmpty).length;
    final before = saved.toJson();
    final after = build().toJson();
    return [for (final key in before.keys) if (jsonEncode(before[key]) != jsonEncode(after[key])) key].length;
  }

  @override
  Map<String, BranchProblem> check() {
    final problems = <String, BranchProblem>{};
    void required(String field, String value) {
      if (value.trim().isEmpty) problems['address.$field'] = BranchProblem.required;
    }

    required('governorate', governorate ?? '');
    required('city', city.text);
    required('details', details.text);
    for (final (field, controller) in [
      ('city', city),
      ('area', area),
      ('details', details),
      ('landmark', landmark),
      ('mapUrl', mapUrl),
    ]) {
      if (controller.text.trim().length > maxLength[field]!) problems['address.$field'] = BranchProblem.tooLong;
    }
    // What is sent: just the link, when the pasted text has words around it.
    final link = MapLinks.extract(mapUrl.text);
    if (link.isNotEmpty && !problems.containsKey('address.mapUrl') && !MapLinks.isGoogleMaps(link)) {
      problems['address.mapUrl'] = BranchProblem.invalidMapLink;
    }
    return problems;
  }

  @override
  void dispose() {
    for (final c in _texts) {
      c.dispose();
    }
    super.dispose();
  }
}

/// One phone row in [ContactDraft].
class PhoneDraft {
  PhoneDraft({String number = '', this.label = PhoneLabels.reception, this.isWhatsapp = false})
      : number = TextEditingController(text: number);

  final key = UniqueKey();
  final TextEditingController number;
  String label;
  bool isWhatsapp;
}

/// Contact: 1–5 phones (mobile, landline or hotline) and an optional email.
class ContactDraft extends BranchDraft {
  ContactDraft([BranchContact? saved]) {
    if (saved != null) {
      fill(saved);
    } else {
      phones.add(PhoneDraft());
    }
  }

  static const maxPhones = 5;

  final phones = <PhoneDraft>[];
  final email = TextEditingController();
  BranchContact? _saved;

  void fill(BranchContact contact) {
    _saved = contact;
    for (final p in phones) {
      p.number.dispose();
    }
    phones
      ..clear()
      ..addAll([
        for (final p in contact.phones)
          PhoneDraft(number: EgyptianPhone.display(p.number), label: p.label, isWhatsapp: p.isWhatsapp),
      ]);
    if (phones.isEmpty) phones.add(PhoneDraft());
    email.text = contact.email ?? '';
    notifyListeners();
  }

  void addPhone() {
    if (phones.length >= maxPhones) return;
    phones.add(PhoneDraft());
    notifyListeners();
  }

  void removePhone(PhoneDraft phone) {
    phones.remove(phone);
    phone.number.dispose();
    notifyListeners();
  }

  void setLabel(PhoneDraft phone, String label) {
    phone.label = label;
    notifyListeners();
  }

  void setWhatsapp(PhoneDraft phone, bool value) {
    phone.isWhatsapp = value;
    notifyListeners();
  }

  /// Empty rows are left out; numbers go as typed (the API stores E.164).
  BranchContact build() => BranchContact(
        phones: [
          for (final p in phones)
            if (p.number.text.trim().isNotEmpty)
              BranchContactPhone(number: p.number.text.trim(), label: p.label, isWhatsapp: p.isWhatsapp),
        ],
        email: _optional(email.text),
      );

  String _signature(BranchContact c) => jsonEncode({
        'phones': [for (final p in c.phones) [EgyptianPhone.normalize(p.number) ?? p.number, p.label, p.isWhatsapp]],
        'email': c.email?.toLowerCase(),
      });

  @override
  Listenable get edits => Listenable.merge([email, this, ...phones.map((p) => p.number)]);

  @override
  int get changes {
    final saved = _saved;
    final now = build();
    if (saved == null) return now.phones.length + (now.email == null ? 0 : 1);
    return _signature(saved) == _signature(now) ? 0 : 1;
  }

  @override
  Map<String, BranchProblem> check() {
    final problems = <String, BranchProblem>{};
    final filled = phones.where((p) => p.number.text.trim().isNotEmpty).toList();
    if (filled.isEmpty) problems['contact.phones'] = BranchProblem.phoneRequired;
    for (final (i, phone) in filled.indexed) {
      if (EgyptianPhone.normalize(phone.number.text) == null) problems['contact.phones[$i].number'] = BranchProblem.invalidPhone;
    }
    final mail = email.text.trim();
    if (mail.isNotEmpty && !Validators.isEmail(mail)) problems['contact.email'] = BranchProblem.invalidEmail;
    return problems;
  }

  /// The index a filled phone has in what is sent (empty rows are skipped),
  /// for matching the API's `contact.phones[i]` errors to their row.
  int? sentIndexOf(PhoneDraft phone) {
    var index = 0;
    for (final p in phones) {
      if (p.number.text.trim().isEmpty) continue;
      if (identical(p, phone)) return index;
      index++;
    }
    return null;
  }

  @override
  void dispose() {
    for (final p in phones) {
      p.number.dispose();
    }
    email.dispose();
    super.dispose();
  }
}

/// Payment methods and amenities.
class ChecklistDraft extends BranchDraft {
  ChecklistDraft([BranchClinicInfo? saved]) {
    if (saved != null) {
      fill(saved);
    } else {
      paymentMethods = {'cash'};
    }
  }

  Set<String> paymentMethods = {};
  Set<String> amenities = {};
  BranchClinicInfo? _saved;

  void fill(BranchClinicInfo info) {
    _saved = info;
    paymentMethods = {...info.paymentMethods};
    amenities = {...info.amenities};
    notifyListeners();
  }

  void togglePayment(String method, bool on) {
    paymentMethods = on ? {...paymentMethods, method} : ({...paymentMethods}..remove(method));
    notifyListeners();
  }

  void toggleAmenity(String amenity, bool on) {
    amenities = on ? {...amenities, amenity} : ({...amenities}..remove(amenity));
    notifyListeners();
  }

  BranchChecklistInput build() => BranchChecklistInput(paymentMethods: paymentMethods.toList(), amenities: amenities.toList());

  @override
  Listenable get edits => this;

  @override
  int get changes {
    final saved = _saved;
    if (saved == null) return 0;
    final before = saved.paymentMethods.toSet();
    final beforeAmenities = saved.amenities.toSet();
    return paymentMethods.difference(before).length +
        before.difference(paymentMethods).length +
        amenities.difference(beforeAmenities).length +
        beforeAmenities.difference(amenities).length;
  }

  @override
  Map<String, BranchProblem> check() => const {};
}

/// One editable working period.
class PeriodDraft {
  PeriodDraft({required this.weekday, required this.start, required this.end, this.endsNextDay = false, this.label, String capacity = ''})
      : capacity = TextEditingController(text: capacity);

  factory PeriodDraft.of(BranchPeriod p) => PeriodDraft(
        weekday: p.weekday,
        start: p.startLocal,
        end: p.endLocal,
        endsNextDay: p.endsNextDay,
        label: p.label,
        capacity: p.capacity?.toString() ?? '',
      );

  final key = UniqueKey();
  int weekday;
  String start;
  String end;
  bool endsNextDay;
  String? label;
  final TextEditingController capacity;

  int? get capacityValue => int.tryParse(Validators.normalizeDigits(capacity.text.trim()));

  BranchPeriod build() => BranchPeriod(
        weekday: weekday,
        startLocal: start,
        endLocal: end,
        endsNextDay: endsNextDay,
        label: label,
        capacity: capacity.text.trim().isEmpty ? null : (capacityValue ?? -1),
      );

  PeriodDraft copyTo(int day) =>
      PeriodDraft(weekday: day, start: start, end: end, endsNextDay: endsNextDay, label: label, capacity: capacity.text);
}

/// Working hours: the whole week, Saturday first.
class HoursDraft extends BranchDraft {
  HoursDraft(List<BranchPeriod> saved) {
    fill(saved);
  }

  final periods = <PeriodDraft>[];
  List<BranchPeriod> _saved = const [];

  void fill(List<BranchPeriod> saved) {
    _saved = saved;
    for (final p in periods) {
      p.capacity.dispose();
    }
    periods
      ..clear()
      ..addAll(saved.map(PeriodDraft.of));
    notifyListeners();
  }

  List<PeriodDraft> ofDay(int weekday) => [for (final p in periods) if (p.weekday == weekday) p]
    ..sort((a, b) => (WeeklyHours.parse(a.start) ?? 0).compareTo(WeeklyHours.parse(b.start) ?? 0));

  /// A new period after the day's last one: an hour after it ends, four
  /// hours long (10:00–14:00 on an empty day).
  void add(int weekday) {
    final day = ofDay(weekday);
    var start = 10 * 60;
    if (day.isNotEmpty) {
      final last = day.last;
      final end = WeeklyHours.parse(last.end) ?? start;
      start = last.endsNextDay ? end : (end + 60).clamp(0, 23 * 60);
    }
    final end = (start + 4 * 60) % (24 * 60);
    periods.add(PeriodDraft(
      weekday: weekday,
      start: WeeklyHours.format(start),
      end: WeeklyHours.format(end),
      endsNextDay: end <= start,
    ));
    notifyListeners();
  }

  void remove(PeriodDraft period) {
    periods.remove(period);
    period.capacity.dispose();
    notifyListeners();
  }

  void update(PeriodDraft period, {String? start, String? end, bool? endsNextDay, String? Function()? label}) {
    if (start != null) period.start = start;
    if (end != null) {
      period.end = end;
      // 20:00 → 01:00 runs past midnight.
      final s = WeeklyHours.parse(period.start);
      final e = WeeklyHours.parse(end);
      if (s != null && e != null) period.endsNextDay = e <= s;
    }
    if (endsNextDay != null) period.endsNextDay = endsNextDay;
    if (label != null) period.label = label();
    notifyListeners();
  }

  /// "Copy Saturday to all days".
  void copySaturdayToAll() {
    final saturday = ofDay(DateTime.saturday);
    for (final p in [...periods]) {
      if (p.weekday != DateTime.saturday) {
        periods.remove(p);
        p.capacity.dispose();
      }
    }
    for (final day in WeeklyHours.weekOrder.skip(1)) {
      periods.addAll(saturday.map((p) => p.copyTo(day)));
    }
    notifyListeners();
  }

  /// What is sent, in the order the API's `periods[i]` errors refer to.
  List<PeriodDraft> get ordered => [for (final day in WeeklyHours.weekOrder) ...ofDay(day)];

  List<BranchPeriod> build() => [for (final p in ordered) p.build()];

  @override
  Listenable get edits => Listenable.merge([this, ...periods.map((p) => p.capacity)]);

  @override
  int get changes {
    final now = build();
    final before = [for (final day in WeeklyHours.weekOrder) ...WeeklyHours.ofDay(_saved, day)];
    if (now.length != before.length) return (now.length - before.length).abs().clamp(1, 99);
    var count = 0;
    for (var i = 0; i < now.length; i++) {
      if (now[i] != before[i]) count++;
    }
    return count;
  }

  /// Problems are keyed by the period's index in [ordered].
  @override
  Map<String, BranchProblem> check() => const {};

  @override
  void dispose() {
    for (final p in periods) {
      p.capacity.dispose();
    }
    super.dispose();
  }
}
