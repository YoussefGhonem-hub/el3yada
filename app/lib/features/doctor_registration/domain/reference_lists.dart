/// Fixed lists for A4 that live in the app rather than the API. Like the
/// lists the admin manages (spec section 12), each entry carries both
/// languages: the screen shows the current one and the API stores [ar].
library;

/// A name in Arabic and English.
class BilingualName {
  const BilingualName(this.ar, this.en);

  final String ar;
  final String en;

  String of(String languageCode) => languageCode == 'ar' ? ar : en;

  /// [value] in either language (the API may hold one typed before this list).
  bool isNamed(String value) {
    final trimmed = value.trim();
    return trimmed == ar || trimmed.toLowerCase() == en.toLowerCase();
  }
}

/// Egypt's 27 governorates, in the usual order (Greater Cairo, Delta, Canal,
/// Sinai, Upper Egypt, frontier). `branch.governorate` stores the Arabic name.
abstract final class Governorates {
  static const all = [
    BilingualName('القاهرة', 'Cairo'),
    BilingualName('الجيزة', 'Giza'),
    BilingualName('القليوبية', 'Qalyubia'),
    BilingualName('الإسكندرية', 'Alexandria'),
    BilingualName('البحيرة', 'Beheira'),
    BilingualName('مطروح', 'Matrouh'),
    BilingualName('الدقهلية', 'Dakahlia'),
    BilingualName('الشرقية', 'Sharqia'),
    BilingualName('الغربية', 'Gharbia'),
    BilingualName('المنوفية', 'Monufia'),
    BilingualName('كفر الشيخ', 'Kafr El Sheikh'),
    BilingualName('دمياط', 'Damietta'),
    BilingualName('بورسعيد', 'Port Said'),
    BilingualName('الإسماعيلية', 'Ismailia'),
    BilingualName('السويس', 'Suez'),
    BilingualName('شمال سيناء', 'North Sinai'),
    BilingualName('جنوب سيناء', 'South Sinai'),
    BilingualName('الفيوم', 'Faiyum'),
    BilingualName('بني سويف', 'Beni Suef'),
    BilingualName('المنيا', 'Minya'),
    BilingualName('أسيوط', 'Asyut'),
    BilingualName('سوهاج', 'Sohag'),
    BilingualName('قنا', 'Qena'),
    BilingualName('الأقصر', 'Luxor'),
    BilingualName('أسوان', 'Aswan'),
    BilingualName('البحر الأحمر', 'Red Sea'),
    BilingualName('الوادي الجديد', 'New Valley'),
  ];

  /// The entry for a stored value, or null for a name this list doesn't have.
  static BilingualName? find(String value) {
    for (final governorate in all) {
      if (governorate.isNamed(value)) return governorate;
    }
    return null;
  }
}

/// The common professional titles (A4 step 2). `title` stores [BilingualName.ar]
/// and `titleEn` the English one, for the prescription header; anything else
/// is typed as free text (at most 40 characters).
abstract final class DoctorTitles {
  static const all = [
    BilingualName('أخصائي', 'Specialist'),
    BilingualName('استشاري', 'Consultant'),
    BilingualName('أستاذ', 'Professor'),
    BilingualName('أستاذ مساعد', 'Associate Professor'),
    BilingualName('مدرس', 'Lecturer'),
  ];

  static BilingualName? find(String value) {
    for (final title in all) {
      if (title.isNamed(value)) return title;
    }
    return null;
  }
}
