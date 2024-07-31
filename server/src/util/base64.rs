use rand::{distributions::Uniform, prelude::Distribution};

// URL-safe variant of the base64 alphabet
const BASE64_CHARS: [char; 64] = [
    '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i',
    'j', 'k', 'l', 'm', 'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z', 'A', 'B',
    'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U',
    'V', 'W', 'X', 'Y', 'Z', '-', '_',
];

fn generate_with<R: rand::Rng>(mut rng: R, len: usize) -> String {
    let uniform = Uniform::from(0..63);
    let mut s = String::with_capacity(len);
    for _ in 0..len {
        s.push(BASE64_CHARS[uniform.sample(&mut rng)]);
    }
    s
}

pub fn generate(len: usize) -> String {
    // Note: thread_rng() uses a cryptographically secure PRNG. Not what we really need,
    // but using it is more convenient than keeping the state of RNGs around.
    generate_with(rand::thread_rng(), len)
}
