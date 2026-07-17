import 'package:latlong2/latlong.dart';

/// پارس Deep Link / Intent برای دریافت مقصد از اپ‌های دیگر.
///
/// پشتیبانی:
/// - `geo:lat,lon`
/// - `geo:0,0?q=lat,lon(label)`
/// - `https://maps.google.com/?q=lat,lon`
/// - `abtin://navigate?lat=..&lon=..&title=..`
class DeeplinkDestination {
  final LatLng location;
  final String? title;

  const DeeplinkDestination(this.location, {this.title});
}

class DeeplinkParser {
  const DeeplinkParser();

  DeeplinkDestination? parse(String uriString) {
    final uri = Uri.tryParse(uriString.trim());
    if (uri == null) return null;

    if (uri.scheme == 'geo') {
      // geo:35.7,51.4 or geo:0,0?q=35.7,51.4(Label)
      final path = uri.path;
      final coords = _parseCoords(path);
      if (coords != null) {
        return DeeplinkDestination(coords, title: uri.queryParameters['q']);
      }
      final q = uri.queryParameters['q'];
      if (q != null) {
        final m = RegExp(r'([-+]?\d+(\.\d+)?)\s*,\s*([-+]?\d+(\.\d+)?)')
            .firstMatch(q);
        if (m != null) {
          final lat = double.parse(m.group(1)!);
          final lon = double.parse(m.group(3)!);
          final labelMatch = RegExp(r'\((.+)\)').firstMatch(q);
          return DeeplinkDestination(
            LatLng(lat, lon),
            title: labelMatch?.group(1),
          );
        }
      }
    }

    if (uri.scheme == 'abtin' || uri.host.contains('abtin')) {
      final lat = double.tryParse(uri.queryParameters['lat'] ?? '');
      final lon = double.tryParse(uri.queryParameters['lon'] ?? '');
      if (lat != null && lon != null) {
        return DeeplinkDestination(
          LatLng(lat, lon),
          title: uri.queryParameters['title'],
        );
      }
    }

    if (uri.host.contains('google') || uri.host.contains('maps')) {
      final q = uri.queryParameters['q'] ?? uri.queryParameters['query'];
      if (q != null) {
        final m = RegExp(r'([-+]?\d+(\.\d+)?)\s*,\s*([-+]?\d+(\.\d+)?)')
            .firstMatch(q);
        if (m != null) {
          return DeeplinkDestination(
            LatLng(double.parse(m.group(1)!), double.parse(m.group(3)!)),
          );
        }
      }
      final ll = uri.queryParameters['ll'];
      if (ll != null) {
        final c = _parseCoords(ll);
        if (c != null) return DeeplinkDestination(c);
      }
    }

    return null;
  }

  LatLng? _parseCoords(String s) {
    final m =
        RegExp(r'([-+]?\d+(\.\d+)?)\s*,\s*([-+]?\d+(\.\d+)?)').firstMatch(s);
    if (m == null) return null;
    return LatLng(double.parse(m.group(1)!), double.parse(m.group(3)!));
  }
}
