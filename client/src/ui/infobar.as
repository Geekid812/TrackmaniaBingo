
namespace UIInfoBar {
    // Margin between the board and the "info bar", in pixels
    const int BOARD_MARGIN = 8;
    // Alignment offset of map leaderboard rankings
    const float MAP_LEADERBOARD_SIDE_MARGIN = 35.;

    float SubwindowOffset = 0.;
    string MapLeaderboardUid;

    // Small controls window below the infobar for exiting
    void InfobarControls() {
        vec4 geometry = SubwindowBegin("Bingo Infobar Controls");
        UIColor::LightGray();
        if (@Room !is null) {
            if (UI::Button("Back to room")) {
                @Match = null;
                UIGameRoom::Visible = true;

                if (Room.localPlayerIsHost) {
                    // Starting a new game, ask the server to load new maps
                    startnew(Network::ReloadMaps);
                }
            }
            UI::SameLine();
        }
        UIColor::Reset();

        if (UI::Button("Exit")) {
            Gamemaster::Shutdown();
            UIMainWindow::Visible = true;
            startnew(Network::Connect);
        }
        SubwindowEnd(geometry);
    }

    void MapLeaderboard(GameTile map) {
        vec4 geometry = SubwindowBegin("Bingo Map Leaderboard");
        if (map.attemptRanking.Length == 0 && Match.config.targetMedal == Medal::None) {
            UI::Text("\\$888Complete this map to claim it!");
            SubwindowEnd(geometry);
            return;
        }

        for (uint i = 0; i < map.attemptRanking.Length; i++) {
            MapClaim claim = map.attemptRanking[i];
            UI::Text(tostring(i + 1) + ".");
            UI::SameLine();
            if (i == 0) {
                UI::SetCursorPos(UI::GetCursorPos() + vec2(0, 6));
            }

            Font::Style textStyle = Font::Style::Regular;
            if (i == 0) textStyle = Font::Style::Bold;
            Font::Set(textStyle, Font::Size::Medium);

            Layout::MoveTo(MAP_LEADERBOARD_SIDE_MARGIN);
            UI::Text(claim.result.Display());
            UI::SameLine();
            if (i == 0) {
                UI::SetCursorPos(UI::GetCursorPos() + vec2(0, 6));
            }
            UITools::PlayerTag(claim.player);
            Font::Unset();
        }
        if (Match.config.targetMedal != Medal::None) {
            Layout::MoveTo(MAP_LEADERBOARD_SIDE_MARGIN);
            UI::Text(Playground::GetCurrentTimeToBeat(true).Display("$aaa") + "  Target Medal");
        }

        if (!Match.endState.HasEnded()) {
            UI::Separator();
            
            float width = UI::GetWindowSize().x;
            float padding = Layout::GetPadding(width, 72., 0.5);
            Layout::MoveTo(padding);
            UIColor::Custom(Match.GetSelf().team.color);
            if (UI::Button(Icons::Times + " Close")) {
                MapLeaderboardUid = "";
            }
            UIColor::Reset();
        }
        SubwindowEnd(geometry);
    }

    void TimeToBeatDisplay(GameTile cell) {
        vec4 geometry = SubwindowBegin("Bingo Map Info");

        string displayText = "\\$ff8Time to beat: ";
        Team myTeam = Match.GetSelf().team;
        if (cell.IsClaimed()) {
            MapClaim leadingClaim = cell.LeadingRun();
            if (leadingClaim.player.team == myTeam) {
                displayText = "\\$ff8Your team's time: ";
            }
            string claimingText = leadingClaim.result.Display() + " by";

            float claimTextWidth = Math::Max(Draw::MeasureString(claimingText + " " + leadingClaim.player.name).x, UI::GetWindowSize().x);
            Layout::MoveTo(Layout::GetPadding(claimTextWidth, Draw::MeasureString(displayText).x, 0.5));
            UI::Text(displayText);
            UI::Text(claimingText);

            UI::SameLine();
            UI::SetCursorPos(UI::GetCursorPos() - vec2(6., 0.));
            UITools::PlayerTag(leadingClaim.player);

            UI::Separator();
            string buttonText = Icons::ListOl + " Map Records";
            Layout::AlignButton(buttonText, 0.5);
            UIColor::Custom(myTeam.color);
            if (UI::Button(buttonText)) {
                MapLeaderboardUid = Playground::GetCurrentMap().EdChallengeId;
            }
            UIColor::Reset();
        } else {
            RunResult@ baseTimeToBeat = Playground::GetCurrentTimeToBeat();
            if (@baseTimeToBeat !is null && baseTimeToBeat.time != -1) {
                displayText += baseTimeToBeat.Display();
                UI::Text(displayText);
            } else {
                UI::Text("Complete this map to claim it!");
            }
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
        vec2 parentPos = geometry.xy + vec2(0, SubwindowOffset);
        vec2 parentSize = geometry.zw;
        vec2 thisSize = UI::GetWindowSize();
        UI::SetWindowPos(vec2(parentPos.x + (parentSize.x - thisSize.x) / 2., parentPos.y + parentSize.y + BOARD_MARGIN / 2.));
        UI::End();
        SubwindowOffset += thisSize.y + BOARD_MARGIN / 2.;
    }

    void Render() {
        if (!Gamemaster::IsBingoActive()) return;
        
        int64 stopwatchTime = GameTime::CurrentClock();
        string stopwatchPrefix = GameTime::CurrentClockColorPrefix();
        GamePhase phase = Gamemaster::GetPhase();

        // If we are in the countdown at game start, don't show up yet
        if (phase == GamePhase::Starting) return;

        UI::Begin("Board Information", UI::WindowFlags::NoTitleBar | UI::WindowFlags::AlwaysAutoResize | UI::WindowFlags::NoScrollbar | UI::WindowFlags::NoMove);

        // Phase indicator
        string phaseText;
        vec3 color;
        bool animate = true;
        if (phase == GamePhase::NoBingo) {
            phaseText = "Grace Period";
            color = vec3(.7, .6, .2);
            animate = false;
        } else if (phase == GamePhase::Overtime) {
            phaseText = "Overtime";
            color = vec3(.6, .15, .15);
        } else if (phase == GamePhase::Ended) {
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
            float padding = Layout::GetPadding(UI::GetWindowSize().x, size, 0.5);
            vec4 buttonColor = UIColor::GetAlphaColor(color, animate ? (Math::Sin(Time::Now / 500.) + 1.5) / 2. : .8);
            UI::PushStyleColor(UI::Col::Button, buttonColor);
            UI::PushStyleColor(UI::Col::ButtonHovered, buttonColor);
            UI::PushStyleColor(UI::Col::ButtonActive, buttonColor);
            Layout::MoveTo(padding);
            UI::Button(phaseText, vec2(size, 0.));
            UI::PopStyleColor(3);
        }

        Font::Set(Font::Style::Bold, Font::Size::Huge);

        string stopwatchText = Time::Format(stopwatchTime, false, true, true);
        UI::Text(stopwatchPrefix + stopwatchText);

        Font::Unset();
        
        GameTile@ tile = Gamemaster::GetCurrentTile();
        CGameCtnChallenge@ gameMap = Playground::GetCurrentMap();
        if (tile !is null) {
            if (gameMap.EdChallengeId == MapLeaderboardUid || Match.endState.HasEnded()) {
                MapLeaderboard(tile);
            } else {
                TimeToBeatDisplay(tile);
            }
        }

        UIColor::Gray();
        if (phase == GamePhase::Ended) {
            InfobarControls();
        }
        UIColor::Reset();

        SubwindowOffset = 0.;
        vec2 windowSize = UI::GetWindowSize();
        UI::SetWindowPos(vec2(int(Board::Position.x) + (int(Board::BoardSize) - windowSize.x) / 2, int(Board::Position.y) + int(Board::BoardSize) + BOARD_MARGIN), UI::Cond::Always);
        UI::End();
    }
}
