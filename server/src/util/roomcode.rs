use rand::{distributions::Uniform, prelude::Distribution};

use crate::config::{JOINCODE_CHARS, JOINCODE_LENGTH};

pub fn generate_roomcode() -> String {
    let mut rng = rand::thread_rng();
    let uniform = Uniform::from(0..JOINCODE_CHARS.len());
    (0..JOINCODE_LENGTH)
        .map(|_| JOINCODE_CHARS[uniform.sample(&mut rng)])
        .collect()
}
