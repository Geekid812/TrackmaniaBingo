use serde::Serialize;
use std::num::ParseIntError;
use thiserror::Error;

#[derive(Serialize, PartialEq, Eq, Debug, Clone, Copy)]
pub struct RgbColor(pub u8, pub u8, pub u8);

impl RgbColor {
    pub fn from_hex(col: &str) -> Result<Self, ParseColorError> {
        let size = col.len();
        if size != 6 {
            return Err(ParseColorError::LengthError(size));
        }
        let r = u8::from_str_radix(&col[0..2], 16)?;
        let g = u8::from_str_radix(&col[2..4], 16)?;
        let b = u8::from_str_radix(&col[4..6], 16)?;
        Ok(Self(r, g, b))
    }

    pub fn red(&self) -> u8 {
        self.0
    }
    pub fn green(&self) -> u8 {
        self.1
    }
    pub fn blue(&self) -> u8 {
        self.2
    }
}

#[derive(Error, Debug)]
pub enum ParseColorError {
    #[error("Expected string of length 6, got {0} instead")]
    LengthError(usize),

    #[error(transparent)]
    ParseIntError(#[from] ParseIntError),
}

#[cfg(test)]
mod test {
    use super::*;

    #[test]
    fn check_color_hex() {
        let green = RgbColor(0, 255, 0);
        let green_hex = RgbColor::from_hex("00FF00").unwrap();
        assert_eq!(green, green_hex);
    }
}
