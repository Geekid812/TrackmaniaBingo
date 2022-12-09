namespace MapList {
    const string WindowName = Icons::Th + " \\$zMap List";
    bool Visible;

    void Render() {
        if (!Visible || Room.MapList.IsEmpty() || (!Room.InGame && !Room.EndState.HasEnded())) return;

        UI::Begin(WindowName, Visible, UI::WindowFlags::AlwaysAutoResize | UI::WindowFlags::NoCollapse);
        auto DrawList = UI::GetWindowDrawList();

        UI::PushStyleVar(UI::StyleVar::CellPadding, Settings::TinyBoard ? vec2(4, 4) : vec2(8, 8));
        UI::PushStyleVar(UI::StyleVar::ItemSpacing, vec2(2, 2));
        if (Settings::TinyBoard) UI::PushStyleVar(UI::StyleVar::FramePadding, vec2(4, 4));
        UI::PushStyleColor(UI::Col::TableBorderLight, vec4(.6, .6, .6, 1.));
        UI::PushStyleColor(UI::Col::TableBorderStrong, vec4(1., 1., 1., 1.));
        UI::BeginTable("Bingo_MapList", 5, UI::TableFlags::SizingFixedFit | UI::TableFlags::Borders);

        if (Settings::TinyBoard) UI::PushFont(Font::Tiny);
        for (uint i = 0; i < Room.MapList.Length; i++) {
            auto Map = Room.MapList[i];
            UI::TableNextColumn();

            auto StartPos = UI::GetCursorPos() + UI::GetWindowPos() - vec2(8, 7);

            vec2 ThumbnailSize = vec2(200, 145);
            if (Settings::TinyBoard) ThumbnailSize = vec2(100, 72);
            if (@Map.MapImage.m_texture != null) {
                UI::Image(Map.MapImage.m_texture, ThumbnailSize);
            } else if (@Map.Thumbnail.m_texture != null) {
                UI::Image(Map.Thumbnail.m_texture, ThumbnailSize);
            } else {
                UI::Dummy(ThumbnailSize);
            }
            UI::PushStyleVar(UI::StyleVar::CellPadding, vec2(2, 2));
            UI::BeginTable("Bingo_Map" + i, 2, UI::TableFlags::SizingFixedFit);
            UI::TableSetupColumn("", UI::TableColumnFlags::None, Settings::TinyBoard ? 70 : 135);
            UI::TableSetupColumn("", UI::TableColumnFlags::None, Settings::TinyBoard ? 30 : 65);
            UI::TableNextColumn();
            UI::Text(Map.Name);

            if (Map.ClaimedRun.Time != -1) {
                UI::TextDisabled(Settings::TinyBoard ? Map.ClaimedRun.DisplayTime() : Map.ClaimedRun.Display());
            } else {
                UI::TextDisabled("By " + Map.Author);
            }

            UI::TableNextColumn();
            if (!Room.EndState.HasEnded()) {
                UIColor::DarkGreen();
            } else {
                UIColor::Cyan();
            }
            if (UI::Button((Settings::TinyBoard ? "" : Icons::Play + " ") + "Play")) {
                MapList::Visible = false;
                Playground::LoadMap(Map.TmxID);
            }
            UIColor::Reset();

            UI::EndTable();
            UI::PopStyleVar();

            auto Size = UI::GetCursorPos() + UI::GetWindowPos() + vec2(8, 6) - StartPos;
            vec4 Rect = vec4(StartPos.x, StartPos.y + (Settings::TinyBoard ? 4 : 0), 216, Size.y - (Settings::TinyBoard ? 8 : 0));
            if (Map.ClaimedTeam !is null)
                DrawList.AddRectFilled(Rect, UIColor::GetAlphaColor(Map.ClaimedTeam.Color, 0.1));
        }
        if (Settings::TinyBoard) UI::PopFont();

        UI::EndTable();
        UI::PopStyleColor(2);
        UI::PopStyleVar(Settings::TinyBoard ? 3 : 2);
        UI::End();
    }
}