const MAX_INPUT_BYTES = 15 * 1024 * 1024;

/**
 * Center-crops to a square, downscales to at most [size] px and re-encodes
 * as JPEG — a phone photo is several MB, but it's shown as a small circle,
 * so this keeps Storage and every later page load cheap. Browser-only
 * (uses createImageBitmap + canvas).
 */
export async function resizeImageForUpload(file: Blob, size = 512, quality = 0.85): Promise<Blob> {
  if (!file.type.startsWith("image/")) throw new Error("Please choose an image file.");
  if (file.size > MAX_INPUT_BYTES) throw new Error("That image is too large. Please choose a smaller photo.");

  const bitmap = await createImageBitmap(file);
  const side = Math.min(bitmap.width, bitmap.height);
  const out = Math.min(size, side);

  const canvas = document.createElement("canvas");
  canvas.width = out;
  canvas.height = out;
  const ctx = canvas.getContext("2d");
  if (!ctx) throw new Error("Couldn't process that image.");
  ctx.drawImage(
    bitmap,
    (bitmap.width - side) / 2,
    (bitmap.height - side) / 2,
    side,
    side,
    0,
    0,
    out,
    out,
  );
  bitmap.close();

  return new Promise<Blob>((resolve, reject) => {
    canvas.toBlob(
      (blob) => (blob ? resolve(blob) : reject(new Error("Couldn't process that image."))),
      "image/jpeg",
      quality,
    );
  });
}
