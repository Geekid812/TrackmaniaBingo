use rand::{distributions::Uniform, prelude::Distribution, SeedableRng};

const BASE62_CHARS: [char; 62] = [
    '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i',
    'j', 'k', 'l', 'm', 'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z', 'A', 'B',
    'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U',
    'V', 'W', 'X', 'Y', 'Z',
];

pub fn uuid(len: usize) -> String {
    let mut rand = rand::rngs::SmallRng::from_entropy();
    let uniform = Uniform::from(0..25);
    let mut s = String::with_capacity(len);
    for _ in 0..len {
        s.push(BASE62_CHARS[uniform.sample(&mut rand)]);
    }
    s
}
