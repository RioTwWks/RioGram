enum AuthPhase {
  initializing,
  waitPhoneNumber,
  waitCode,
  waitPassword,
  waitQrConfirmation,
  waitRegistration,
  waitEmailAddress,
  waitEmailCode,
  ready,
  error,
}

/// Условия регистрации нового аккаунта.
class RegistrationTerms {
  const RegistrationTerms({
    required this.text,
    this.minUserAge = 0,
    this.showPopup = false,
  });

  final String text;
  final int minUserAge;
  final bool showPopup;

  factory RegistrationTerms.fromTdlib(Map<String, dynamic>? json) {
    if (json == null || json['@type'] != 'termsOfService') {
      return const RegistrationTerms(text: '');
    }
    final formatted = json['text'] as Map<String, dynamic>?;
    return RegistrationTerms(
      text: formatted?['text'] as String? ?? '',
      minUserAge: json['min_user_age'] as int? ?? 0,
      showPopup: json['show_popup'] as bool? ?? false,
    );
  }
}
