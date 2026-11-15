import 'auth_session.dart';
import 'user_role.dart';

/// What `login` answers (A3): a session, or "log in as" when one mobile number
/// has a patient account and an assistant account and the password matched both.
sealed class LoginResult {
  const LoginResult();
}

class SignedIn extends LoginResult {
  const SignedIn(this.session);

  final AuthSession session;
}

/// The app asks «الدخول كـ: مريض / مساعد طبيب», then calls `selectAccount`
/// with [selectionToken] and the chosen role.
class ChooseAccount extends LoginResult {
  const ChooseAccount({required this.selectionToken, required this.accounts, this.expiresAt});

  factory ChooseAccount.fromJson(Map<String, dynamic> json) => ChooseAccount(
        selectionToken: json['selectionToken'] as String,
        expiresAt: DateTime.tryParse('${json['selectionTokenExpiresAt']}'),
        accounts: [
          for (final item in json['accounts'] as List)
            AccountChoice.fromJson((item as Map).cast<String, dynamic>()),
        ],
      );

  final String selectionToken;
  final DateTime? expiresAt;
  final List<AccountChoice> accounts;
}

/// One account to choose. [doctorName] is an assistant's doctor («عيادة د. …»).
class AccountChoice {
  const AccountChoice({required this.role, required this.displayName, this.doctorName});

  factory AccountChoice.fromJson(Map<String, dynamic> json) => AccountChoice(
        role: UserRole.fromJson(json['role'] as String),
        displayName: json['displayName'] as String? ?? '',
        doctorName: json['doctorName'] as String?,
      );

  final UserRole role;
  final String displayName;
  final String? doctorName;
}
