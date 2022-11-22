
namespace Window {
    bool Visible;
    bool JoinCodeVisible;
    bool RoomCodeVisible;

    void Render() {
        if (!Visible) return;
        UI::Begin(WindowName, Visible);

        if (!Permissions::PlayLocalMap()) {
            NoPermissions();
            UI::End();
            return;
        }

        if (Settings::DevMode) {
            DevControls();
            UI::Separator();
        }

        if (Room.InGame) {
            InGame();
            UI::End();
            return;
        }

        bool Disabled = false;
        if (StartCountdown > 0) {
            Countdown();
            Disabled = true;
        }
        if (Network::RequestInProgress) {
            Disabled = true;
        }
        if (Disabled) UI::BeginDisabled();

        if (Room.Active) {
            RoomView();
        } else {
            UI::BeginTabBar("Bingo_TabBar");

            if (UI::BeginTabItem("Join Room")) {
                JoinTab();
                UI::EndTabItem();
            }

            if (UI::BeginTabItem("Create Room")) {
                CreateTab();
                UI::EndTabItem();
            }

            if (UI::BeginTabItem(Icons::QuestionCircle + " How to play")) {
                TutorialTab();
                UI::EndTabItem();
            }

            UI::EndTabBar();
        }

        if (Disabled) UI::EndDisabled();
        UI::End();
    }

    void CreateTab() {
        Room.MaxPlayers = Math::Clamp(UI::InputInt("Room Size", Room.MaxPlayers), 2, 32);
        
        if (UI::BeginCombo("Map Selection", stringof(Room.MapSelection))) {
            if (UI::Selectable(stringof(MapMode::TOTD), Room.MapSelection == MapMode::TOTD)) {
                Room.MapSelection = MapMode::TOTD;
            }

            if (UI::Selectable(stringof(MapMode::MXRandom), Room.MapSelection == MapMode::MXRandom)) {
                Room.MapSelection = MapMode::MXRandom;
            }

            UI::EndCombo();
        }

        if (UI::BeginCombo("Target Medal", stringof(Room.TargetMedal))) {
            if (UI::Selectable(stringof(Medal::Author), Room.TargetMedal == Medal::Author)) {
                Room.TargetMedal = Medal::Author;
            }

            if (UI::Selectable(stringof(Medal::Gold), Room.TargetMedal == Medal::Gold)) {
                Room.TargetMedal = Medal::Gold;
            }

            if (UI::Selectable(stringof(Medal::Silver), Room.TargetMedal == Medal::Silver)) {
                Room.TargetMedal = Medal::Silver;
            }
            if (UI::Selectable(stringof(Medal::Bronze), Room.TargetMedal == Medal::Bronze)) {
                Room.TargetMedal = Medal::Bronze;
            }
            if (UI::Selectable(stringof(Medal::None), Room.TargetMedal == Medal::None)) {
                Room.TargetMedal = Medal::None;
            }

            UI::EndCombo();
        }

        if (UI::Button("Create Room")) {
            startnew(Network::CreateRoom);
        }
    }

    void JoinTab() {
        Room.JoinCode = UI::InputText("Room Code", Room.JoinCode, false, UI::InputTextFlags::CharsUppercase | (JoinCodeVisible? 0 : UI::InputTextFlags::Password));
        UI::SameLine();
        JoinCodeVisible = UI::Checkbox("Show code", JoinCodeVisible);
        if (UI::Button("Join Room") && Room.JoinCode.Length >= 6) {
            startnew(Network::JoinRoom);
        }
    }

    void TutorialTab() {
        UI::PushFont(Font::Header);
        UI::Text("Welcome to the Trackmania Bingo!");
        UI::PopFont();

        UI::TextWrapped("In this mode, two or more teams compete be the first to complete a row, column or diagonal on the game board. Each cell on this board corresponds to a track that players can claim for their team by achieving a specific medal on that track.");
        UI::TextWrapped("Once a track has been claimed, in order to reclaim it, other teams must beat the time that was set on that track. Try to play strategically to be the first team to achieve a bingo!");
        UI::Text("Good luck and have fun!");
        UI::TextDisabled("Mode created by TheGeekid");
    }

    void RoomView() {
        UI::Text(Room.HostName + (Room.HostName.EndsWith("s") ? "'": "'s") + " Bingo Room - " + Room.Players.Length + "/" + Room.MaxPlayers + " players");
        UI::SameLine();
        UIColor::DarkRed();
        if (UI::Button(Icons::Kenney::Exit + " Leave")) {
            startnew(Network::LeaveRoom);
        }
        UIColor::Reset();

        if (Room.LocalPlayerIsHost) {
            UIColor::DarkGreen();
            bool StartDisabled = (Room.Players.Length < 2 && !Settings::DevMode) || Room.MapsLoadingStatus != LoadStatus::LoadSuccess;
            if (StartDisabled) UI::BeginDisabled();
            
            UI::SameLine();
            if (UI::Button(Icons::PlayCircleO + " Start")) {
                startnew(Network::StartGame);
            }
            if (StartDisabled) UI::EndDisabled();
            UIColor::Reset();
        }
        if (Room.MapsLoadingStatus != LoadStatus::LoadSuccess) {
            if (Room.MapsLoadingStatus == LoadStatus::Loading) {
                UI::Text("\\$ff0" + Icons::HourglassHalf + " \\$zFetching maps from TMX...");
            } else {
                UI::Text("\\$ff0" + Icons::ExclamationTriangle + " \\$ff6Maps could not be loaded from TMX. The game cannot be started.");
            }
        } else {
            UI::Text(""); // Blank space to avoid layout shifts
        }

        UI::Text("\\$ff0Map Selection: \\$z" + stringof(Room.MapSelection));
        UI::Text("\\$ff0Target Medal: \\$z" + stringof(Room.TargetMedal));

        UI::Text("\\$ff0Room Code: \\$z" + (RoomCodeVisible ? Room.JoinCode : "######"));
        UI::SameLine();
        if (UI::Button(RoomCodeVisible ? "Hide" : "Show")) RoomCodeVisible = !RoomCodeVisible;
        UI::SameLine();
        if (UI::Button(Icons::Clipboard + " Copy")) IO::SetClipboard(Room.JoinCode);

        UI::BeginTable("Bingo_TeamTable", Room.Teams.Length + (Room.MoreTeamsAvaliable()? 1 : 0));

        for (uint i = 0; i < Room.Teams.Length; i++) {
            UI::TableNextColumn();
            Team@ Team = Room.Teams[i];
            UIColor::Custom(UIColor::Brighten(Team.Color, 0.75));
            int teamIdXdd = Team.Id;
            if (UI::Button("Join##" + Team.Id)) startnew(function(ref@ team) { Network::JoinTeam(cast<Team>(team)); }, Team);
            UI::SameLine();
            UI::Text("\\$" + UIColor::GetHex(Team.Color) + Team.Name);
            UIColor::Reset();
        }

        if (Room.MoreTeamsAvaliable()) {
            UI::TableNextColumn();
            if (UI::Button("Create+")) {
                startnew(function() { Network::CreateTeam(); });
            }
        }

        uint RowIndex = 0;
        while (true){
            // Iterate forever until no players in any team remain
            UI::TableNextRow();
            uint FinishedTeams = 0;
            for (uint i = 0; i < Room.Teams.Length; i++){
                // Iterate through all teams
                UI::TableNextColumn();
                Team Team = Room.Teams[i];
                Player@ Player = PlayerCell(Team, RowIndex);
                if (Player is null) { // No more players in this team
                    FinishedTeams += 1;
                    continue;
                }
                else {
                    UI::Text((Player.IsSelf ? "\\$ff8" : "") + (RowIndex + 1) + ". " + Player.Name);
                }
            }
            if (FinishedTeams == Room.Teams.Length) break;
            RowIndex += 1;
        }
        UI::EndTable();
    }

    void Countdown() {
        UI::PushFont(Font::Header);
        int SecondsRemaining = StartCountdown / 1000 + 1;
        UI::Text("Game starting in " + SecondsRemaining + "...");
        UI::PopFont();
        UI::NewLine();
        UI::Separator();
    }

    void InGame() {
        UI::Text("A game is already running! Close this window and keep playing!");
        if (UI::Button(Icons::Kenney::Exit + " Leave Game")) {
            startnew(Network::LeaveRoom);
        }
    }

    void NoPermissions() {
        UI::TextWrapped("Unfortunately, you do not have permission to play this gamemode.");
        UI::TextWrapped("Playing Bingo requires having at least \\$999Standard Access\\$z, which you do not seem to have. Sorry!");
        UI::TextWrapped("If you believe this is a mistake, make sure to restart your game and check your internet connection.");
    }

    void DevControls() {
        if (UI::Button(Icons::Signal + " Force Disconnect")) {
            startnew(Network::OnDisconnect);
        }
    }
}

// Helper function to build the table
Player@ PlayerCell(Team team, int index) {
    int Count = 0;
    for (uint i = 0; i < Room.Players.Length; i++) {
        auto Player = Room.Players[i];
        if (Player.Team == team) {
            if (Count == index) return Player;
            else Count += 1;
        }
    }
    return null;
}
