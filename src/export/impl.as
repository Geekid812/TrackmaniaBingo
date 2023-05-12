namespace TrackmaniaBingo {
    State GetState() {
        if (@Room == null) return Window::Visible ? State::PluginMenu : State::None;
        if (Room.InGame) {
            return Room.EndState.HasEnded() ? State::PostGame : State::InGame;
        }
        return State::InRoom;
    }

    bool IsBingoMapActive() {
        return @Playground::GetCurrentTimeToBeat() != null;
    }

    int GetChallengeTargetTime() {
        auto targetRun = Playground::GetCurrentTimeToBeat();
        if (@targetRun == null) return 0;
        return targetRun.Time;
    }
}