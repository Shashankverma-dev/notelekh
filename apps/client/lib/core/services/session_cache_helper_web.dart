import 'package:web/web.dart' as web;

bool checkSavedSessionSync() {
  try {
    final hasSession = web.window.localStorage.getItem('flutter.notelekh_has_user_session');
    final isRedirect = web.window.localStorage.getItem('flutter.notelekh_pending_auth_redirect');
    return hasSession == 'true' || isRedirect == 'true';
  } catch (_) {
    return false;
  }
}
