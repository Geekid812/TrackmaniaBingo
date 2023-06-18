
namespace UIGameRoom {
    bool Visible;
    bool IncludePlayerCount;
    bool RoomCodeVisible;
    bool RoomCodeHovered;
    bool ClipboardHovered;
    bool ClipboardCopied;

    void Render() {
        if (@Room == null) Visible = false;
        if (!Visible) return;

        UI::PushStyleColor(UI::Col::TitleBg, UI::GetStyleColor(UI::Col::WindowBg));
        UI::PushStyleColor(UI::Col::TitleBgActive, UI::GetStyleColor(UI::Col::WindowBg));
        UI::PushStyleVar(UI::StyleVar::WindowTitleAlign, vec2(0.5, 0.5));
        UI::PushFont(Font::Bold);
        UI::SetNextWindowSize(600, 400, UI::Cond::Always);
        bool windowOpen = UI::Begin(Room.config.name + (IncludePlayerCount ? "\t\\$ffa" + Icons::Users + "  " + PlayerCount() : "") + "###bingoroom", Visible, UI::WindowFlags::NoResize);
        if (windowOpen) {
            UI::PushFont(Font::Regular);
            RenderContent();
            UI::PopFont();
        }
        IncludePlayerCount = !windowOpen;

        UI::End();
        UI::PopFont();
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
        UI::PushFont(Font::Monospace);
        UI::Text(roomCodeStatus);
        UI::PopFont();
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

        UI::SameLine();
        float windowWidth = UI::GetWindowSize().x;

        if (Room.localPlayerIsHost) {
            UI::SameLine();
            float buttonPadding = LayoutTools::GetPadding(windowWidth, 150, 1.0);
            UI::SetCursorPos(vec2(buttonPadding, UI::GetCursorPos().y - 4));
            UIColor::Gray();
            if (UI::Button(Icons::Cog + " Change Settings")) {
                SettingsWindow::Visible = !SettingsWindow::Visible;
            }
            UIColor::Reset();
            UI::SetCursorPos(UI::GetCursorPos() - vec2(0, 2));
        }
        UI::Separator();

        string[] roomInfo = MatchConfigInfo(Room.matchConfig);
        string combinedInfo = string::Join(roomInfo, " ");
        float infoPadding = LayoutTools::GetPadding(windowWidth, Draw::MeasureString(combinedInfo).x, 0.5);
        UI::SetCursorPos(vec2(infoPadding, UI::GetCursorPos().y));

        for (uint i = 0; i < roomInfo.Length; i++) {
            UI::Text(roomInfo[i]);

            if (UI::IsItemHovered()) {
                if (i == 0) {
                    StatusTooltip("Grid Size", tostring(Room.matchConfig.gridSize) + "x" + tostring(Room.matchConfig.gridSize));
                } else if (i == 1) {
                    StatusTooltip("Map Selection", stringof(Room.matchConfig.mapSelection));
                } else if (i == 2) {
                    StatusTooltip("Target Medal", stringof(Room.matchConfig.targetMedal));
                } else {
                    StatusTooltip("Time Limit", Room.matchConfig.minutesLimit == 0 ? "Disabled" : tostring(Room.matchConfig.minutesLimit) + " minutes");
                }
            }

            UI::SameLine();
        }
        UI::NewLine();
        UI::NewLine();

        UI::BeginTable("Bingo_TeamTable", Room.teams.Length + (Room.CanCreateMoreTeams() ? 1 : 0));

        for (uint i = 0; i < Room.teams.Length; i++) {
            UI::TableNextColumn();
            Team@ team = Room.teams[i];

            float seperatorSize = UI::GetContentRegionMax().x - UI::GetCursorPos().x - 50;
            UI::BeginChild("bingoteamsep" + i, vec2(seperatorSize, UI::GetTextLineHeightWithSpacing() + 4));
            UI::PushFont(Font::Bold);
            UI::Text("\\$" + UIColor::GetHex(team.color) + team.name);
            UI::PopFont();

            UI::PushStyleColor(UI::Col::Separator, UIColor::GetAlphaColor(team.color, .8));
            UI::Separator();
            UI::PopStyleColor();
            UI::EndChild();

            if (UI::IsItemHovered()) {
                UI::BeginTooltip();
                UI::Text("\\$" + UIColor::GetHex(team.color) + team.name + " Team" + (Room.GetSelf().team != team ? "  \\$888(Click to join)" : ""));
                UI::EndTooltip();
            }

            if (UI::IsItemClicked()) {
                startnew(function(ref@ team) { Network::JoinTeam(cast<Team>(team)); }, team);
            }
        }

        if (Room.CanCreateMoreTeams()) {
            UI::TableNextColumn();
            if (UI::Button(Icons::PlusSquare + " Create team")) {
                startnew(Network::CreateTeam);
            }
        }

        uint rowIndex = 0;
        while (true) {
            // Iterate forever until no players in any team remain
            UI::TableNextRow();
            uint finishedTeams = 0;
            for (uint i = 0; i < Room.teams.Length; i++){
                // Iterate through all teams
                UI::TableNextColumn();
                Player@ player = PlayerCell(Room.teams[i], rowIndex);
                if (player is null) { // No more players in this team
                    finishedTeams += 1;
                    continue;
                }
                else {
                    UI::Text((player.isSelf ? "\\$ff8" : "") + (rowIndex + 1) + ". " + player.name);
                }
            }
            if (finishedTeams == Room.teams.Length) break;
            rowIndex += 1;
        }
        UI::EndTable();

        UIColor::DarkRed();
        if (UI::Button(Icons::Kenney::Exit + " Leave")) {
            startnew(Network::LeaveRoom);
        }
        UIColor::Reset();

        if (Room.localPlayerIsHost) {
            UIColor::DarkGreen();
            bool startDisabled = Room.players.Length < 2 && !Settings::DevMode;
            startDisabled = false; // Dev override
            UI::BeginDisabled(startDisabled);
            
            UI::SameLine();
            if (UI::Button(Icons::PlayCircleO + " Start")) {
                startnew(Network::StartMatch);
            }
            UI::EndDisabled();
            UIColor::Reset();
        }

        // Leave room if window was closed
        //if (!Visible) Network::LeaveRoom();
    }

    string[] MatchConfigInfo(MatchConfiguration config) {
        return {
            StatusLabel(Icons::Th, tostring(config.gridSize) + "x" + tostring(config.gridSize)),
            StatusLabel(Icons::Map, tostring(config.mapSelection)),
            StatusLabel(Icons::Bullseye, stringof(config.targetMedal)),
            StatusLabel(Icons::Hourglass, config.minutesLimit == 0 ? "∞" : tostring(config.minutesLimit) + ":00")
        };
    }

    string StatusLabel(const string&in icon, const string&in text) {
        return icon + " \\$z" + text;
    }

    void StatusTooltip(const string&in key, const string&in value) {
        UI::BeginTooltip();
        if (key != "") {
            UI::PushFont(Font::Bold);
            UI::Text(key + ":");
            UI::PopFont();
            UI::SameLine();
        }
        UI::Text(value);
        UI::EndTooltip();
    }

    void Countdown() {
        if (@Match == null) return;
        UI::PushFont(Font::Header);
        int secondsRemaining = (Match.startTimestamp + COUNTDOWN_TIME - Time::Now) / 1000 + 1;
        UI::Text("Game starting in " + secondsRemaining + "...");
        UI::PopFont();
        UI::NewLine();
        UI::Separator();
    }

    string PlayerCount() {
        return Room.players.Length + (Room.config.hasPlayerLimit ? "/" + Room.config.maxPlayers : "");
    }

    // Helper function to build the table
    Player@ PlayerCell(Team team, int index) {
        int count = 0;
        for (uint i = 0; i < Room.players.Length; i++) {
            auto player = Room.players[i];
            if (player.team == team) {
                if (count == index) return player;
                else count += 1;
            }
        }
        return null; 
    }
}
