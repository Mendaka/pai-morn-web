// Builds public/promptpay-qr.png: a real, scannable Thai QR Payment (PromptPay)
// code with no fixed amount, so a donor's own banking app lets them type any
// amount. This is the ONLY place that should ever construct a payment QR for
// this site — never hand-build one inline in a component.
//
// Usage:
//   node scripts/generate-promptpay-qr.mjs <phone-or-13-digit-id> ["Merchant Name"]
//
// <phone-or-13-digit-id> is whatever identifier the owner's banking app shows
// as their PromptPay target — a 10-digit mobile number (with or without
// leading 0/+66) or a 13-digit Thai national ID / juristic ID. This is not a
// secret (it's exactly what anyone sending them money via PromptPay already
// sees), but it IS a real payment destination: only ever run this with an
// identifier the owner has explicitly given, and always confirm the output by
// scanning it before it ships — money sent to a wrong ID cannot be recalled.
//
// Implements the EMV QR Code spec (the same format every Thai bank app reads)
// by hand — deterministic, no payment-processor dependency, so the resulting
// PNG can be regenerated identically by anyone reviewing this script.
import path from "node:path";
import QRCode from "qrcode";

const [, , rawTarget, merchantName = "PAIMORN"] = process.argv;
if (!rawTarget) {
  console.error("Usage: node scripts/generate-promptpay-qr.mjs <phone-or-13-digit-id> [\"Merchant Name\"]");
  process.exit(1);
}

const digits = rawTarget.replace(/\D/g, "");
let proxyType; // "01" = mobile number, "02" = national/juristic ID
let proxyValue;
if (digits.length === 13) {
  proxyType = "02";
  proxyValue = digits;
} else {
  // Mobile number: PromptPay wants it as country code 66 + the number with its
  // leading 0 dropped (e.g. 0812345678 -> 66812345678), padded to 13 digits.
  proxyType = "01";
  const local = digits.replace(/^0/, "").replace(/^66/, "");
  proxyValue = ("0000000000000" + "66" + local).slice(-13);
}

// TLV = Tag-Length-Value, the building block of every field in an EMV QR.
const tlv = (tag, value) => `${tag}${String(value.length).padStart(2, "0")}${value}`;

const merchantAccountInfo = tlv("00", "A000000677010111") + tlv(proxyType, proxyValue);

const payloadWithoutCrc =
  tlv("00", "01") + // Payload Format Indicator
  tlv("01", "11") + // Point of Initiation Method: 11 = static (no fixed amount)
  tlv("29", merchantAccountInfo) + // PromptPay merchant account info
  tlv("53", "764") + // Currency: THB
  tlv("58", "TH") + // Country
  tlv("59", merchantName.slice(0, 25)) +
  "6304"; // CRC tag + length, value appended below

// CRC-16/CCITT-FALSE over everything so far, as the spec requires.
function crc16(str) {
  let crc = 0xffff;
  for (const ch of Buffer.from(str, "ascii")) {
    crc ^= ch << 8;
    for (let i = 0; i < 8; i++) crc = crc & 0x8000 ? ((crc << 1) ^ 0x1021) & 0xffff : (crc << 1) & 0xffff;
  }
  return crc.toString(16).toUpperCase().padStart(4, "0");
}

const payload = payloadWithoutCrc + crc16(payloadWithoutCrc);

const outPath = path.join(import.meta.dirname, "..", "public", "promptpay-qr.png");
await QRCode.toFile(outPath, payload, { width: 640, margin: 2 });
console.log("Wrote", outPath);
console.log("Payload:", payload);
console.log("Scan the output file with a Thai banking app to confirm the amount field is blank and the name/target look right BEFORE this goes live.");
