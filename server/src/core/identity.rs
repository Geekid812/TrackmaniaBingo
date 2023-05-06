use std::hash::Hash;

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PlayerIdentity {
    pub account_id: String,
    pub display_name: String,
}

impl Hash for PlayerIdentity {
    fn hash<H: std::hash::Hasher>(&self, state: &mut H) {
        self.account_id.hash(state);
    }
}
