namespace UIGameRoom {
    bool Visible;
    bool IncludePlayerCountInTitle;
    bool RoomCodeVisible;
    bool RoomCodeHovered;
    bool ClipboardHovered;
    bool ClipboardCopied;
    bool GrabFocus;

    void Render() {
        if (@Room == null) Visible = false;
        if (!Visible) return;

        UI::PushStyleColor(UI::Col::TitleBg, UI::GetStyleColor(UI::Col::WindowBg));
        UI::PushStyleColor(UI::Col::TitleBgActive, UI::GetStyleColor(UI::Col::WindowBg));
        UI::PushStyleVar(UI::StyleVar::WindowTitleAlign, vec2(0.5, 0.5));
        UI::SetNextWindowSize(600, 400, UI::Cond::FirstUseEver);
        bool windowOpen = UI::Begin(Room.config.name + (IncludePlayerCountInTitle ? "\t\\$ffa" + Icons::Users + "  " + PlayerCount() : "") + "###bingoroom", Visible, (GrabFocus ? UI::WindowFlags::NoCollapse : 0));
        if (!Visible && @Match == null) {
            // Room window was closed, should disconnect the player.
            // Ideally show a confirmation dialog here, but the Dialogs framework might get reworked.
            // So for now, the player will get yeeted out.
            Network::LeaveRoom();
            CleanupUI();
            return;
        }
        if (windowOpen) {
            bool gameIsStarting = @Match !is null && Match.GetPhase() == MatchPhase::Starting;
            UI::BeginDisabled(gameIsStarting);
            RenderContent();
            UI::EndDisabled();
            if (gameIsStarting) Countdown();
        }
        IncludePlayerCountInTitle = !windowOpen;
        GrabFocus = false;

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
            StatusTooltip("", Room.players.Length + (Room.players.Length == 1 ? " player" : " players"));
        }
    
        UI::SameLine();
        string roomCodeStatus = StatusLabel((RoomCodeHovered ? "\\$ff8" : "") + Icons::Kenney::Key, RoomCodeVisible ? Room.joinCode : "******");
        UI::Text(roomCodeStatus);
        if (UI::IsItemClicked()) RoomCodeVisible = !RoomCodeVisible;
        RoomCodeHovered = UI::IsItemHovered();
        if (RoomCodeHovered) {
            StatusTooltip("Room Code", RoomCodeVisible ? Room.joinCode : "\\$aaaHidden  (Click to reveal)");
        }
        UI::SameLine();
        UI::Text((ClipboardHovered ? "\\$ff8" : "") + Icons::Clipboard);
        ClipboardHovered = UI::IsItemHovered();
        if (ClipboardHovered) {
            UI::BeginTooltip();
            UI::Text(ClipboardCopied ? "\\$8f8Room code copied!" : "\\$aaaClick to copy room code to clipboard");
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
            UI::SameLine();
            string buttonText = Icons::Cog + " Change Settings";
            float buttonPadding = Layout::GetPadding(windowWidth, Layout::ButtonWidth(buttonText) + 4, 1.0);
            UI::SetCursorPos(vec2(buttonPadding, UI::GetCursorPos().y - 4));
            UIColor::Gray();
            if (UI::Button(buttonText)) {
                SettingsWindow::Visible = !SettingsWindow::Visible;
            }
            UIColor::Reset();
            UI::SetCursorPos(UI::GetCursorPos() - vec2(0, 2));
        }
        UI::Separator();

        string[] roomInfo = MatchConfigInfo(Room.matchConfig);
        string combinedInfo = string::Join(roomInfo, " ");
        float infoPadding = Layout::GetPadding(windowWidth, Draw::MeasureString(combinedInfo).x, 0.5);
        UI::SetCursorPos(vec2(infoPadding, UI::GetCursorPos().y));

        for (uint i = 0; i < roomInfo.Length; i++) {
            UI::Text(roomInfo[i]);

            if (UI::IsItemHovered()) {
                if (i == 0) {
                    StatusTooltip("Grid Size", tostring(Room.matchConfig.gridSize) + "x" + tostring(Room.matchConfig.gridSize));
                } else if (i == 1) {
                    StatusTooltip("Map Selection", stringof(Room.matchConfig.selection));
                } else if (i == 2) {
                    StatusTooltip("Target Medal", stringof(Room.matchConfig.targetMedal));
                } else {
                    StatusTooltip("Time Limit", Room.matchConfig.timeLimit == 0 ? "Disabled" : tostring(Room.matchConfig.timeLimit / 60000) + " minutes");
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
        } else {
            UI::NewLine();
        }
        
        UIPlayers::PlayerTable(Room.teams, Room.players, Room.GetSelf().team, (Room.config.randomize && @Match == null) || Room.matchConfig.freeForAll, true, Room.CanCreateMoreTeams() && @Match is null, Room.CanDeleteTeams());

        LeaveButton();

        if (Room.localPlayerIsHost) {
            UIColor::DarkGreen();
            bool startDisabled = Room.players.Length < 2 && !Settings::DevMode;
            UI::BeginDisabled(startDisabled);
            
            UI::SameLine();
            if (UI::Button(Icons::PlayCircleO + " Start")) {
                startnew(Network::StartMatch);
            }
            UI::EndDisabled();
            UIColor::Reset();
            UITools::ErrorMessage("StartMatch");
        }
    }

    void LeaveButton() {
        UIColor::DarkRed();
        if (UI::Button(Icons::Kenney::Exit + " Leave")) {
            startnew(Network::LeaveRoom);
        }
        UIColor::Reset();
    }

    string[] MatchConfigInfo(MatchConfiguration config) {
        return {
            StatusLabel(Icons::Th, tostring(config.gridSize) + "x" + tostring(config.gridSize)),
            StatusLabel(Icons::Map, config.selection != MapMode::Tags || !MXTags::TagsLoaded() ? tostring(config.selection) : MXTags::GetTag(config.mapTag).name),
            StatusLabel(Icons::Bullseye, stringof(config.targetMedal)),
            StatusLabel(Icons::Hourglass, config.timeLimit == 0 ? "∞" : tostring(config.timeLimit / 60000) + ":" + ((config.timeLimit / 1000 % 60) < 10 ? "0" : "") + tostring(config.timeLimit / 1000 % 60))
        };
    }

    string StatusLabel(const string&in icon, const string&in text) {
        return icon + " \\$z" + text;
    }

    void StatusTooltip(const string&in key, const string&in value) {
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
        if (@Room is null) return "";
        return Room.players.Length + (hasPlayerLimit(Room.config) ? "/" + Room.config.size : "");
    }
}
