namespace UIGameRoom {
    bool Visible;
    bool IncludePlayerCountInTitle;
    bool RoomCodeVisible;
    bool RoomCodeHovered;
    bool ClipboardHovered;
    bool ClipboardCopied;
    bool GrabFocus;
    bool PlayerLabelHovered;
    Player @DraggedPlayer = null;

    void Render() {
        if (@Room == null)
            Visible = false;
        if (!Visible)
            return;

        UI::PushStyleColor(UI::Col::TitleBg, UI::GetStyleColor(UI::Col::WindowBg));
        UI::PushStyleColor(UI::Col::TitleBgActive, UI::GetStyleColor(UI::Col::WindowBg));
        UI::PushStyleVar(UI::StyleVar::WindowTitleAlign, vec2(0.5, 0.5));
        UI::SetNextWindowSize(600, 400, UI::Cond::FirstUseEver);
        bool windowOpen = UI::Begin(Room.config.name +
                                        (IncludePlayerCountInTitle
                                             ? "\t\\$ffa" + Icons::Users + "  " + PlayerCount()
                                             : "") +
                                        "###bingoroom",
                                    Visible,
                                    (GrabFocus ? UI::WindowFlags::NoCollapse : 0) |
                                        (PlayerLabelHovered ? UI::WindowFlags::NoMove : 0));
        if (!Visible && @Match == null) {
            // Room window was closed, should disconnect the player.
            // Ideally show a confirmation dialog here, but the Dialogs framework might get
            // reworked. So for now, the player will get yeeted out.
            @Room = null;
            Network::CloseConnection();
            CleanupUI();
            return;
        }

        PlayerLabelHovered = false;
        if (windowOpen) {
            bool gameIsStarting =
                Gamemaster::IsBingoActive() && Gamemaster::GetPhase() == GamePhase::Starting;
            UI::BeginDisabled(gameIsStarting);
            RenderContent();
            UI::EndDisabled();
            if (gameIsStarting)
                Countdown();
        }
        IncludePlayerCountInTitle = !windowOpen;
        GrabFocus = false;
        if (!UI::IsMouseDown()) {
            if (@DraggedPlayer !is null) {
                Player @playerOldState = Room.GetPlayer(DraggedPlayer.profile.uid);
                if (@playerOldState !is null && playerOldState.team.id != DraggedPlayer.team.id) {
                    // Player was dragged to a new team, request an update
                    NetParams::TeamSelectId = DraggedPlayer.team.id;
                    NetParams::PlayerSelectUid = DraggedPlayer.profile.uid;
                    startnew(Network::ChangePlayerTeam);
                    playerOldState.team = DraggedPlayer.team;
                }
            }

            @DraggedPlayer = null;
        }

        CleanupUI();
    }

    void CleanupUI() {
        UI::End();
        UI::PopStyleVar();
        UI::PopStyleColor(2);
    }

    void RenderContent() {
        string playerStatus = StatusLabel(Icons::Users + " ", UIGameRoom::PlayerCount());
        UI::Text(playerStatus);
        if (UI::IsItemHovered()) {
            StatusTooltip(
                "", Room.players.Length + (Room.players.Length == 1 ? " player" : " players"));
        }

        UI::SameLine();
        string roomCodeStatus = StatusLabel((RoomCodeHovered ? "\\$ff8" : "") + Icons::Kenney::Key,
                                            RoomCodeVisible ? Room.joinCode : "******");
        UI::Text(roomCodeStatus);
        if (UI::IsItemClicked())
            RoomCodeVisible = !RoomCodeVisible;
        RoomCodeHovered = UI::IsItemHovered();
        if (RoomCodeHovered) {
            StatusTooltip("Room Code",
                          RoomCodeVisible ? Room.joinCode : "\\$aaaHidden  (Click to reveal)");
        }
        UI::SameLine();
        UI::Text((ClipboardHovered ? "\\$ff8" : "") + Icons::Clipboard);
        ClipboardHovered = UI::IsItemHovered();
        if (ClipboardHovered) {
            UI::BeginTooltip();
            UI::Text(ClipboardCopied ? "\\$8f8Room code copied!"
                                     : "\\$aaaClick to copy room code to clipboard");
            UI::EndTooltip();
        }
        if (UI::IsItemClicked()) {
            IO::SetClipboard(Room.joinCode);
            ClipboardCopied = true;
        } else if (!ClipboardHovered) {
            ClipboardCopied = false;
        }

        float windowWidth = UI::GetWindowSize().x;
        if (Room.localPlayerIsHost) {
            // Change settings button
            UI::SameLine();

            string buttonText = Icons::Cog + " Change Settings";
            float buttonPadding =
                Layout::GetPadding(windowWidth, Layout::ButtonWidth(buttonText) + 8, 1.0);
            UI::SetCursorPos(vec2(buttonPadding, UI::GetCursorPos().y - 4));
            UIColor::Gray();
            if (UI::Button(buttonText)) {
                UIEditSettings::Visible = !UIEditSettings::Visible;
            }
            UIColor::Reset();

            UI::SetCursorPos(UI::GetCursorPos() - vec2(0, 2));
        }
        UI::Separator();

        string[] roomInfo = MatchConfigInfo(Room.matchConfig);
        string combinedInfo = string::Join(roomInfo, " ");
        float infoPadding =
            Layout::GetPadding(windowWidth, Draw::MeasureString(combinedInfo).x, 0.5);
        UI::SetCursorPos(vec2(infoPadding, UI::GetCursorPos().y));

        for (uint i = 0; i < roomInfo.Length; i++) {
            UI::Text(roomInfo[i]);

            if (UI::IsItemHovered()) {
                if (i == 0) {
                    StatusTooltip("Grid Size",
                                  tostring(Room.matchConfig.gridSize) + "x" +
                                      tostring(Room.matchConfig.gridSize));
                } else if (i == 1) {
                    StatusTooltip("Map Selection", stringof(Room.matchConfig.selection));
                } else if (i == 2) {
                    StatusTooltip("Target Medal", stringof(Room.matchConfig.targetMedal));
                } else {
                    StatusTooltip("Time Limit",
                                  Room.matchConfig.timeLimit == 0
                                      ? "Disabled"
                                      : tostring(Room.matchConfig.timeLimit / 60000) + " minutes");
                }
            }

            UI::SameLine();
        }
        UI::NewLine();

        if (Room.config.randomize) {
            if (Room.localPlayerIsHost) {
                UI::BeginDisabled(!Room.CanDeleteTeams());
                if (UI::Button(Icons::MinusSquare)) {
                    NetParams::DeletedTeamId = Room.teams[0].id;
                    startnew(Network::DeleteTeam);
                }
                UI::EndDisabled();

                UI::SameLine();
                UI::BeginDisabled(!Room.CanCreateMoreTeams());
                if (UI::Button(Icons::PlusSquare)) {
                    startnew(Network::CreateTeam);
                }
                UI::EndDisabled();
                UI::SameLine();
            }

            UI::Text("\\$ff8Number of teams: \\$z" + Room.teams.Length);
        } else if (Room.config.hostControl) {
            UI::Text("\\$ff8" + Icons::Lock + " \\$zThe host controls the team setup.");
        } else {
            UI::NewLine();
        }

        UIPlayers::PlayerTable(Room.teams,
                               Room.players,
                               Room.GetSelf().team,
                               (Room.config.randomize && !Gamemaster::IsBingoActive()),
                               !Room.config.hostControl,
                               Room.CanCreateMoreTeams(),
                               Room.CanDeleteTeams(),
                               Room.localPlayerIsHost,
                               DraggedPlayer);

        // Quit early if we disconnected from the room
        if (LeaveButton())
            return;

        if (Room.localPlayerIsHost) {
            UIColor::DarkGreen();
            bool isSolo = Room.players.Length < 2;

            UI::SameLine();
            if (UI::Button(Icons::PlayCircleO + " Start")) {
                startnew(Network::StartMatch);
            }

            if (isSolo) {
                UI::SetItemTooltip(
                    "\\$ff8Warning: \\$zA minimum of 2 players is recommended to start the "
                    "game.\nMatch statistics will not be saved when playing solo.");
            }

            UIColor::Reset();
            UITools::ErrorMessage("StartMatch");
        }
    }

    bool LeaveButton() {
        bool hasDisconnected = false;

        UIColor::DarkRed();
        if (UI::Button(Icons::Kenney::Exit + " Leave")) {
            @Room = null;
            Gamemaster::Shutdown();
            hasDisconnected = true;

            // Reopen the connection if the main window is open
            if (UIMainWindow::Visible) {
                startnew(Network::Connect);
            }
        }

        UIColor::Reset();
        return hasDisconnected;
    }

    string[] MatchConfigInfo(MatchConfiguration config) {
        return {StatusLabel(Icons::Th, tostring(config.gridSize) + "x" + tostring(config.gridSize)),
                StatusLabel(Icons::Map,
                            config.selection != MapMode::Tags || !MXTags::TagsLoaded()
                                ? tostring(config.selection)
                                : MXTags::GetTag(config.mapTag).name),
                StatusLabel(Icons::Bullseye, stringof(config.targetMedal)),
                StatusLabel(Icons::Hourglass,
                            config.timeLimit == 0
                                ? "∞"
                                : tostring(config.timeLimit / 60000) + ":" +
                                      ((config.timeLimit / 1000 % 60) < 10 ? "0" : "") +
                                      tostring(config.timeLimit / 1000 % 60))};
    }

    string StatusLabel(const string& in icon, const string& in text) {
        return icon + " \\$z" + text;
    }

    void StatusTooltip(const string& in key, const string& in value) {
        UI::BeginTooltip();
        if (key != "") {
            UI::Text(key + ":");
            UI::SameLine();
        }
        UI::Text(value);
        UI::EndTooltip();
    }

    void Countdown() {
        vec2 windowSize = UI::GetWindowSize();
        int secondsRemaining = (Match.startTime - Time::Now) / 1000 + 1;
        string countdownText = "Game starting in " + secondsRemaining + "...";
        vec2 textSize = Draw::MeasureString(countdownText, Font::Current());
        float padding = Layout::GetPadding(windowSize.x, textSize.x, 1.0);
        vec4 textColor = UI::GetStyleColor(UI::Col::Text);
        float margin = 16;

        int sinTimeValue = Match.startTime - Time::Now - 250;
        float alphaValue = sinTimeValue * 2. * Math::PI;
        textColor.w = (Math::Sin(alphaValue / 1000.) + 1) / 1.6;

        UI::SetCursorPos(vec2(padding - margin, windowSize.y - textSize.y - margin));
        UI::PushStyleColor(UI::Col::Text, textColor);
        UI::Text(countdownText);
        UI::PopStyleColor();
    }

    string PlayerCount() {
        if (@Room is null)
            return "";
        return Room.players.Length + (hasPlayerLimit(Room.config) ? "/" + Room.config.size : "");
    }

    void SwitchToPlayContext() {
        UIMainWindow::Visible = false;
        UIGameRoom::Visible = false;
        UIMapList::Visible = true;
        UIEditSettings::Visible = false;
        UITeamEditor::Visible = false;
    }
}
