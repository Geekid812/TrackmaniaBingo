
namespace UIInfoBar {
    // Margin between the board and the "info bar", in pixels
    const int BOARD_MARGIN = 8;
    // Alignment offset of map leaderboard rankings
    const float MAP_LEADERBOARD_SIDE_MARGIN = 35.;

    float subwindowOffset = 0.;

    // Small controls window below the infobar for exiting
    void InfobarControls() {
        vec4 geometry = SubwindowBegin("Bingo Infobar Controls");
        UIColor::LightGray();
        if (@Room !is null) {
            if (UI::Button("Back to room")) {
                @Match = null;
                UIGameRoom::Visible = true;
            }
            UI::SameLine();
        }
        UIColor::Reset();

        if (UI::Button("Exit")) {
            Network::LeaveRoom();
            UIMainWindow::Visible = true;
            startnew(Network::Connect);
        }
        SubwindowEnd(geometry);
    }

    void MapLeaderboard(MapCell map) {
        vec4 geometry = SubwindowBegin("Bingo Map Leaderboard");
        if (map.attemptRanking.Length == 0 && Match.config.targetMedal == Medal::None) {
            UI::Text("\\$888Complete this map to claim it!");
            SubwindowEnd(geometry);
            return;
        }

        for (uint i = 0; i < map.attemptRanking.Length; i++) {
            MapClaim claim = map.attemptRanking[i];
            UI::PushFont(i == 0 ? Font::MonospaceBig : Font::Monospace);
            UI::Text(tostring(i + 1) + ".");
            UI::PopFont();
            UI::SameLine();
            if (i == 0) {
                UI::SetCursorPos(UI::GetCursorPos() + vec2(0, 6));
            }
            UI::PushFont(i == 0 ? Font::Bold : Font::Regular);
            LayoutTools::MoveTo(MAP_LEADERBOARD_SIDE_MARGIN);
            UI::Text(claim.result.Display() + "\t\\$" + UIColor::GetHex(claim.player.team.color) + claim.player.name);
            UI::PopFont();
        }
        if (Match.config.targetMedal != Medal::None) {
            LayoutTools::MoveTo(MAP_LEADERBOARD_SIDE_MARGIN);
            UI::Text(Playground::GetCurrentTimeToBeat(true).Display("$888") + "\tTarget Medal");
        }
        SubwindowEnd(geometry);
    }

    vec4 SubwindowBegin(const string&in name) {
        vec2 parentPos = UI::GetWindowPos();
        vec2 parentSize = UI::GetWindowSize();
        UI::Begin(name, UI::WindowFlags::NoTitleBar | UI::WindowFlags::AlwaysAutoResize | UI::WindowFlags::NoMove);
        return vec4(parentPos, parentSize);
    }

    void SubwindowEnd(vec4 geometry) {
        vec2 parentPos = geometry.xy + vec2(0, subwindowOffset);
        vec2 parentSize = geometry.zw;
        vec2 thisSize = UI::GetWindowSize();
        UI::SetWindowPos(vec2(parentPos.x + (parentSize.x - thisSize.x) / 2., parentPos.y + parentSize.y + BOARD_MARGIN / 2.));
        UI::End();
        subwindowOffset += thisSize.y + BOARD_MARGIN / 2.;
    }

    void Render() {
        if (@Match == null) return;
        
        // Time since the game has started. If we are in countdown, don't show up yet
        int64 stopwatchTime = Time::Milliseconds(@Match);
        MatchPhase phase = Match.GetPhase();
        if (phase == MatchPhase::Starting) return;

        Player@ self = Match.GetSelf();
        Team team;
        if (@self is null) {
            team = Team(0, "", vec3(.5, .5, .5));
        } else {
            team = self.team;
        }
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
            Team@ winningTeam = Match.endState.team;

            if (winningTeam !is null) {
                phaseText = winningTeam.name + " wins!";
                color = UIColor::Brighten(winningTeam.color, 0.7);
            } else {
                uint winningTeamsCount = Match.endState.WinnerTeamsCount();
                phaseText = winningTeamsCount == 0 ? "Tie" : winningTeamsCount + " winners!";
                color = vec3(.5, .5, .5);
            }
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
        if (Match.config.minutesLimit != 0 || Match.config.noBingoMinutes != 0) stopwatchTime = Time::GetMaxTimeMilliseconds(@Match) - stopwatchTime;
        if (phase == MatchPhase::NoBingo) stopwatchTime -= Time::GetTimelimitMilliseconds(@Match);
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
        RunResult@ runToBeat = Playground::GetCurrentTimeToBeat();
        if (@runToBeat != null) {
            MapCell map = Match.GetCurrentMap();
            MapLeaderboard(map);
        }

        UIColor::Gray();
        if (Match.GetPhase() == MatchPhase::Ended) {
            InfobarControls();
        }
        UIColor::Reset();
        UI::PopStyleVar();
        UI::PopFont();

        subwindowOffset = 0.;
        vec2 windowSize = UI::GetWindowSize();
        UI::SetWindowPos(vec2(int(Board::Position.x) + (int(Board::BoardSize) - windowSize.x) / 2, int(Board::Position.y) + int(Board::BoardSize) + BOARD_MARGIN), UI::Cond::Always);
        UI::End();
    }
}