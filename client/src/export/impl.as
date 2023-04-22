namespace TrackmaniaBingo {
    State GetState() {
        if (@Room == null) return Window::Visible ? State::PluginMenu : State::None;
        if (Room.InGame) {
            return Room.EndState.HasEnded() ? State::PostGame : State::InGame;
        }
        return State::InRoom;
    }
}