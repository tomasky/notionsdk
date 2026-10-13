///|
/// Helpers for receiving and verifying Notion webhook deliveries.
///
/// Port of `src/webhooks.ts`. Event signatures use HMAC-SHA256 with the
/// subscription's verification token. The `X-Notion-Signature` header contains
/// `sha256=<hex>`. Pass the raw body as received; parsing and re-serializing
/// JSON can change its bytes and invalidate the signature.

///|
/// Arguments for `verify_webhook_signature`.
pub(all) struct VerifyWebhookSignatureArgs {
  /// The raw HTTP request body, before any parsing.
  body : String
  /// The value of the `X-Notion-Signature` request header. Verification fails
  /// (returns false) if this is missing or malformed.
  signature : String?
  /// The verification token configured for this webhook subscription.
  verification_token : String
}

///|
/// The prefix of the signature header value.
let signature_prefix : String = "sha256="

///|
/// Length of a SHA-256 digest in lower-case hex.
let sha256_hex_length : Int = 64

///|
/// Verify that a webhook delivery came from Notion and has not been tampered
/// with.
///
/// Returns `true` if the signature matches HMAC-SHA256 of the body using the
/// verification token. Returns `false` for a missing or malformed signature.
pub fn verify_webhook_signature(args : VerifyWebhookSignatureArgs) -> Bool {
  let { body, signature, verification_token, } = args
  let provided_hex = match signature {
    None => return false
    Some(value) => {
      if !value.has_prefix(signature_prefix) {
        return false
      }
      value[signature_prefix.length():].to_owned().to_lower()
    }
  }
  if provided_hex.length() != sha256_hex_length {
    return false
  }
  if !is_lower_hex(provided_hex) {
    return false
  }
  let computed_hex = bytes_to_hex(
    hmac_sha256(@utf8.encode(verification_token), @utf8.encode(body)),
  )
  timing_safe_equal_hex(provided_hex, computed_hex)
}

///|
/// Compute the value Notion would send in `X-Notion-Signature` for a given body
/// and verification token. Use this to test webhook handlers without a live
/// subscription.
pub fn sign_webhook_payload(
  body : String,
  verification_token : String,
) -> String {
  let hex = bytes_to_hex(
    hmac_sha256(@utf8.encode(verification_token), @utf8.encode(body)),
  )
  signature_prefix + hex
}

///|
/// Whether a string consists only of lower-case hex digits.
fn is_lower_hex(value : String) -> Bool {
  for ch in value {
    match ch {
      '0'..='9' | 'a'..='f' => ()
      _ => return false
    }
  }
  true
}

///|
/// Constant-time string comparison. The inputs are already known to be the same
/// length, so this purely avoids early-exit on the first differing character.
fn timing_safe_equal_hex(a : String, b : String) -> Bool {
  if a.length() != b.length() {
    return false
  }
  let mut diff = 0
  for i = 0; i < a.length(); i = i + 1 {
    diff = diff | (a.get(i).unwrap() ^ b.get(i).unwrap()).to_int()
  }
  diff == 0
}
