/// Assistant permission keys (spec 6.10), the same strings as the API
/// (`GET /api/clinic/me` → `permissions`, `PERMISSION_DENIED` → `permission`).
/// A doctor has every permission.
///
/// Keep in step with backend/src/El3yada.Api/Clinic/ClinicPermissions.cs.
abstract final class ClinicPermission {
  static const patientsManage = 'patientsManage';
  static const patientsResetPassword = 'patientsResetPassword';
  static const sessionsCreate = 'sessionsCreate';
  static const sessionsDelete = 'sessionsDelete';
  static const clinicalView = 'clinicalView';
  static const clinicalEditProfile = 'clinicalEditProfile';
  static const filesManage = 'filesManage';
  static const prescriptionsPrint = 'prescriptionsPrint';
  static const prescriptionsDraft = 'prescriptionsDraft';
  static const chat = 'chat';
  static const billingView = 'billingView';
  static const billingPay = 'billingPay';
  static const appointmentsView = 'appointmentsView';
  static const appointmentsManage = 'appointmentsManage';
  static const scheduleManage = 'scheduleManage';
  static const revenueView = 'revenueView';
  static const pricesManage = 'pricesManage';

  /// Every key, in the order of the spec's table and the D26 checklist.
  static const all = [
    patientsManage, patientsResetPassword, sessionsCreate, sessionsDelete, clinicalView, clinicalEditProfile,
    filesManage, prescriptionsPrint, prescriptionsDraft, chat, billingView, billingPay, appointmentsView,
    appointmentsManage, scheduleManage, revenueView, pricesManage,
  ];

  /// A permission that needs another: turning it on turns that one on, and
  /// turning that one off turns this one off (spec 6.10, "Dependencies").
  static const requires = {
    clinicalEditProfile: clinicalView,
    prescriptionsDraft: clinicalView,
    billingPay: billingView,
    appointmentsManage: appointmentsView,
    scheduleManage: appointmentsManage,
  };

  /// [keys] with [key] switched on (and what it needs) or off (and what
  /// needs it), as the D26 checklist does.
  static Set<String> toggle(Set<String> keys, String key, {required bool on}) {
    final result = {...keys};
    if (on) {
      String? next = key;
      while (next != null && result.add(next)) {
        next = requires[next];
      }
      return result;
    }
    final queue = [key];
    while (queue.isNotEmpty) {
      final off = queue.removeLast();
      if (!result.remove(off)) continue;
      queue.addAll(requires.entries.where((e) => e.value == off).map((e) => e.key));
    }
    return result;
  }
}

/// Assistant presets (spec 6.10). Picking one fills the checklist; changing
/// any box makes it [custom].
abstract final class AssistantPreset {
  static const reception = 'reception';
  static const clinical = 'clinical';
  static const officeManager = 'officeManager';
  static const custom = 'custom';

  static const all = [reception, clinical, officeManager, custom];

  static const permissions = <String, Set<String>>{
    reception: {
      ClinicPermission.patientsManage, ClinicPermission.patientsResetPassword, ClinicPermission.sessionsCreate,
      ClinicPermission.filesManage, ClinicPermission.prescriptionsPrint, ClinicPermission.appointmentsView,
      ClinicPermission.appointmentsManage,
    },
    clinical: {
      ClinicPermission.patientsManage, ClinicPermission.patientsResetPassword, ClinicPermission.sessionsCreate,
      ClinicPermission.clinicalView, ClinicPermission.clinicalEditProfile, ClinicPermission.filesManage,
      ClinicPermission.prescriptionsPrint, ClinicPermission.prescriptionsDraft, ClinicPermission.chat,
      ClinicPermission.appointmentsView, ClinicPermission.appointmentsManage,
    },
    officeManager: {
      ClinicPermission.patientsManage, ClinicPermission.patientsResetPassword, ClinicPermission.sessionsCreate,
      ClinicPermission.filesManage, ClinicPermission.prescriptionsPrint, ClinicPermission.chat,
      ClinicPermission.billingView, ClinicPermission.billingPay, ClinicPermission.appointmentsView,
      ClinicPermission.appointmentsManage, ClinicPermission.scheduleManage, ClinicPermission.pricesManage,
    },
  };

  /// The preset with exactly [keys], or [custom].
  static String match(Set<String> keys) {
    for (final MapEntry(:key, :value) in permissions.entries) {
      if (value.length == keys.length && value.containsAll(keys)) return key;
    }
    return custom;
  }
}
