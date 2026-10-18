class AccountBridge {
  Future<Map<String, dynamic>> request(
    String action, {
    Map<String, dynamic> parameters = const {},
  }) async {
    throw UnsupportedError('Sesi akun UB tersedia melalui browser web.');
  }
}
