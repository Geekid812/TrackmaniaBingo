const string WindowName = Icons::Th + " \\$zBingo";
const string MenuItemName = "\\$ff0" + WindowName;

void Main() {
    startnew(Font::Init);
    startnew(Login::EnsureLoggedIn);
    PersistantStorage::LoadPersistentItems();
    Config::FetchConfig();

    // Plugin was connected to a game when it was forcefully closed or game crashed
    if (WasConnected) {
        Network::Connect();
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
    InfoBar::Render();
    UIMapList::Render();
}

void RenderInterface() {
    UIMainWindow::Render();
    UINews::Render();
    SettingsWindow::Render();
}

void Update(float dt) {
    Game::Tick();
}
