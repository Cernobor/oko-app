import 'package:oko/urls/stub.dart'
    // ignore: uri_does_not_exist
    if (dart.library.io) 'package:oko/urls/mobile.dart'
    // ignore: uri_does_not_exist
    if (dart.library.html) 'package:oko/urls/web.dart';

abstract class UriCreator {
  Uri handshakeUri(String serverAddress);
  Uri pingUri(String serverAddress);
  Uri data(String serverAddress);

  factory UriCreator() => getUriCreator();
}

String cleanupAddress(String address) {
  if (address.startsWith('http://')) {
    return address.substring('http://'.length);
  }
  if (address.startsWith('https://')) {
    return address.substring('https://'.length);
  }
  return address;
}
