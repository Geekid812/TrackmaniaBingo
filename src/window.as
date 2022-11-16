
namespace Window {
    const bool CanAlwaysStart = true; // Debug constant 
    bool Visible;
    bool RoomCodeVisible;

    void Render() {
        if (!Visible) return;
        UI::Begin(WindowName, Visible);

        if (Room.InGame) {
            InGame();
            UI::End();
            return;
        }

        if (!Permissions::PlayLocalMap()) {
            NoPermissions();
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
        Room.JoinCode = UI::InputText("Room Code", Room.JoinCode);
        if (UI::Button("Join Room") && Room.JoinCode.Length >= 6) {
            startnew(Network::JoinRoom);
        }
    }

    void TutorialTab() {
        UI::PushFont(Font::Header);
        UI::Text("Welcome to the Trackmania Bingo!");
        UI::PopFont();

        UI::TextWrapped("In this mode, two teams compete be the first to complete a row, column or diagonal on the game board. Each cell on this board corresponds to a track that players can claim for their team by achieving a specific medal on that track.");
        UI::TextWrapped("Once a track has been claimed, in order to reclaim it, other teams must beat the time that was set on that track. Try to play strategically to be the first team to achieve a bingo!");
        UI::Text("Good luck and have fun!");
        UI::TextDisabled("Mode created by TheGeekid");
    }

    void RoomView() {
        UI::Text(Room.HostName + (Room.HostName.EndsWith("s") ? "'": "'s") + " Bingo Room - " + Room.Players.Length + "/" + Room.MaxPlayers + " players");
        UI::SameLine();
        UIColor::DarkRed();
        if (UI::Button(Icons::Kenney::Exit + " Leave")) {
            Network::Reset();
        }
        UIColor::Reset();

        if (Room.LocalPlayerIsHost) {
            UIColor::DarkGreen();
            bool StartDisabled = (Room.Players.Length < 2 && !CanAlwaysStart) || !Room.MapsLoaded;
            if (StartDisabled) UI::BeginDisabled();
            
            UI::SameLine();
            if (UI::Button(Icons::PlayCircleO + " Start")) {
                startnew(Network::StartGame);
            }
            if (!Room.MapsLoaded){
                UI::EndDisabled();
                StartDisabled = false;
                UI::SameLine();
                UI::Text("\\$fffFetching maps from tmx...");
            }
            if (StartDisabled) UI::EndDisabled();
            UIColor::Reset();
        }

        UI::Text("\\$ff0Map Selection: \\$z" + stringof(Room.MapSelection));
        UI::Text("\\$ff0Target Medal: \\$z" + stringof(Room.TargetMedal));

        UI::Text("\\$ff0Room Code: \\$z" + (RoomCodeVisible ? Room.JoinCode : "######"));
        UI::SameLine();
        if (UI::Button(RoomCodeVisible ? "Hide" : "Show")) RoomCodeVisible = !RoomCodeVisible;
        UI::SameLine();
        if (UI::Button(Icons::Clipboard + " Copy")) IO::SetClipboard(Room.JoinCode);

        UI::BeginTable("Bingo_TeamTable", 2);

        UI::TableNextColumn();
        UIColor::Red();
        if (UI::Button("Join##red")) { startnew(function() { Network::JoinTeam(0); }); }
        UI::SameLine();
        UI::Text("\\$f44Red Team");
        UIColor::Reset();

        UI::TableNextColumn();
        UIColor::Blue();
        if (UI::Button("Join##blue")) { startnew(function() { Network::JoinTeam(1); }); }
        UI::SameLine();
        UI::Text("\\$44fBlue Team");
        UIColor::Reset();

        bool RedCompleted = false;
        bool BlueCompleted = false;
        int Row = 0;
        while (!RedCompleted || !BlueCompleted) {
            UI::TableNextRow();

            UI::TableNextColumn();
            if (!RedCompleted) {
                try {
                    auto Player = PlayerCell(0, Row);
                    UI::Text((Player.IsSelf ? "\\$ff8" : "") + Player.Name);
                } catch {
                    RedCompleted = true;
                }
            }

            UI::TableNextColumn();
            if (!BlueCompleted) {
                try {
                    auto Player = PlayerCell(1, Row);
                    UI::Text((Player.IsSelf ? "\\$ff8" : "") + Player.Name);
                } catch {
                    BlueCompleted = true;
                }
            }
            Row += 1;
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
            Network::Reset();
            Room.Active = false;
        }
    }

    void NoPermissions() {
        UI::TextWrapped("Unfortunately, you do not have permission to play this gamemode.");
        UI::TextWrapped("Playing Bingo requires having at least \\$999Standard Access\\$z, which you do not seem to have. Sorry!");
        UI::TextWrapped("If you believe this is a mistake, make sure to restart your game and check your internet connection.");
    }
}

// Helper function to build the table
Player PlayerCell(int Team, int Index) {
    int Count = 0;
    for (uint i = 0; i < Room.Players.Length; i++) {
        auto Player = Room.Players[i];
        if (Player.Team == Team) {
            if (Count == Index) return Player;
            else Count += 1;
        }
    }

    throw("not found");
    return Player();
}
