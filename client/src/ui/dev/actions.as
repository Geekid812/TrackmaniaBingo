namespace UIDevActions {
    bool Visible;

    void Render() {
        if (!Visible) return;
        UI::Begin(DEVELOPER_WINDOW_NAME, Visible);

        UI::BeginTabBar("bingodev_tabs");

        if (UI::BeginTabItem(Icons::Bug + " Actions")) {
            ClientTokenControl();
            DummyGameLauncher();

            UI::EndTabItem();
        }

        if (UI::BeginTabItem(Icons::Font + " Fonts")) {
            UIDevFonts::RenderFontMatrix();
            
            UI::EndTabItem();
        }

        UI::EndTabBar();

        UI::End();
    }

    void ClientTokenControl() {
        PersistantStorage::ClientToken = UI::InputText("Client Token", PersistantStorage::ClientToken);
        UI::SameLine();
        if (UI::Button("Clear")) {
            PersistantStorage::ClientToken = "";
        };
    }

    void DummyGameLauncher() {
        if (UI::Button(Icons::PlayCircle + " Launch Dummy Game")) {
            trace("[UIDevActions::DummyGameLauncher] Starting a dummy Bingo game.");
            Gamemaster::ResetAll();

            Gamemaster::SetBingoActive(true);
            Gamemaster::SetStartTime(Time::Now);
            Gamemaster::SetPhase(GamePhase::Running);

            UIDevActions::Visible = false;
        }
    }
}
