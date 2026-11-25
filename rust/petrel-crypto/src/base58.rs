//! Base58 with the Bitcoin alphabet, used by multikeys and `did:key`.

use crate::error::PetrelCryptoError;

/// Maximum input length accepted by [`Base58BTC::decode`].
const MAX_DECODE_LEN: usize = 256;

/// Base58 with the Bitcoin alphabet (no multibase prefix).
#[derive(Debug, Clone, Copy)]
#[allow(clippy::upper_case_acronyms)]
pub struct Base58BTC;

impl Base58BTC {
    /// Encodes bytes as base58btc (no multibase prefix). Each leading zero
    /// byte becomes one leading `'1'`.
    pub fn encode(data: &[u8]) -> String {
        if data.is_empty() {
            return String::new();
        }
        bs58::encode(data)
            .with_alphabet(bs58::Alphabet::BITCOIN)
            .into_string()
    }

    /// Decodes base58btc (no multibase prefix). Each leading `'1'` becomes one
    /// leading zero byte.
    ///
    /// Rejects empty strings, strings longer than 256 bytes, and characters
    /// outside the Bitcoin Base58 alphabet.
    pub fn decode(value: &str) -> Result<Vec<u8>, PetrelCryptoError> {
        if value.is_empty() || value.len() > MAX_DECODE_LEN {
            return Err(PetrelCryptoError::InvalidIdentifier(
                "base58btc value".into(),
            ));
        }
        bs58::decode(value)
            .with_alphabet(bs58::Alphabet::BITCOIN)
            .into_vec()
            .map_err(|_| PetrelCryptoError::InvalidIdentifier("base58btc value".into()))
    }
}
