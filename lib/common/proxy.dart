import 'package:fl_clash/common/system.dart';
import 'package:proxy/proxy.dart';

final proxy = system.isDesktop ? Proxy() : null;

/// Extract leading flag emoji from proxy name.
/// Returns country code (lowercase, e.g. "de") and cleaned name.
({String? countryCode, String name}) extractFlag(String raw) {
  final runes = raw.runes.toList();
  if (runes.length >= 2) {
    final a = runes[0];
    final b = runes[1];
    // Regional Indicator Symbol range: 0x1F1E6 (🇦) to 0x1F1FF (🇿)
    if (a >= 0x1F1E6 && a <= 0x1F1FF && b >= 0x1F1E6 && b <= 0x1F1FF) {
      final code = String.fromCharCodes([
        a - 0x1F1E6 + 0x41,
        b - 0x1F1E6 + 0x41,
      ]).toLowerCase();
      var rest = String.fromCharCodes(runes.sublist(2));
      rest = rest.trimLeft();
      if (rest.startsWith('|') || rest.startsWith('-') || rest.startsWith('·')) {
        rest = rest.substring(1).trimLeft();
      }
      return (countryCode: code, name: rest.isEmpty ? raw : rest);
    }
  }
  return (countryCode: null, name: raw);
}
