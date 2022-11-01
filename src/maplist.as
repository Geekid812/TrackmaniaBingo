namespace MapList {
    const string WindowName = Icons::Th + " \\$zMap List";
    bool Visible;

    void Render() {
        if (!Visible) return;

        UI::Begin(WindowName, Visible, UI::WindowFlags::AlwaysAutoResize | UI::WindowFlags::NoCollapse);
        auto DrawList = UI::GetWindowDrawList();

        UI::PushStyleVar(UI::StyleVar::CellPadding, vec2(8, 8));
        UI::PushStyleVar(UI::StyleVar::ItemSpacing, vec2(2, 2));
        UI::PushStyleColor(UI::Col::TableBorderLight, vec4(.6, .6, .6, 1.));
        UI::PushStyleColor(UI::Col::TableBorderStrong, vec4(1., 1., 1., 1.));
        UI::BeginTable("Bingo_MapList", 5, UI::TableFlags::SizingFixedFit | UI::TableFlags::Borders);

        for (uint i = 0; i < Room.MapList.Length; i++) {
            auto Map = Room.MapList[i];
            UI::TableNextColumn();

            auto StartPos = UI::GetCursorPos() + UI::GetWindowPos() - vec2(8, 7);

            if (@Map.MapImage.m_texture != null) {
                UI::Image(Map.MapImage.m_texture, vec2(200, 145));
            } else if (@Map.Thumbnail.m_texture != null) {
                UI::Image(Map.Thumbnail.m_texture, vec2(200, 145));
            } else {
                UI::Dummy(vec2(200, 145));
            }
            UI::PushStyleVar(UI::StyleVar::CellPadding, vec2(2, 2));
            UI::BeginTable("Bingo_Map" + i, 2, UI::TableFlags::SizingFixedFit);
            UI::TableSetupColumn("", UI::TableColumnFlags::None, 135);
            UI::TableSetupColumn("", UI::TableColumnFlags::None, 65);
            UI::TableNextColumn();
            UI::Text(Map.Name);

            if (Map.ClaimedRun.Time != -1) {
                UI::TextDisabled(Map.ClaimedRun.Display());
            } else {
                UI::TextDisabled("By " + Map.Author);
            }

            UI::TableNextColumn();
            if (!Room.EndState.HasEnded()) {
                UIColor::DarkGreen();
                if (UI::Button(Icons::Play + " Play")) {
                    MapList::Visible = false;
                    Playground::LoadMap(Map.TmxID);
                }
                UIColor::Reset();
            }
            UI::EndTable();
            UI::PopStyleVar();

            auto Size = UI::GetCursorPos() + UI::GetWindowPos() + vec2(8, 6) - StartPos;
            vec4 Rect = vec4(StartPos.x, StartPos.y, 216, Size.y);
            if (Map.ClaimedTeam == 0) DrawList.AddRectFilled(Rect, vec4(1, .2, .2, .1));
            if (Map.ClaimedTeam == 1) DrawList.AddRectFilled(Rect, vec4(.2, .2, 1, .1));
        }

        UI::EndTable();
        UI::PopStyleColor(2);
        UI::PopStyleVar(2);
        UI::End();
    }
}