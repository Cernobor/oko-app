import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';

import 'package:oko/data.dart';
import 'package:oko/utils.dart' as utils;
import 'package:oko/communication.dart' as comm;
import 'package:oko/i18n.dart';

class _PairingDialogState extends State<PairingDialog> {
  final TextEditingController addressInputController = TextEditingController();
  final TextEditingController nameInputController = TextEditingController();
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');

  String? addressInputError;
  String? nameInputError;
  bool exists = false;

  QRViewController? controller;
  bool scanning = false;

  _PairingDialogState();

  @override
  void reassemble() {
    super.reassemble();
    if (controller == null) {
      return;
    }
    if (Platform.isAndroid) {
      controller!.pauseCamera();
    } else if (Platform.isIOS) {
      controller!.resumeCamera();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (addressInputController.text.isNotEmpty) {
      addressInputError = null;
    } else {
      addressInputError = I18N.of(context).errorAddressRequired;
    }
    if (nameInputController.text.isNotEmpty) {
      nameInputError = null;
    } else {
      nameInputError = I18N.of(context).errorNameRequired;
    }
    return SimpleDialog(
      title: Text(I18N.of(context).pairing),
      children: <Widget>[
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: TextField(
                controller: addressInputController,
                decoration: InputDecoration(
                    suffixIcon: IconButton(
                        icon: Icon(scanning
                            ? Icons.qr_code_2
                            : Icons.qr_code_2_outlined),
                        color: scanning
                            ? Theme.of(context).colorScheme.secondary
                            : null,
                        onPressed: () {
                          if (scanning) {
                            controller!.dispose();
                            setState(() {
                              scanning = false;
                            });
                          } else {
                            FocusScope.of(context).unfocus();
                            setState(() {
                              scanning = true;
                            });
                          }
                        }),
                    labelText: I18N.of(context).serverAddressLabel,
                    errorText: addressInputError),
                onChanged: (String value) {
                  setState(() {
                    if (value.isEmpty) {
                      addressInputError = I18N.of(context).errorAddressRequired;
                    } else {
                      addressInputError = null;
                    }
                  });
                })),
        if (scanning)
          AspectRatio(
              aspectRatio: 1,
              child: Stack(children: <Widget>[
                QRView(
                  onQRViewCreated: _onQRViewCreated,
                  key: qrKey,
                ),
                Align(
                  alignment: Alignment.bottomLeft,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.switch_camera),
                        color: Theme.of(context).colorScheme.secondary,
                        onPressed: () {
                          controller!.flipCamera();
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.flash_on),
                        color: Theme.of(context).colorScheme.secondary,
                        onPressed: () {
                          controller!.toggleFlash();
                        },
                      )
                    ],
                  ),
                ),
              ])),
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: TextField(
                controller: nameInputController,
                decoration: InputDecoration(
                    labelText: I18N.of(context).nameLabel,
                    errorText: nameInputError),
                onChanged: (String value) {
                  setState(() {
                    if (value.isEmpty) {
                      nameInputError = I18N.of(context).errorNameRequired;
                    } else {
                      nameInputError = null;
                    }
                  });
                })),
        CheckboxListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          value: exists,
          title: Text(I18N.of(context).handshakeExistsTitle),
          subtitle: Text(I18N.of(context).handshakeExistsSubtitle),
          onChanged: (bool? value) {
            setState(() {
              exists = value!;
            });
          },
        ),
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                MaterialButton(
                  color: Theme.of(context).colorScheme.primary,
                  textColor: Theme.of(context).colorScheme.onPrimary,
                  child: Text(I18N.of(context).dialogPair),
                  onPressed: _isValid() ? _pair : null,
                ),
                MaterialButton(
                  color: Theme.of(context).colorScheme.primary,
                  textColor: Theme.of(context).colorScheme.onPrimary,
                  child: Text(I18N.of(context).dialogCancel),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                )
              ],
            ))
      ],
    );
  }

  void _onQRViewCreated(QRViewController controller) {
    this.controller = controller;
    controller.scannedDataStream.listen((Barcode barcode) {
      developer.log('Barcode ${barcode.code}');
      addressInputController.text = barcode.code!;
      setState(() {
        scanning = false;
        this.controller?.dispose();
        this.controller = null;
      });
    });
  }

  bool _isValid() {
    return addressInputController.text.isNotEmpty &&
        nameInputController.text.isNotEmpty;
  }

  void _pair() async {
    String serverAddress = addressInputController.text;
    ServerSettings ss;
    try {
      ss =
          await comm.handshake(serverAddress, nameInputController.text, exists);
    } on comm.DetailedCommException catch (e) {
      developer.log('exception: ${e.toString()}');
      await utils.notifyDialog(context, e.getMessage(context),
          e.detail, utils.NotificationLevel.error);
      return;
    } on comm.CommException catch (e) {
      developer.log('exception: ${e.toString()}');
      await utils.notifyDialog(context, e.getMessage(context),
          null, utils.NotificationLevel.error);
      return;
    } catch (e) {
      developer.log('exception: ${e.toString()}');
      await utils.notifyDialog(context, I18N.of(context).serverUnavailable,
          e.toString(), utils.NotificationLevel.error);
      return;
    }
    Navigator.of(context).pop(ss);
  }

  @override
  void dispose() {
    addressInputController.dispose();
    nameInputController.dispose();
    controller?.dispose();
    super.dispose();
  }
}

class PairingDialog extends StatefulWidget {
  final GlobalKey<ScaffoldState> scaffoldKey;

  const PairingDialog({Key? key, required this.scaffoldKey}) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return _PairingDialogState();
  }
}
