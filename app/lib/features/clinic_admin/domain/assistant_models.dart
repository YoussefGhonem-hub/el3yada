import '../../clinic/domain/clinic_permissions.dart';
import 'branch_models.dart';
import 'json_read.dart';

/// Assistant models for D25, D26 (backend/docs/api-phase-2-clinic.md,
/// "Assistants"). Permission keys, presets and dependencies are in
/// `clinic/domain/clinic_permissions.dart`.

/// `Assistants.Status` (BR-AS8).
abstract final class AssistantStatuses {
  static const active = 'active';
  static const disabled = 'disabled';

  /// Soft and final: the history stays in the activity log.
  static const removed = 'removed';
}

/// A branch an assistant works in.
class AssistantBranch {
  const AssistantBranch({required this.id, required this.nameAr, this.nameEn, required this.status});

  factory AssistantBranch.fromJson(Map<String, dynamic> json) => AssistantBranch(
        id: json['id'] as String,
        nameAr: json['nameAr'] as String,
        nameEn: readText(json['nameEn']),
        status: json['status'] as String? ?? BranchStatuses.active,
      );

  final String id;
  final String nameAr;
  final String? nameEn;
  final String status;

  String name(String languageCode) => branchName(languageCode, nameAr, nameEn);
}

/// The assistant object every assistant endpoint answers with.
class Assistant {
  const Assistant({
    required this.userId,
    required this.fullName,
    required this.phone,
    required this.preset,
    required this.status,
    required this.allBranches,
    this.branches = const [],
    this.branchIds = const [],
    this.permissions = const {},
    this.mustChangePassword = false,
    this.lastActiveAt,
    required this.createdAt,
    this.updatedAt,
    this.removedAt,
    this.accountStatus = 'active',
  });

  factory Assistant.fromJson(Map<String, dynamic> json) {
    final permissions = readMapOrNull(json['permissions']) ?? const {};
    return Assistant(
      userId: json['userId'] as String,
      fullName: json['fullName'] as String,
      phone: json['phone'] as String,
      preset: json['preset'] as String? ?? AssistantPreset.custom,
      status: json['status'] as String? ?? AssistantStatuses.active,
      allBranches: json['allBranches'] as bool? ?? false,
      branches: [for (final row in readList(json['branches'])) AssistantBranch.fromJson(row)],
      branchIds: readStrings(json['branchIds']),
      permissions: {for (final MapEntry(:key, :value) in permissions.entries) if (value == true) key},
      mustChangePassword: json['mustChangePassword'] as bool? ?? false,
      lastActiveAt: readTimeOrNull(json['lastActiveAt']),
      createdAt: readTime(json['createdAt']),
      updatedAt: readTimeOrNull(json['updatedAt']),
      removedAt: readTimeOrNull(json['removedAt']),
      accountStatus: json['accountStatus'] as String? ?? 'active',
    );
  }

  final String userId;
  final String fullName;

  /// E.164.
  final String phone;

  /// `reception`, `clinical`, `officeManager` or `custom`, worked out by the server.
  final String preset;
  final String status;
  final bool allBranches;

  /// Empty when [allBranches].
  final List<AssistantBranch> branches;
  final List<String> branchIds;

  /// The keys that are on (spec 6.10).
  final Set<String> permissions;

  /// They haven't replaced the temporary password yet.
  final bool mustChangePassword;

  /// Their last clinic request, to within 5 minutes; null if never.
  final DateTime? lastActiveAt;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? removedAt;

  /// Their login (Users.Status): `pendingDeletion` while they are deleting
  /// their account (spec 6.17), when they no longer act for the clinic.
  final String accountStatus;

  bool get pendingDeletion => accountStatus == 'pendingDeletion';

  bool get isActive => status == AssistantStatuses.active;
  bool get isRemoved => status == AssistantStatuses.removed;
}

/// D25: `GET /api/assistants`. [count] is the active and disabled
/// assistants, which is what [limit] counts.
class AssistantList {
  const AssistantList({required this.items, required this.count, required this.limit, required this.canAdd});

  factory AssistantList.fromJson(Map<String, dynamic> json) => AssistantList(
        items: [for (final row in readList(json['items'])) Assistant.fromJson(row)],
        count: json['count'] as int,
        limit: json['limit'] as int,
        canAdd: json['canAdd'] as bool,
      );

  final List<Assistant> items;
  final int count;
  final int limit;
  final bool canAdd;

  AssistantList copyWith({List<Assistant>? items, int? count, bool? canAdd}) => AssistantList(
        items: items ?? this.items,
        count: count ?? this.count,
        limit: limit,
        canAdd: canAdd ?? this.canAdd,
      );
}

/// `createAssistant` and `resetAssistantPassword`: the assistant and their
/// temporary password, shown once (BR-AS2).
class AssistantWithPassword {
  const AssistantWithPassword({required this.assistant, required this.temporaryPassword});

  factory AssistantWithPassword.fromJson(Map<String, dynamic> json) => AssistantWithPassword(
        assistant: Assistant.fromJson(readMap(json['assistant'])),
        temporaryPassword: json['temporaryPassword'] as String,
      );

  final Assistant assistant;
  final String temporaryPassword;
}

/// The D26 form: what create sends, and what update compares against.
class AssistantDraft {
  const AssistantDraft({
    required this.fullName,
    required this.phone,
    required this.allBranches,
    required this.branchIds,
    required this.permissions,
  });

  factory AssistantDraft.of(Assistant assistant) => AssistantDraft(
        fullName: assistant.fullName,
        phone: assistant.phone,
        allBranches: assistant.allBranches,
        branchIds: assistant.branchIds.toSet(),
        permissions: assistant.permissions,
      );

  final String fullName;

  /// As typed; the server stores E.164.
  final String phone;
  final bool allBranches;
  final Set<String> branchIds;
  final Set<String> permissions;

  /// The preset these permissions match (D26 picker), or custom.
  String get preset => AssistantPreset.match(permissions);

  /// Every key, true or false, as the API takes it.
  Map<String, bool> get permissionMap => permissionMapOf(permissions);

  static Map<String, bool> permissionMapOf(Set<String> keys) =>
      {for (final key in ClinicPermission.all) key: keys.contains(key)};

  Map<String, dynamic> toCreateJson() => {
        'fullName': fullName,
        'phone': phone,
        'allBranches': allBranches,
        'branchIds': allBranches ? const <String>[] : branchIds.toList(),
        'permissions': permissionMap,
      };
}
