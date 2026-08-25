/// Состояние облачного пароля (2FA) аккаунта.
class PasswordStateModel {
  const PasswordStateModel({
    this.hasPassword = false,
    this.passwordHint = '',
    this.hasRecoveryEmail = false,
    this.recoveryEmailPattern = '',
    this.pendingResetDate = 0,
  });

  final bool hasPassword;
  final String passwordHint;
  final bool hasRecoveryEmail;
  final String recoveryEmailPattern;
  final int pendingResetDate;

  bool get canResetImmediately =>
      pendingResetDate > 0 &&
      pendingResetDate <= DateTime.now().millisecondsSinceEpoch ~/ 1000;

  PasswordStateModel copyWith({
    bool? hasPassword,
    String? passwordHint,
    bool? hasRecoveryEmail,
    String? recoveryEmailPattern,
    int? pendingResetDate,
  }) {
    return PasswordStateModel(
      hasPassword: hasPassword ?? this.hasPassword,
      passwordHint: passwordHint ?? this.passwordHint,
      hasRecoveryEmail: hasRecoveryEmail ?? this.hasRecoveryEmail,
      recoveryEmailPattern:
          recoveryEmailPattern ?? this.recoveryEmailPattern,
      pendingResetDate: pendingResetDate ?? this.pendingResetDate,
    );
  }
}
