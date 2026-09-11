import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Downscales to a max of [maxSize] on the long edge and re-encodes as JPEG
/// before upload — a phone photo's multi-MB original is wasted bandwidth
/// and storage for what's only ever displayed as a small avatar/thumbnail.
/// Uses the same package:web browser-interop style already established in
/// this app (see tuner_screen.dart's getUserMedia) rather than pulling in a
/// second image-processing dependency just for a resize. Originally
/// profile_screen.dart's own private `_resizeForAvatar` — extracted here
/// once admin_artists_screen.dart needed the exact same resize-before-
/// upload step for artist photos.
Future<Uint8List> resizeImageForUpload(
  Uint8List bytes, {
  int maxSize = 512,
  double quality = 0.85,
}) async {
  final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: 'image/*'));
  final objectUrl = web.URL.createObjectURL(blob);
  final image = web.HTMLImageElement();
  final loaded = Completer<void>();
  image.addEventListener(
    'load',
    (web.Event _) {
      if (!loaded.isCompleted) loaded.complete();
    }.toJS,
  );
  image.addEventListener(
    'error',
    (web.Event _) {
      if (!loaded.isCompleted) {
        loaded.completeError('Could not read that image file.');
      }
    }.toJS,
  );
  image.src = objectUrl;
  await loaded.future;

  final naturalWidth = image.naturalWidth;
  final naturalHeight = image.naturalHeight;
  final longEdge = naturalWidth > naturalHeight ? naturalWidth : naturalHeight;
  final scale = longEdge > maxSize ? maxSize / longEdge : 1.0;
  final targetWidth = (naturalWidth * scale).round();
  final targetHeight = (naturalHeight * scale).round();

  final canvas =
      web.HTMLCanvasElement()
        ..width = targetWidth
        ..height = targetHeight;
  final ctx = canvas.getContext('2d') as web.CanvasRenderingContext2D;
  ctx.drawImage(image, 0, 0, targetWidth.toDouble(), targetHeight.toDouble());
  web.URL.revokeObjectURL(objectUrl);

  final resized = Completer<Uint8List>();
  canvas.toBlob(
    ((web.Blob? outBlob) {
      if (outBlob == null) {
        resized.completeError('Could not process that image.');
        return;
      }
      outBlob.arrayBuffer().toDart.then((buffer) {
        resized.complete(buffer.toDart.asUint8List());
      });
    }).toJS,
    'image/jpeg',
    quality.toJS,
  );
  return resized.future;
}
