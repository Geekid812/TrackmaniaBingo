use crate::gameroom::GameRoom;

pub fn setup_room(room: &mut GameRoom) {
    if !room.config().randomize {
        room.create_team().expect("creating initial 1st team");
        room.create_team().expect("creating initial 2nd team");
    }
}
