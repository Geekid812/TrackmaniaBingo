use rand::{distributions::Uniform, prelude::Distribution};

pub const JOINCODE_LENGTH: u32 = 6;
pub const JOINCODE_CHARS: [char; 10] = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];

pub fn generate_roomcode() -> String {
    let mut rng = rand::thread_rng();
    let uniform = Uniform::from(0..JOINCODE_CHARS.len());
    (0..JOINCODE_LENGTH)
        .map(|_| JOINCODE_CHARS[uniform.sample(&mut rng)])
        .collect()
}
