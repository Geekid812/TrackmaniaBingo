const string WindowName = Icons::Th + " \\$zBingo";
const string MenuItemName = "\\$ff0" + WindowName;
const string DeveloperMenuItemName = "\\$82a" + Icons::Th + " \\$zDeveloper Tools";

#if TMNEXT
const GamePlatform CurrentGame = GamePlatform::Next;
#elif TURBO
const GamePlatform CurrentGame = GamePlatform::Turbo;
#endif

void Main() {
    Font::Init();
    startnew(Login::EnsureLoggedIn);
    PersistantStorage::LoadPersistentItems();
    Config::FetchConfig();

    // Plugin was connected to a game when it was forcefully closed or game crashed
    if (PersistantStorage::LastConnectedMatchId != "") {
        trace("Main: Plugin was previously connected, attempting to reconnect.");
        Network::Connect();

        if (Network::IsConnected()) {
            NetParams::MatchJoinUid = PersistantStorage::LastConnectedMatchId;
            NetParams::MatchJoinTeamId = PersistantStorage::LastConnectedMatchTeamId;
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

    if (Settings::DevTools && UI::MenuItem(DeveloperMenuItemName, "", UIDevActions::Visible)) {
        UIDevActions::Visible = !UIDevActions::Visible;
    }
}

void Render() {
    if (!UI::IsGameUIVisible()) return;
    if (!Font::Initialized) return;
    Font::Set(Font::Style::Regular, 20);

    UIGameRoom::Render();
    BoardLocator::Render();
    Board::Draw();
    UIInfoBar::Render();
    UIMapList::Render();
    UIPaintColor::Render();
    UITeams::Render();
    SettingsWindow::Render();
    UIMapSelect::Render();
    UIChat::Render();

    for (uint i = 0; i < Polls.Length; i++) {
        UIPoll::RenderPoll(Polls[i], i);
    }

    if (Settings::DevTools) {
        UIDownloads::Render();
    }

    Font::Unset();
}

void RenderInterface() {
    if (!Font::Initialized) return;
    Font::Set(Font::Style::Regular, 20);

    UIMainWindow::Render();
    UINews::Render();
    UIDailyHistory::Render();
    UIDevActions::Render();

    Font::Unset();
}

UI::InputBlocking OnKeyPress(bool down, VirtualKey key) {
    return UIChat::OnKeyPress(down, key);
}

void Update(float dt) {
    if (@Match !is null) Game::Tick();
}
