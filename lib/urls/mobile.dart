import 'package:oko/urls/urls.dart';

class MobileUriCreator implements UriCreator {
  @override
  Uri handshakeUri(String serverAddress) {
    return Uri.parse(serverAddress).resolve('handshake');
  }

  @override
  Uri pingUri(String serverAddress) {
    return Uri.parse(serverAddress).resolve('ping');
  }

  @override
  Uri data(String serverAddress) {
    return Uri.parse(serverAddress).resolve('data');
  }
}

UriCreator getUriCreator() => MobileUriCreator();