import '../../doctor_registration/domain/specialty.dart';
import 'json_read.dart';

/// D22: `GET /api/doctor/profile`. Email, phone, license number and status
/// are read-only here.
class DoctorProfile {
  const DoctorProfile({
    required this.doctorId,
    required this.fullName,
    this.fullNameEn,
    required this.title,
    this.titleEn,
    this.degreesAr,
    this.degreesEn,
    this.specialty,
    required this.specialtyId,
    this.extraSpecialties = const [],
    this.email,
    this.emailVerified = true,
    this.phone,
    this.licenseNumber,
    required this.status,
    this.updatedAt,
  });

  factory DoctorProfile.fromJson(Map<String, dynamic> json) => DoctorProfile(
        doctorId: json['doctorId'] as String,
        fullName: json['fullName'] as String,
        fullNameEn: readText(json['fullNameEn']),
        title: json['title'] as String? ?? '',
        titleEn: readText(json['titleEn']),
        degreesAr: readText(json['degreesAr']),
        degreesEn: readText(json['degreesEn']),
        specialty: json['specialty'] == null ? null : Specialty.fromJson(readMap(json['specialty'])),
        specialtyId: json['specialtyId'] as String,
        extraSpecialties: [for (final row in readList(json['extraSpecialties'])) Specialty.fromJson(row)],
        email: readText(json['email']),
        emailVerified: json['emailVerified'] as bool? ?? true,
        phone: readText(json['phone']),
        licenseNumber: readText(json['licenseNumber']),
        status: json['status'] as String? ?? 'active',
        updatedAt: readTimeOrNull(json['updatedAt']),
      );

  final String doctorId;
  final String fullName;
  final String? fullNameEn;
  final String title;
  final String? titleEn;
  final String? degreesAr;
  final String? degreesEn;
  final Specialty? specialty;
  final String specialtyId;
  final List<Specialty> extraSpecialties;
  final String? email;
  final bool emailVerified;
  final String? phone;
  final String? licenseNumber;
  final String status;
  final DateTime? updatedAt;

  List<String> get extraSpecialtyIds => [for (final s in extraSpecialties) s.id];
}

/// The D22 form, sent whole to `POST /api/doctor/updateProfile`.
class DoctorProfileUpdate {
  const DoctorProfileUpdate({
    required this.fullName,
    this.fullNameEn,
    required this.title,
    this.titleEn,
    this.degreesAr,
    this.degreesEn,
    required this.specialtyId,
    this.extraSpecialtyIds = const [],
  });

  final String fullName;
  final String? fullNameEn;
  final String title;
  final String? titleEn;
  final String? degreesAr;
  final String? degreesEn;
  final String specialtyId;
  final List<String> extraSpecialtyIds;

  Map<String, dynamic> toJson() => {
        'fullName': fullName,
        'fullNameEn': fullNameEn,
        'title': title,
        'titleEn': titleEn,
        'degreesAr': degreesAr,
        'degreesEn': degreesEn,
        'specialtyId': specialtyId,
        'extraSpecialtyIds': extraSpecialtyIds,
      };
}

/// D24, AS12: the signed-in user's own notification preferences
/// (`GET /api/me/notificationPrefs`). Push uses them from Phase 5.
class NotificationPrefs {
  const NotificationPrefs({this.chat = true, this.reminders = true, this.showPreview = false, this.bookings = false});

  factory NotificationPrefs.fromJson(Map<String, dynamic> json) => NotificationPrefs(
        chat: json['chat'] as bool? ?? true,
        reminders: json['reminders'] as bool? ?? true,
        showPreview: json['showPreview'] as bool? ?? false,
        bookings: json['bookings'] as bool? ?? false,
      );

  /// New chat messages.
  final bool chat;

  /// Billing and appointment reminders.
  final bool reminders;

  /// The message text in chat pushes (default off, spec 10.1).
  final bool showPreview;

  /// The doctor's booking alerts (doctors only).
  final bool bookings;

  NotificationPrefs copyWith({bool? chat, bool? reminders, bool? showPreview, bool? bookings}) => NotificationPrefs(
        chat: chat ?? this.chat,
        reminders: reminders ?? this.reminders,
        showPreview: showPreview ?? this.showPreview,
        bookings: bookings ?? this.bookings,
      );

  Map<String, dynamic> toJson() => {'chat': chat, 'reminders': reminders, 'showPreview': showPreview, 'bookings': bookings};
}
