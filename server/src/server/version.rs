use std::cmp::{Ord, Ordering, PartialOrd};
use std::convert::TryFrom;

#[derive(Eq, PartialEq)]
pub struct Version(pub i32, pub i32);

impl TryFrom<String> for Version {
    type Error = ();

    fn try_from(mut value: String) -> Result<Self, Self::Error> {
        if let Some((prefix, _)) = value.split_once('-') {
            value = prefix.to_owned();
        }
        let mut version_iter = value.split('.');
        let major = version_iter.next().ok_or(())?.parse().map_err(|_| ())?;
        let minor = version_iter.next().ok_or(())?.parse().map_err(|_| ())?;
        if version_iter.next().is_some() {
            return Err(());
        }
        Ok(Self(major, minor))
    }
}

impl PartialOrd for Version {
    fn partial_cmp(&self, other: &Self) -> Option<Ordering> {
        Some(self.cmp(other))
    }
}

impl Ord for Version {
    fn cmp(&self, other: &Self) -> Ordering {
        self.0.cmp(&other.0).then(self.1.cmp(&other.1))
    }
}

#[cfg(test)]
mod test {
    use super::*;

    #[test]
    fn check_version_cmp() {
        let v0 = Version(0, 3);
        let v1 = Version(1, 0);
        let v1next = Version(1, 1);

        assert!(v0 < v1);
        assert!(v1 < v1next);
        assert!(v1next > v0);
    }
}
