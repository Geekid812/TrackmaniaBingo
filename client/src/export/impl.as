namespace TrackmaniaBingo {
    State GetState() {
        if (@Match != null) return Match.endState.HasEnded() ? State::PostGame : State::InGame;
        if (@Room != null) return State::InRoom;
        return UIMainWindow::Visible ? State::PluginMenu : State::None;
    }
}