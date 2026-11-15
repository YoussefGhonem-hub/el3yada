import '../../../core/data/paged.dart';
import 'json_read.dart';

/// D27 activity log (`GET /api/clinic/activity`, BR-AS10).

/// Who did it: `doctor`, `assistant`, or `system` (no user, no name).
class ActivityActor {
  const ActivityActor({this.userId, this.name, required this.role});

  factory ActivityActor.fromJson(Map<String, dynamic> json) =>
      ActivityActor(userId: json['userId'] as String?, name: readText(json['name']), role: json['role'] as String? ?? 'system');

  final String? userId;
  final String? name;
  final String role;

  bool get isSystem => role == 'system';
}

/// The patient an action was about. [name] and [fileNumber] are null when
/// they are no longer linked to this clinic.
class ActivityPatient {
  const ActivityPatient({required this.id, this.name, this.fileNumber});

  factory ActivityPatient.fromJson(Map<String, dynamic> json) =>
      ActivityPatient(id: json['id'] as String, name: readText(json['name']), fileNumber: json['fileNumber'] as int?);

  final String id;
  final String? name;
  final int? fileNumber;
}

class ActivityEntry {
  const ActivityEntry({
    required this.id,
    required this.at,
    required this.actor,
    required this.action,
    required this.targetType,
    this.targetId,
    this.patient,
    this.details = const {},
  });

  factory ActivityEntry.fromJson(Map<String, dynamic> json) => ActivityEntry(
        id: json['id'] as int,
        at: readTime(json['at']),
        actor: ActivityActor.fromJson(readMap(json['actor'])),
        action: json['action'] as String,
        targetType: json['targetType'] as String? ?? '',
        targetId: json['targetId'] as String?,
        patient: json['patient'] == null ? null : ActivityPatient.fromJson(readMap(json['patient'])),
        details: readMapOrNull(json['details']) ?? const {},
      );

  final int id;
  final DateTime at;
  final ActivityActor actor;
  final String action;
  final String targetType;
  final String? targetId;
  final ActivityPatient? patient;

  /// Action-specific IDs and values, never medical text.
  final Map<String, dynamic> details;
}

/// Someone for the person filter: the doctor, then every assistant the
/// clinic ever had (removed ones last).
class ActivityPerson {
  const ActivityPerson({required this.userId, required this.name, required this.role, this.status});

  factory ActivityPerson.fromJson(Map<String, dynamic> json) => ActivityPerson(
        userId: json['userId'] as String,
        name: json['name'] as String,
        role: json['role'] as String,
        status: json['status'] as String?,
      );

  final String userId;
  final String name;
  final String role;

  /// An assistant's status (`active`, `disabled`, `removed`); null for the doctor.
  final String? status;
}

/// A page of the log, with the filter choices the API sends with it.
class ActivityPage {
  const ActivityPage({required this.page, this.people = const [], this.actions = const []});

  factory ActivityPage.fromJson(Map<String, dynamic> json) => ActivityPage(
        page: Paged.fromJson(json, ActivityEntry.fromJson),
        people: [for (final row in readList(json['people'])) ActivityPerson.fromJson(row)],
        actions: readStrings(json['actions']),
      );

  final Paged<ActivityEntry> page;
  final List<ActivityPerson> people;

  /// Every action in this clinic's log.
  final List<String> actions;
}

/// D27 filters. Dates are Cairo calendar days, both included.
class ActivityFilter {
  const ActivityFilter({this.actorUserId, this.actorName, this.action, this.from, this.to, this.patientId, this.patientName});

  final String? actorUserId;

  /// Shown on the filter chip.
  final String? actorName;
  final String? action;
  final DateTime? from;
  final DateTime? to;
  final String? patientId;
  final String? patientName;

  bool get isEmpty => actorUserId == null && action == null && from == null && to == null && patientId == null;

  ActivityFilter withActor(String? userId, String? name) =>
      ActivityFilter(actorUserId: userId, actorName: name, action: action, from: from, to: to, patientId: patientId, patientName: patientName);

  ActivityFilter withAction(String? value) =>
      ActivityFilter(actorUserId: actorUserId, actorName: actorName, action: value, from: from, to: to, patientId: patientId, patientName: patientName);

  ActivityFilter withDates(DateTime? start, DateTime? end) =>
      ActivityFilter(actorUserId: actorUserId, actorName: actorName, action: action, from: start, to: end, patientId: patientId, patientName: patientName);

  ActivityFilter withPatient(String? id, String? name) =>
      ActivityFilter(actorUserId: actorUserId, actorName: actorName, action: action, from: from, to: to, patientId: id, patientName: name);

  Map<String, dynamic> toQuery() => {
        'actorUserId': ?actorUserId,
        'action': ?action,
        'patientId': ?patientId,
        if (from != null) 'from': writeDay(from!),
        if (to != null) 'to': writeDay(to!),
      };
}
