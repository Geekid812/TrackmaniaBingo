
namespace InfoBar {
    // Margin between the board and the "info bar", in pixels
    const int BOARD_MARGIN = 8;

    void Render() {
        if (@Match == null) return;
        
        // Time since the game has started. If we are in countdown, don't show up yet
        int64 stopwatchTime = Time::MillisecondsBounded();
        if (Time::MillisecondsElapsed() < 0) return;

        auto team = Match.GetSelf().team;
        UI::Begin("Board Information", UI::WindowFlags::NoTitleBar | UI::WindowFlags::AlwaysAutoResize | UI::WindowFlags::NoScrollbar | UI::WindowFlags::NoMove);

        MatchPhase phase = Match.GetPhase();
        UI::PushFont(Font::MonospaceBig);
        string colorPrefix;
        switch (phase) {
            case MatchPhase::NoBingo:
                colorPrefix = "\\$dd2";
                break;
            case MatchPhase::Overtime:
                colorPrefix = "\\$e44";
                break;
            case MatchPhase::Ended:
                colorPrefix = "\\$fb0";
                break;
        }

        // If playing with a time limit, timer counts down to 0
        if (Match.config.minutesLimit != 0 || Match.config.noBingoMinutes != 0) stopwatchTime = Time::GetMaxTimeMilliseconds() - stopwatchTime;
        if (phase == MatchPhase::NoBingo) stopwatchTime -= Time::GetTimelimitMilliseconds();
        if (stopwatchTime < 0) stopwatchTime = -stopwatchTime;

        UI::Text(colorPrefix + Time::Format(stopwatchTime, false, true, true));
        UI::PopFont();

        UI::PushFont(Font::Regular);
        UI::SameLine();
        UI::PushStyleVar(UI::StyleVar::FramePadding, vec2(6, 5));
        string mapListText = "Open Map List";
        if (UIMapList::Visible) mapListText = "Close Map List";
        UIColor::Custom(team.color);
        if (UI::Button(mapListText)) {
            UIMapList::Visible = !UIMapList::Visible;
        }
        UIColor::Reset();

        UIColor::Gray();
        if (Match.endState.HasEnded()) {
            UI::SameLine();
            if (UI::Button("Exit")) {
                Network::LeaveRoom();
            }
        }
        UIColor::Reset();
        UI::PopStyleVar();

        if (@Match != null && !Match.endState.HasEnded()) {
            RunResult@ runToBeat = Playground::GetCurrentTimeToBeat();
            if (@runToBeat != null) {
                MapCell map = Match.GetCurrentMap();
                if (runToBeat.time != -1 && (!map.IsClaimed() || map.LeadingRun().player.team != team)) {
                    UI::Text("Time to beat: " + runToBeat.Display());
                } else if (runToBeat.time != -1) {
                    UI::Text("Your team's time: " + runToBeat.Display());
                } else {
                    UI::Text("Complete this map to claim it!");
                }
            }
        }
        UI::PopFont();

        vec2 windowSize = UI::GetWindowSize();
        UI::SetWindowPos(vec2(int(Board::Position.x) + (int(Board::BoardSize) - windowSize.x) / 2, int(Board::Position.y) + int(Board::BoardSize) + BOARD_MARGIN), UI::Cond::Always);
        UI::End();
    }
}