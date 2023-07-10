
namespace UIInfoBar {
    // Margin between the board and the "info bar", in pixels
    const int BOARD_MARGIN = 8;

    void Render() {
        if (@Match == null) return;
        
        // Time since the game has started. If we are in countdown, don't show up yet
        int64 stopwatchTime = Time::Milliseconds();
        MatchPhase phase = Match.GetPhase();
        if (phase == MatchPhase::Starting) return;

        auto team = Match.GetSelf().team;
        UI::Begin("Board Information", UI::WindowFlags::NoTitleBar | UI::WindowFlags::AlwaysAutoResize | UI::WindowFlags::NoScrollbar | UI::WindowFlags::NoMove);

        UI::PushFont(Font::MonospaceBig);
        string colorPrefix;
        switch (phase) {
            case MatchPhase::NoBingo:
                colorPrefix = "\\$fe6";
                break;
            case MatchPhase::Overtime:
                colorPrefix = "\\$e44+";
                break;
            case MatchPhase::Ended:
                colorPrefix = "\\$fb0";
                break;
        }

        // Phase indicator
        string phaseText;
        vec3 color;
        bool animate = true;
        if (phase == MatchPhase::NoBingo) {
            phaseText = "Grace Period";
            color = vec3(.7, .6, .2);
            animate = false;
        } else if (phase == MatchPhase::Overtime) {
            phaseText = "Overtime";
            color = vec3(.6, .15, .15);
        } else if (phase == MatchPhase::Ended) {
            Team winningTeam = Match.endState.team;
            phaseText = winningTeam.name + " wins!";
            color = UIColor::Brighten(winningTeam.color, 0.7);
        }
        if (phaseText != "" && !UI::IsWindowAppearing()) {
            float sideMargins = UI::GetStyleVarVec2(UI::StyleVar::WindowPadding).x * 2.;
            float size = UI::GetWindowSize().x - sideMargins;
            float padding = LayoutTools::GetPadding(UI::GetWindowSize().x, size, 0.5);
            vec4 buttonColor = UIColor::GetAlphaColor(color, animate ? (Math::Sin(Time::Now / 500.) + 1.5) / 2. : .8);
            UI::PushFont(Font::Bold);
            UI::PushStyleColor(UI::Col::Button, buttonColor);
            UI::PushStyleColor(UI::Col::ButtonHovered, buttonColor);
            UI::PushStyleColor(UI::Col::ButtonActive, buttonColor);
            LayoutTools::MoveTo(padding);
            UI::Button(phaseText, vec2(size, 0.));
            UI::PopStyleColor(3);
            UI::PopFont();
        }

        // If playing with a time limit, timer counts down to 0
        if (Match.config.minutesLimit != 0 || Match.config.noBingoMinutes != 0) stopwatchTime = Time::GetMaxTimeMilliseconds() - stopwatchTime;
        if (phase == MatchPhase::NoBingo) stopwatchTime -= Time::GetTimelimitMilliseconds();
        if (stopwatchTime < 0) stopwatchTime = -stopwatchTime;
        if (phase == MatchPhase::Overtime) stopwatchTime = Time::Now - Match.overtimeStartTime;

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