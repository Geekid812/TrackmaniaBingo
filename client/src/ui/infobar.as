
namespace UIInfoBar {
    // Margin between the board and the "info bar", in pixels
    const int BOARD_MARGIN = 8;
    // Alignment offset of map leaderboard rankings
    const float MAP_LEADERBOARD_SIDE_MARGIN = 35.;
    // Size in pixels of the powerup thumbnail
    const float POWERUP_FRAME_SIZE = 24.;

    float SubwindowOffset = 0.;
    string MapLeaderboardUid;
    bool Visible = true;

    // Small controls window below the infobar for exiting
    void PostgameControls() {
        vec4 geometry = SubwindowBegin("Bingo Infobar Controls");
        UIColor::LightGray();
        if (@Room !is null) {
            if (UI::Button("Back to room")) {
                Gamemaster::SetBingoActive(false);
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
            Player @claimingPlayer = claim.player;
            UI::Text(tostring(i + 1) + ".");
            UI::SameLine();

            Font::Style textStyle = Font::Style::Regular;
            if (i == 0)
                textStyle = Font::Style::Bold;
            Font::Set(textStyle, Font::Size::Medium);

            Layout::MoveTo(MAP_LEADERBOARD_SIDE_MARGIN);
            UI::Text(claim.result.Display());
            UI::SameLine();
            UITools::PlayerTag(claimingPlayer);

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
        Player @localPlayer = Match.GetSelf();
        Team myTeam = (@localPlayer != null ? localPlayer.team : Team(-1, "", vec3()));
        if (cell.HasRunSubmissions()) {
            MapClaim leadingClaim = cell.LeadingRun();
            if (leadingClaim.teamId == myTeam.id) {
                displayText = "\\$ff8Your team's time: ";
            }
            string claimingText = leadingClaim.result.Display() + " by";

            float claimTextWidth =
                Math::Max(Draw::MeasureString(claimingText + " " + leadingClaim.player.name).x,
                          UI::GetWindowSize().x);
            Layout::MoveTo(
                Layout::GetPadding(claimTextWidth, Draw::MeasureString(displayText).x, 0.5));
            UI::Text(displayText);
            UI::Text(claimingText);

            Player @topPlayer = leadingClaim.player;
            UI::SameLine();
            UI::SetCursorPos(UI::GetCursorPos() - vec2(6., 0.));
            UITools::PlayerTag(topPlayer);

            UI::Separator();
            string buttonText = Icons::ListOl + " Map Records";
            Layout::AlignButton(buttonText, 0.5);
            UIColor::Custom(myTeam.color);
            if (UI::Button(buttonText)) {
                MapLeaderboardUid = Playground::GetCurrentMap().EdChallengeId;
            }
            UIColor::Reset();
        } else {
            RunResult @baseTimeToBeat = Playground::GetCurrentTimeToBeat();
            if (@baseTimeToBeat !is null && baseTimeToBeat.time != -1) {
                displayText += baseTimeToBeat.Display();
                UI::Text(displayText);
            } else {
                UI::Text("Complete this map to claim it!");
            }
        }

        SubwindowEnd(geometry);
    }

    vec4 SubwindowBegin(const string& in name) {
        vec2 parentPos = UI::GetWindowPos();
        vec2 parentSize = UI::GetWindowSize();
        UI::Begin(name,
                  UI::WindowFlags::NoTitleBar | UI::WindowFlags::AlwaysAutoResize |
                      UI::WindowFlags::NoMove);
        return vec4(parentPos, parentSize);
    }

    void SubwindowEnd(vec4 geometry) {
        vec2 parentPos = geometry.xy + vec2(0, SubwindowOffset);
        vec2 parentSize = geometry.zw;
        vec2 thisSize = UI::GetWindowSize();
        UI::SetWindowPos(vec2(parentPos.x + (parentSize.x - thisSize.x) / 2.,
                              parentPos.y + parentSize.y + BOARD_MARGIN / 2.));
        UI::End();
        SubwindowOffset += thisSize.y + BOARD_MARGIN / 2.;
    }

    void Render() {
        if (!Visible)
            return;
        if (!Gamemaster::IsBingoActive())
            return;

        int64 stopwatchTime = GameTime::CurrentClock();
        string stopwatchPrefix = GameTime::CurrentClockColorPrefix();
        GamePhase phase = Gamemaster::GetPhase();

        // If we are in the countdown at game start, don't show up yet
        if (phase == GamePhase::Starting)
            return;

        UI::Begin("Board Information",
                  UI::WindowFlags::NoTitleBar | UI::WindowFlags::AlwaysAutoResize |
                      UI::WindowFlags::NoScrollbar | UI::WindowFlags::NoMove);

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
            Team @winningTeam = Match.endState.team;

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
            NoticeFrame(phaseText, color, animate);
        }

        for (uint i = 0; i < Gamemaster::GetTileCount(); i++) {
            if (Match.tiles[i] is null)
                continue;
            switch (Match.tiles[i].specialState) {
            case TileItemState::Rally:
                NoticeFrame("Rally - " +
                                Time::Format(Match.tiles[i].stateTimeDeadline - Time::Now, false),
                            Board::RALLY_COLOR,
                            true);
                break;
            case TileItemState::Jail:
                if (int(Match.tiles[i].statePlayerTarget.uid) == Profile.uid) {
                    NoticeFrame(
                        "Jailed - " +
                            Time::Format(Match.tiles[i].stateTimeDeadline - Time::Now, false),
                        vec3(.6, .2, .2),
                        true);
                }
                break;
            }
        }

        Font::Set(Font::Style::Bold, Font::Size::Huge);
        string stopwatchText = stopwatchPrefix + Time::Format(stopwatchTime, false, true, true);

        if (Match.config.mode == Gamemode::Frenzy) {
            UI::Text(stopwatchText);
            Font::Unset();

            UI::SameLine();
            FrenzyItemSelectSlot();
        } else {
            Layout::AlignText(stopwatchText, 0.5);
            UI::Text(stopwatchText);
            Font::Unset();
        }

        GameControls();

        GameTile @tile = Gamemaster::GetCurrentTile();
        CGameCtnChallenge @gameMap = Playground::GetCurrentMap();
        if (tile !is null) {
            if (gameMap.EdChallengeId == MapLeaderboardUid || Match.endState.HasEnded()) {
                MapLeaderboard(tile);
            } else {
                TimeToBeatDisplay(tile);
            }
        }

        UIColor::Gray();
        if (phase == GamePhase::Ended) {
            PostgameControls();
        }
        UIColor::Reset();

        SubwindowOffset = 0.;
        vec2 windowSize = UI::GetWindowSize();
        UI::SetWindowPos(vec2(int(Board::Position.x) + (int(Board::BoardSize) - windowSize.x) / 2,
                              int(Board::Position.y) + int(Board::BoardSize) + BOARD_MARGIN),
                         UI::Cond::Always);
        UI::End();
    }

    void NoticeFrame(const string& in text, vec3 color, bool animated) {
        float sideMargins = UI::GetStyleVarVec2(UI::StyleVar::WindowPadding).x * 2.;
        float size = UI::GetWindowSize().x - sideMargins;
        float padding = Layout::GetPadding(UI::GetWindowSize().x, size, 0.5);
        vec4 buttonColor =
            UIColor::GetAlphaColor(color, animated ? (Math::Sin(Time::Now / 500.) + 1.5) / 2. : .8);
        UI::PushStyleColor(UI::Col::Button, buttonColor);
        UI::PushStyleColor(UI::Col::ButtonHovered, buttonColor);
        UI::PushStyleColor(UI::Col::ButtonActive, buttonColor);
        Layout::MoveTo(padding);
        UI::Button(text, vec2(size, 0.));
        UI::PopStyleColor(3);
    }

    void FrenzyItemSelectSlot() {
        UI::PushStyleColor(UI::Col::Border,
                           UIItemSelect::Visible ? vec4(1., .8, .2, .9) : vec4(.5, .5, .5, .9));
        UI::BeginChild("Bingo Item Select Slot",
                       vec2(),
                       UI::ChildFlags::Borders | UI::ChildFlags::AutoResizeX |
                           UI::ChildFlags::AutoResizeY);

        Player @localPlayer = (Gamemaster::IsBingoActive() ? Match.GetSelf() : null);
        Powerup myPowerup = (@localPlayer !is null ? localPlayer.holdingPowerup : Powerup::Empty);

        if (myPowerup != Powerup::Empty) {
            UI::Image(Powerups::GetPowerupTexture(myPowerup),
                      vec2(POWERUP_FRAME_SIZE, POWERUP_FRAME_SIZE));
        } else {
            UI::Dummy(POWERUP_FRAME_SIZE, POWERUP_FRAME_SIZE);
        }

        UI::PushStyleColor(UI::Col::Border, vec4());
        if (UI::BeginItemTooltip()) {
            UI::Text("\\$ff5Item Slot");

            switch (myPowerup) {
            case Powerup::RowShift:
                UI::Text("Row Shift\nShift all tiles on a row of the Bingo board one step in any "
                         "direction!");
                break;
            case Powerup::ColumnShift:
                UI::Text("Column Shift\nShift all tiles on a column of the Bingo board one step in "
                         "any direction!");
                break;
            case Powerup::Rally:
                UI::Text("Rally\nStart a rally on a map of your choice.\nWhichever team has the "
                         "record there after 10 minutes will claim all adjacent tiles!");
                break;
            case Powerup::Jail:
                UI::Text(
                    "Jail\nSend a player you choose to any map of the Bingo board.\nThey will "
                    "remain emprisoned there for 10 minutes until they can claim a new record!");
                break;
            case Powerup::RainbowTile:
                UI::Text("Rainbow Tile\nTransform any map into a rainbow tile,\nwhich counts as if "
                         "all teams had claimed it!\nCan't be used to immediately create a\nbingo line.");
                break;
            case Powerup::GoldenDice:
                UI::Text(
                    "Golden Dice\nReroll any map of your choice (keeps the current team "
                    "color).\nAll players can vote for one of three maps that will replace it!");
                break;
            default:
                UI::TextDisabled("You don't have any item to use right now.");
                break;
            }

            if (myPowerup != Powerup::Empty) {
                UI::Text("\\$ff8Expires in " +
                         Time::Format(localPlayer.powerupExpireTimestamp - Time::Now, false));
            }

            UI::EndTooltip();
        }
        UI::PopStyleColor();

        UI::EndChild();
        UI::PopStyleColor();

        UIItemSelect::Powerup = myPowerup;
        if (myPowerup != Powerup::Empty && UI::IsItemClicked()) {
            UIItemSelect::Visible = !UIItemSelect::Visible;

            // Also close the map list picker to avoid players getting confused by having a duplicated map selector
            UIMapList::Visible = false;
        }
    }

    void GameControls() {
        Player @self = Match.GetSelf();
        Team team;
        if (@self is null) {
            team = Team(0, "", vec3(.5, .5, .5));
        } else {
            team = self.team;
        }
        UI::PushStyleVar(UI::StyleVar::FramePadding, vec2(6, 5));
        UIColor::Custom(team.color);
        if (UI::Button(Icons::Map + " Map Grid")) {
            UIMapList::Visible = !UIMapList::Visible;
        }
        UI::SameLine();
        UIColor::Reset();
        UIColor::Custom(UIColor::Brighten(team.color, 0.6));
        if (UI::Button("Teams")) {
            UITeams::Visible = !UITeams::Visible;
        }
        UIColor::Reset();
        UI::PopStyleVar();
    }
}
