/// The four roles in spec section 5.
enum UserRole {
  admin,
  doctor,
  assistant,
  patient;

  static UserRole fromJson(String value) => UserRole.values.firstWhere(
        (role) => role.name == value,
        orElse: () => throw FormatException('Unknown role: $value'),
      );

  String toJson() => name;
}
