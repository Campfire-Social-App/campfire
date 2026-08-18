/// The pair of tokens the API client needs on every request, held apart from
/// the auth provider so the two do not have to import each other: the client
/// reads and refreshes them, the provider owns their lifecycle and persistence.
class TokenHolder {
  TokenHolder({this.accessToken, this.refreshToken});

  /// 15 minutes. Replaced in place by the refresh flow.
  String? accessToken;

  /// 30 days, and the only one that is persisted.
  String? refreshToken;

  bool get hasSession => refreshToken != null;

  void clear() {
    accessToken = null;
    refreshToken = null;
  }
}
