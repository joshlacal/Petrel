use crate::error::CARError;

/// Maximum unsigned value permitted in canonical CAR varints (63 bits = `i64::MAX`).
pub const MAX_CAR_VARINT: u64 = i64::MAX as u64;

/// Decodes a canonical unsigned LEB128 varint from the front of `bytes`.
///
/// Enforces AT Protocol / Swift `CARReader` & `PublicRepositoryCAR` strictness:
/// - At most 9 bytes (`i64::MAX` fits in 63 bits = 9 * 7 bits)
/// - No trailing zero byte in multi-byte encodings (`non-canonical`)
/// - Value `<= i64::MAX`
pub fn decode(bytes: &[u8]) -> Result<(u64, usize), CARError> {
    let mut value: u64 = 0;
    let mut shift: u32 = 0;
    for (idx, &byte) in bytes.iter().enumerate() {
        if idx >= 9 {
            return Err(CARError::VarintOverflow);
        }
        let low = u64::from(byte & 0x7f);
        if idx == 8 && (byte & 0x80) != 0 {
            return Err(CARError::VarintOverflow);
        }
        value |= low << shift;
        if (byte & 0x80) == 0 {
            if idx > 0 && byte == 0 {
                return Err(CARError::NonCanonicalVarint);
            }
            if value > MAX_CAR_VARINT {
                return Err(CARError::VarintOverflow);
            }
            return Ok((value, idx + 1));
        }
        shift += 7;
    }
    Err(CARError::Truncated)
}

/// Encodes `value` into canonical unsigned LEB128 varint bytes inside `out`.
pub fn encode_into(mut value: u64, out: &mut [u8; 9]) -> Result<usize, CARError> {
    if value > MAX_CAR_VARINT {
        return Err(CARError::VarintOverflow);
    }
    let mut len = 0;
    loop {
        let mut byte = (value & 0x7f) as u8;
        value >>= 7;
        if value != 0 {
            byte |= 0x80;
        }
        out[len] = byte;
        len += 1;
        if value == 0 {
            return Ok(len);
        }
    }
}

/// Appends the canonical unsigned varint representation of `value` to `dest`.
pub fn push_varint(value: u64, dest: &mut Vec<u8>) -> Result<(), CARError> {
    let mut buf = [0_u8; 9];
    let len = encode_into(value, &mut buf)?;
    dest.extend_from_slice(&buf[..len]);
    Ok(())
}
