import 'package:url_launcher/url_launcher.dart';

/// Privacy Policy URL — Telegraph hosted (V1 launch).
/// V2'de noblara.com/privacy'ye taşınacak.
const String kPrivacyPolicyUrl = 'https://telegra.ph/Privacy-Policy--Noblara-05-08';

/// Launch a legal URL (Privacy Policy, Terms of Service, etc.)
/// Returns true if URL launched successfully, false otherwise.
Future<bool> launchLegalUrl(String url) async {
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
  return false;
}
