const string WindowName = Icons::Th + " \\$zBingo";
const string MenuItemName = "\\$ff0" + WindowName;

void Main() {
    startnew(Font::Init);
    startnew(Login::EnsureLoggedIn);
    PersistantStorage::LoadPersistentItems();
    Config::FetchConfig();

    // Plugin was connected to a game when it was forcefully closed or game crashed
    if (PersistantStorage::LastConnectedMatchId != "") {
        trace("Main: Plugin was previously connected, attempting to reconnect.");
        Network::Connect();

        if (Network::IsConnected()) {
            NetParams::MatchJoinUid = PersistantStorage::LastConnectedMatchId;
            startnew(Network::Reconnect);
        }
    }

    // We are interested in roomlist notifications, so we should connect
    if (PersistantStorage::SubscribeToRoomUpdates) {
        trace("Main: Player is subscribed to roomlist updates, connecting to the servers.");
        Network::Connect();
        UIRoomMenu::RoomsLoad = LoadStatus::Loading;
        startnew(Network::GetPublicRooms);
    }

    while (true) {
        Network::Loop();
        yield();
    }
}

void RenderMenu() {
    if (UI::MenuItem(MenuItemName, "", UIMainWindow::Visible)) {
        UIMainWindow::Visible = !UIMainWindow::Visible;
        // Connect to server when opening plugin window the first time
        if (UIMainWindow::Visible && Network::GetState() == ConnectionState::Closed) {
            trace("Main: Plugin window opened, connecting to the servers.");
            startnew(Network::Connect);
        }
    }
}

void Render() {
    UIGameRoom::Render();
    BoardLocator::Render();
    Board::Draw();
    UIInfoBar::Render();
    UIMapList::Render();
    UIPaintColor::Render();
    UITeams::Render();
    SettingsWindow::Render();
}

void RenderInterface() {
    UIMainWindow::Render();
    UINews::Render();
    UIDailyHistory::Render();
}

void Update(float dt) {
    Game::Tick();
}
