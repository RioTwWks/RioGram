/// Предикаты состояний TDLib для инициализации авторизации.
String? authorizationStateType(Map<String, dynamic> update) {
  if (update['@type'] == 'updateAuthorizationState') {
    final state = update['authorization_state'] as Map<String, dynamic>?;
    return state?['@type'] as String?;
  }
  return update['@type'] as String?;
}

bool isTdlibParametersStageUpdate(Map<String, dynamic> update) {
  final stateType = authorizationStateType(update);
  return stateType == 'authorizationStateWaitTdlibParameters' ||
      isPastTdlibParametersStage(stateType);
}

bool isInteractiveAuthorizationUpdate(Map<String, dynamic> update) {
  final stateType = authorizationStateType(update);
  return isPastTdlibParametersStage(stateType);
}

bool isPastTdlibParametersStage(String? stateType) {
  return switch (stateType) {
    'authorizationStateWaitPhoneNumber' ||
    'authorizationStateWaitCode' ||
    'authorizationStateWaitPassword' ||
    'authorizationStateWaitOtherDeviceConfirmation' ||
    'authorizationStateWaitEmailAddress' ||
    'authorizationStateWaitEmailCode' ||
    'authorizationStateWaitRegistration' ||
    'authorizationStateReady' =>
      true,
    _ => false,
  };
}
