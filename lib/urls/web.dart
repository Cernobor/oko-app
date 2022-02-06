import 'package:oko/urls/urls.dart';

class WebUriCreator implements UriCreator {
  @override
  Uri handshakeUri(String serverAddress) {
    return Uri.parse('$serverAddress/handshake');
  }

  @override
  Uri pingUri(String serverAddress) {
    return Uri.parse('$serverAddress/ping');
  }

  @override
  Uri data(String serverAddress) {
    return Uri.parse('$serverAddress/data');
  }
}

UriCreator getUriCreator() => WebUriCreator();
