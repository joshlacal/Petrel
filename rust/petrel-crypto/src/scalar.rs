//! Fixed-width big-endian scalar arithmetic for P-256 and secp256k1 group orders.
//!
//! Single home of the low-S rule `s <= floor(n / 2)`. Half-orders are derived at
//! compile time by a one-bit right shift of `n` rather than duplicated as literals.

use std::cmp::Ordering;

use crate::curve::ATProtoKeyCurve;

pub(crate) const SCALAR_BYTE_COUNT: usize = 32;
pub(crate) const COMPACT_SIGNATURE_BYTE_COUNT: usize = 64;

/// NIST P-256 (`secp256r1`) group order, FIPS 186-4 D.1.2.3.
const P256_ORDER: [u8; 32] = [
    0xff, 0xff, 0xff, 0xff, 0x00, 0x00, 0x00, 0x00, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
    0xbc, 0xe6, 0xfa, 0xad, 0xa7, 0x17, 0x9e, 0x84, 0xf3, 0xb9, 0xca, 0xc2, 0xfc, 0x63, 0x25, 0x51,
];

/// `secp256k1` group order, SEC 2 v2 section 2.4.1.
const K256_ORDER: [u8; 32] = [
    0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xfe,
    0xba, 0xae, 0xdc, 0xe6, 0xaf, 0x48, 0xa0, 0x3b, 0xbf, 0xd2, 0x5e, 0x8c, 0xd0, 0x36, 0x41, 0x41,
];

const P256_HALF_ORDER: [u8; 32] = shifted_right_by_one(P256_ORDER);
const K256_HALF_ORDER: [u8; 32] = shifted_right_by_one(K256_ORDER);

const fn shifted_right_by_one(value: [u8; 32]) -> [u8; 32] {
    let mut result = [0_u8; 32];
    let mut carry = 0_u8;
    let mut index = 0;
    while index < 32 {
        result[index] = (value[index] >> 1) | (carry << 7);
        carry = value[index] & 1;
        index += 1;
    }
    result
}

pub(crate) const fn order(curve: ATProtoKeyCurve) -> [u8; 32] {
    match curve {
        ATProtoKeyCurve::P256 => P256_ORDER,
        ATProtoKeyCurve::Secp256k1 => K256_ORDER,
    }
}

pub(crate) const fn half_order(curve: ATProtoKeyCurve) -> [u8; 32] {
    match curve {
        ATProtoKeyCurve::P256 => P256_HALF_ORDER,
        ATProtoKeyCurve::Secp256k1 => K256_HALF_ORDER,
    }
}

fn compare(lhs: &[u8], rhs: &[u8; 32]) -> Ordering {
    for (&left, &right) in lhs.iter().zip(rhs.iter()) {
        match left.cmp(&right) {
            Ordering::Equal => {}
            non_eq => return non_eq,
        }
    }
    Ordering::Equal
}

/// Returns `true` iff `0 < scalar < n`.
pub(crate) fn is_valid(scalar: &[u8], curve: ATProtoKeyCurve) -> bool {
    scalar.len() == SCALAR_BYTE_COUNT
        && scalar.iter().any(|&byte| byte != 0)
        && compare(scalar, &order(curve)) == Ordering::Less
}

/// Returns `true` iff `scalar` is 32 bytes and `scalar <= floor(n / 2)`.
pub(crate) fn is_low(scalar: &[u8], curve: ATProtoKeyCurve) -> bool {
    scalar.len() == SCALAR_BYTE_COUNT && compare(scalar, &half_order(curve)) != Ordering::Greater
}

/// Computes `n - scalar`. Caller must have proven `0 < scalar < n`.
pub(crate) fn negated(scalar: &[u8], curve: ATProtoKeyCurve) -> [u8; 32] {
    let minuend = order(curve);
    let mut result = [0_u8; 32];
    let mut borrow: i16 = 0;
    for index in (0..SCALAR_BYTE_COUNT).rev() {
        let mut value = i16::from(minuend[index]) - i16::from(scalar[index]) - borrow;
        if value < 0 {
            value += 256;
            borrow = 1;
        } else {
            borrow = 0;
        }
        #[allow(clippy::cast_possible_truncation, clippy::cast_sign_loss)]
        {
            result[index] = value as u8;
        }
    }
    debug_assert_eq!(borrow, 0);
    result
}

/// Returns `true` iff `compact` is 64 bytes with `0 < r < n` and `0 < s < n`.
pub(crate) fn is_structurally_valid(compact: &[u8], curve: ATProtoKeyCurve) -> bool {
    compact.len() == COMPACT_SIGNATURE_BYTE_COUNT
        && is_valid(&compact[..SCALAR_BYTE_COUNT], curve)
        && is_valid(&compact[SCALAR_BYTE_COUNT..], curve)
}

/// Folds a structurally valid compact signature to its low-S twin.
pub(crate) fn low_s_form(compact: &[u8; 64], curve: ATProtoKeyCurve) -> [u8; 64] {
    if is_low(&compact[SCALAR_BYTE_COUNT..], curve) {
        return *compact;
    }
    let mut out = *compact;
    let folded_s = negated(&compact[SCALAR_BYTE_COUNT..], curve);
    out[SCALAR_BYTE_COUNT..].copy_from_slice(&folded_s);
    out
}
