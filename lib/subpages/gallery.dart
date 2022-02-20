import 'dart:developer' as developer;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:oko/data.dart';
import 'package:oko/i18n.dart';
import 'package:oko/storage.dart';
import 'package:oko/utils.dart';

const _photoPopupHeroTag = 'photoPopup';
const _thumbMaxDimen = 100;
const _deletedColor = Color(0xff777777);

class Gallery extends StatefulWidget {
  final Storage storage;
  final Feature feature;
  final bool editable;

  const Gallery(
      {Key? key,
      required this.storage,
      required this.feature,
      required this.editable})
      : super(key: key);

  @override
  State<StatefulWidget> createState() => _GalleryState();
}

class _GalleryState<T> extends State<Gallery> {
  _GalleryState();

  List<ThumbnailMemoryPhotoFileFeaturePhoto> photos = [];
  Set<int> current = {};
  final ImagePicker picker = ImagePicker();
  bool ready = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await loadPhotos();
    current = Set.of(widget.feature.photoIDs);
    setState(() {
      ready = true;
    });
  }

  Future<void> loadPhotos() async {
    photos = await widget.storage.getPhotos(widget.feature.id);
    photos.sort();
  }

  Widget? _thumbnail(ThumbnailMemoryPhotoFileFeaturePhoto photo) {
    if (current.contains(photo.id) &&
        widget.feature.origPhotoIDs.contains(photo.id)) {
      return GestureDetector(
        child: Container(
          decoration: BoxDecoration(border: Border.all(color: Colors.white)),
          child: Hero(
            tag: '$_photoPopupHeroTag-${photo.id}',
            child: Image(image: MemoryImage(photo.thumbnailDataSync)),
          ),
        ),
        onTap: () => onThumbnailTap(photo),
      );
    } else if (!current.contains(photo.id) &&
        widget.feature.origPhotoIDs.contains(photo.id)) {
      return Tooltip(
          richMessage: TextSpan(children: [
            TextSpan(
                text: I18N.of(context).deletedPhoto,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const TextSpan(text: '\n \n', style: TextStyle(height: 0.2)),
            TextSpan(text: I18N.of(context).deletedPhotoDetail)
          ]),
          margin: const EdgeInsets.symmetric(horizontal: 36),
          child: GestureDetector(
            child: Container(
              decoration:
                  BoxDecoration(border: Border.all(color: _deletedColor)),
              child: Hero(
                tag: '$_photoPopupHeroTag-${photo.id}',
                child: Stack(
                  alignment: Alignment.topRight,
                  children: [
                    Image(
                        image: MemoryImage(photo.thumbnailDataSync),
                        color: _deletedColor,
                        colorBlendMode: BlendMode.multiply),
                    Icon(
                      Icons.delete,
                      size: 24,
                      color: Theme.of(context).colorScheme.primary,
                    )
                  ],
                ),
              ),
            ),
            onTap: () => onThumbnailTap(photo),
          ));
    } else if (current.contains(photo.id) &&
        !widget.feature.origPhotoIDs.contains(photo.id)) {
      return Tooltip(
          richMessage: TextSpan(children: [
            TextSpan(
                text: I18N.of(context).addedPhoto,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const TextSpan(text: '\n \n', style: TextStyle(height: 0.2)),
            TextSpan(text: I18N.of(context).addedPhotoDetail)
          ]),
          margin: const EdgeInsets.symmetric(horizontal: 36),
          child: GestureDetector(
            child: Container(
              decoration: BoxDecoration(
                  border:
                      Border.all(color: Theme.of(context).colorScheme.primary)),
              child: Hero(
                tag: '$_photoPopupHeroTag-${photo.id}',
                child: Stack(
                  alignment: Alignment.topRight,
                  children: [
                    Image(image: MemoryImage(photo.thumbnailDataSync)),
                    Icon(
                      Icons.star,
                      size: 24,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    Icon(
                      Icons.star_border,
                      size: 24,
                      color: Theme.of(context).colorScheme.onPrimary,
                    )
                  ],
                ),
              ),
            ),
            onTap: () => onThumbnailTap(photo),
          ));
    } else {
      developer.log('photo ID ${photo.id} neither in current nor in orig');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> thumbs =
        photos.map(_thumbnail).where((w) => w != null).cast<Widget>().toList();
    if (widget.editable) {
      thumbs.add(Container(
        width: _thumbMaxDimen.toDouble() + 2,
        height: _thumbMaxDimen.toDouble() + 2,
        decoration: BoxDecoration(border: Border.all(color: Colors.white)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
                icon: const Icon(Icons.add_a_photo),
                tooltip: I18N.of(context).takePhoto,
                onPressed: () => onPickPhoto(ImageSource.camera)),
            IconButton(
                icon: const Icon(Icons.add_photo_alternate),
                tooltip: I18N.of(context).pickPhoto,
                onPressed: () => onPickPhoto(ImageSource.gallery)),
          ],
        ),
      ));
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(I18N.of(context).managePhotos),
        primary: true,
        leading: BackButton(
          onPressed: _save,
        ),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: SingleChildScrollView(
                child: Wrap(
              //alignment: WrapAlignment.spaceBetween,
              direction: Axis.horizontal,
              crossAxisAlignment: WrapCrossAlignment.center,
              verticalDirection: VerticalDirection.down,
              //runAlignment: WrapAlignment.center,
              spacing: 4,
              runSpacing: 4,
              children: thumbs,
            ))),
      ),
    );
  }

  void onPickPhoto(ImageSource source) async {
    final XFile? photoFile;
    try {
      photoFile = await picker.pickImage(
          source: source, preferredCameraDevice: CameraDevice.rear);
    } on Exception catch (e, stack) {
      developer.log('exception: $e\n$stack}');
      notifyDialog(context, 'TODO exception when getting photo', e.toString(),
          NotificationLevel.error);
      return;
    }
    if (photoFile == null) {
      return;
    }
    developer.log('photo name: ${photoFile.name} mime: ${photoFile.mimeType}');
    developer.log('reading file');
    Uint8List photoBytes = await photoFile.readAsBytes();
    developer.log('decoding file');
    String contentType;
    String normPhotoFileName = photoFile.name.toLowerCase();
    if (normPhotoFileName.endsWith('.jpeg') ||
        normPhotoFileName.endsWith('.jpg')) {
      contentType = 'image/jpeg';
    } else if (normPhotoFileName.endsWith('png')) {
      contentType = 'image/png';
    } else {
      await notifyDialog(
          context,
          'TODO unsupported format',
          'image file ${photoFile.name} is neither jp(e)g nor png',
          NotificationLevel.error);
      return;
    }
    developer.log('encoding PNG thumbnail');
    Uint8List thumbnailBytes = await _pngThumbnail(photoBytes);

    developer.log('saving');
    int photoID = await widget.storage.addPhoto(widget.feature.id, 'image/png',
        contentType, thumbnailBytes, photoBytes);
    await loadPhotos();
    current.add(photoID);
    setState(() {});
  }

  Future<void> onThumbnailTap(FeaturePhoto photo) async {
    bool action = await Navigator.push<bool>(context, MaterialPageRoute(
          builder: (context) {
            return PhotoPopup(photo, current.contains(photo.id));
          },
        )) ??
        false;
    developer.log('$action');
    if (!action) {
      return;
    }
    if (current.contains(photo.id)) {
      current.remove(photo.id);
      if (widget.feature.isLocal) {
        await widget.storage.deletePhoto(photo.id);
        await loadPhotos();
      }
    } else if (!current.contains(photo.id) &&
        widget.feature.origPhotoIDs.contains(photo.id)) {
      current.add(photo.id);
    } else {
      throw IllegalStateException('photo neither in current nor orig');
    }
    setState(() {});
  }

  void _save() async {
    Feature f;
    if (widget.feature.isLocal) {
      if (widget.feature is Point) {
        f = Point.from(widget.feature as Point,
            photoIDs: current, origPhotoIDs: current);
      } else if (widget.feature is LineString) {
        f = LineString.from(widget.feature as LineString,
            photoIDs: current, origPhotoIDs: current);
      } else {
        throw IllegalStateException('unknown feature type');
      }
    } else {
      if (widget.feature is Point) {
        f = Point.from(widget.feature as Point, photoIDs: current);
      } else if (widget.feature is LineString) {
        f = LineString.from(widget.feature as LineString, photoIDs: current);
      } else {
        throw IllegalStateException('unknown feature type');
      }
    }
    Navigator.of(context).pop(f);
  }
}

class PhotoPopup extends StatelessWidget {
  final FeaturePhoto photo;
  final bool deleting;
  const PhotoPopup(this.photo, this.deleting, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: '$_photoPopupHeroTag-${photo.id}',
      child: Scaffold(
        body: Center(
          child: FutureBuilder(
            future: photo.photoData,
            initialData: null,
            builder: (BuildContext context, AsyncSnapshot<Uint8List?> data) {
              if (data.data == null) {
                return const CircularProgressIndicator();
              } else {
                return Stack(
                  alignment: Alignment.center,
                  fit: StackFit.loose,
                  children: [
                    Image(
                        image: MemoryImage(data.data!),
                        frameBuilder: (BuildContext context, Widget child,
                            int? frame, bool wasSynchronouslyLoaded) {
                          if (frame == null) {
                            return const CircularProgressIndicator();
                          } else {
                            return child;
                          }
                        }),
                    Padding(
                        padding: const EdgeInsets.all(24),
                        child: Stack(
                          children: [
                            Align(
                              alignment: Alignment.topRight,
                              child: IconButton(
                                  icon: const Icon(Icons.close),
                                  tooltip: I18N.of(context).close,
                                  onPressed: () {
                                    Navigator.pop(context, false);
                                  }),
                            ),
                            Align(
                              alignment: Alignment.topLeft,
                              child: IconButton(
                                  icon: Icon(deleting
                                      ? Icons.delete
                                      : Icons.restore_from_trash),
                                  tooltip: deleting
                                      ? I18N.of(context).delete
                                      : I18N.of(context).undelete,
                                  onPressed: () {
                                    Navigator.pop(context, true);
                                  }),
                            )
                          ],
                        ))
                  ],
                );
              }
            },
          ),
        ),
      ),
    );
  }
}

Future<Uint8List> _pngThumbnail(Uint8List full) async {
  var buffer = await ui.ImmutableBuffer.fromUint8List(full);
  var descriptor = await ui.ImageDescriptor.encoded(buffer);
  ui.Codec codec;
  if (descriptor.width > descriptor.height) {
    codec = await descriptor.instantiateCodec(targetWidth: _thumbMaxDimen);
  } else {
    codec = await descriptor.instantiateCodec(targetHeight: _thumbMaxDimen);
  }
  var frameInfo = await codec.getNextFrame();
  var byteData =
      await frameInfo.image.toByteData(format: ui.ImageByteFormat.png);
  return byteData!.buffer.asUint8List();
}
