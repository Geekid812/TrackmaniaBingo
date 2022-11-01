
namespace InfoBar {
    // Margin between the board and the "info bar", in pixels
    const int BoardMargin = 8;

    uint64 StartTime;
    bool SettingsOpen;

    void Render() {
        if (!Room.InGame) return;

        float u = Board::Unit();
        UI::SetNextWindowPos(int(Board::Position.x * u), int(Board::Position.y * u) + int(Board::Width * u) + BoardMargin, UI::Cond::Always);
        UI::SetNextWindowSize(int(Board::Width * u), 42, UI::Cond::Always);
        UI::Begin("Board Information", UI::WindowFlags::NoTitleBar | UI::WindowFlags::AlwaysAutoResize);
        
        UI::PushFont(Font::Monospace);
        if (Room.EndState.EndTime == 0) {
            UI::Text(Time::Format(Time::Now - StartTime, false, true, true));
        } else {
            UI::Text("\\$fb0" + Time::Format(Room.EndState.EndTime - StartTime, false, true, true));
        }
        UI::PopFont();

        UI::SameLine();
        UI::PushStyleVar(UI::StyleVar::FramePadding, vec2(6, 5));
        string MapListText = "Open Map List";
        if (MapList::Visible) MapListText = "Close Map List";
        if (UI::Button(MapListText)) {
            MapList::Visible = !MapList::Visible;
        }

        UIColor::Gray();
        if (Room.EndState.BingoDirection != BingoDirection::None && UI::Button("Exit")) {
            Network::Reset();
        }
        UIColor::Reset();

        UI::PopStyleVar();


        UI::End();
    }
}