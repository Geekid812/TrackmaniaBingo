const string WindowName = Icons::Th + " \\$zBingo";
const string MenuItemName = "\\$ff0" + WindowName;

void Main() {
    Font::Init();
    Config::FetchConfig();
    ProtocolExample();
} 

void ProtocolExample() {
    auto prot = Protocol();
    HandshakeData handshake = HandshakeData();
    handshake.ClientVersion = Meta::ExecutingPlugin().Version;
    auto AuthReq = Auth::GetToken();
    while (!AuthReq.Finished()) { yield(); }
    handshake.AuthToken = AuthReq.Token();
    prot.Connect("localhost", 6600, handshake);
}

void RenderMenu() {
    if (UI::MenuItem(MenuItemName, "", Window::Visible)) {
        Window::Visible = !Window::Visible;
    }
}

void Render() {
    BoardLocator::Render();
    Board::Draw();
    InfoBar::Render();
    MapList::Render();
}

void RenderInterface() {
    Window::Render();
}

void Update(float dt) {
    Tick(int(dt));
}

void OnDestroyed() {
    Network::EventStream.Close();
}