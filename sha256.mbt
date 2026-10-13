///|
/// SHA-256 and HMAC-SHA256, used by the webhook helpers.
///
/// The TypeScript SDK delegates to Web Crypto. MoonBit's core has no digest
/// package, so this file implements the algorithms directly. They operate on
/// bytes and are independent of the rest of the client.

///|
/// SHA-256 round constants.
let sha256_k : Array[UInt] = [
  0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4,
  0xab1c5ed5, 0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe,
  0x9bdc06a7, 0xc19bf174, 0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f,
  0x4a7484aa, 0x5cb0a9dc, 0x76f988da, 0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7,
  0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967, 0x27b70a85, 0x2e1b2138, 0x4d2c6dfc,
  0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85, 0xa2bfe8a1, 0xa81a664b,
  0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070, 0x19a4c116,
  0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
  0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7,
  0xc67178f2,
]

///|
/// Rotates a 32-bit word right by `n` bits.
fn rotr(value : UInt, n : Int) -> UInt {
  (value >> n) | (value << (32 - n))
}

///|
/// Computes SHA-256 over the given bytes and returns the 32-byte digest.
pub fn sha256_bytes(data : BytesView) -> Bytes {
  let mut a : UInt = 0x6a09e667
  let mut b : UInt = 0xbb67ae85
  let mut c : UInt = 0x3c6ef372
  let mut d : UInt = 0xa54ff53a
  let mut e : UInt = 0x510e527f
  let mut f : UInt = 0x9b05688c
  let mut g : UInt = 0x1f83d9ab
  let mut h : UInt = 0x5be0cd19

  let message : Array[UInt] = []
  for byte in data {
    message.push(byte.to_uint())
  }
  let bit_length = message.length().to_uint64() * 8
  message.push(0x80)
  while message.length() % 64 != 56 {
    message.push(0)
  }
  for i = 0; i < 8; i = i + 1 {
    message.push((bit_length >> ((7 - i) * 8)).to_uint() & 0xff)
  }

  let w : Array[UInt] = Array::make(64, 0)
  let blocks = message.length() / 64
  for block = 0; block < blocks; block = block + 1 {
    let offset = block * 64
    for i = 0; i < 16; i = i + 1 {
      let j = offset + i * 4
      w[i] = (message[j] << 24) |
        (message[j + 1] << 16) |
        (message[j + 2] << 8) |
        message[j + 3]
    }
    for i = 16; i < 64; i = i + 1 {
      let s0 = rotr(w[i - 15], 7) ^ rotr(w[i - 15], 18) ^ (w[i - 15] >> 3)
      let s1 = rotr(w[i - 2], 17) ^ rotr(w[i - 2], 19) ^ (w[i - 2] >> 10)
      w[i] = w[i - 16] + s0 + w[i - 7] + s1
    }
    let mut h0 = a
    let mut h1 = b
    let mut h2 = c
    let mut h3 = d
    let mut h4 = e
    let mut h5 = f
    let mut h6 = g
    let mut h7 = h
    for i = 0; i < 64; i = i + 1 {
      let s1 = rotr(h4, 6) ^ rotr(h4, 11) ^ rotr(h4, 25)
      let ch = (h4 & h5) ^ ((h4 ^ 0xffffffff) & h6)
      let temp1 = h7 + s1 + ch + sha256_k[i] + w[i]
      let s0 = rotr(h0, 2) ^ rotr(h0, 13) ^ rotr(h0, 22)
      let maj = (h0 & h1) ^ (h0 & h2) ^ (h1 & h2)
      let temp2 = s0 + maj
      h7 = h6
      h6 = h5
      h5 = h4
      h4 = h3 + temp1
      h3 = h2
      h2 = h1
      h1 = h0
      h0 = temp1 + temp2
    }
    a = a + h0
    b = b + h1
    c = c + h2
    d = d + h3
    e = e + h4
    f = f + h5
    g = g + h6
    h = h + h7
  }

  let digest : Array[Byte] = []
  for word in [a, b, c, d, e, f, g, h] {
    digest.push(((word >> 24) & 0xff).to_byte())
    digest.push(((word >> 16) & 0xff).to_byte())
    digest.push(((word >> 8) & 0xff).to_byte())
    digest.push((word & 0xff).to_byte())
  }
  Bytes::from_array(digest)
}

///|
/// Computes HMAC-SHA256 over `message` using `key`, returning the 32-byte
/// digest.
pub fn hmac_sha256(key : BytesView, message : BytesView) -> Bytes {
  let block_size = 64
  let mut key_block : Array[Byte] = []
  for byte in key {
    key_block.push(byte)
  }
  if key_block.length() > block_size {
    let hashed = sha256_bytes(Bytes::from_array(key_block))
    key_block = []
    for byte in hashed {
      key_block.push(byte)
    }
  }
  while key_block.length() < block_size {
    key_block.push(0)
  }

  let inner : Array[Byte] = []
  let outer : Array[Byte] = []
  for byte in key_block {
    inner.push(byte ^ 0x36)
    outer.push(byte ^ 0x5c)
  }
  for byte in message {
    inner.push(byte)
  }
  let inner_hash = sha256_bytes(Bytes::from_array(inner))
  for byte in inner_hash {
    outer.push(byte)
  }
  sha256_bytes(Bytes::from_array(outer))
}

///|
/// Returns the lower-case hex encoding of a byte array.
pub fn bytes_to_hex(bytes : BytesView) -> String {
  let digits = "0123456789abcdef"
  let out : StringBuilder = StringBuilder()
  for byte in bytes {
    let value = byte.to_int()
    out.write_string(digits[value / 16:value / 16 + 1].to_owned())
    out.write_string(digits[value % 16:value % 16 + 1].to_owned())
  }
  out.to_string()
}
