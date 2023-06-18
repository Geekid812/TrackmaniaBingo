namespace UIMapList {
    const string WINDOW_NAME = Icons::Th + " \\$zMap List";
    bool Visible;


    void Render() {
        if (!Visible || @Match == null) return;

        UI::Begin(WINDOW_NAME, Visible, UI::WindowFlags::AlwaysAutoResize | UI::WindowFlags::NoCollapse);
        UI::PushFont(Font::Condensed);
        auto drawList = UI::GetWindowDrawList();

        UI::SetNextItemWidth(220);
        float uiScale = PersistantStorage::MapListUiScale;
        uiScale = UI::SliderFloat(uiScale <= 0.5 ? "###gridsize" : "Grid UI Size###gridsize", uiScale, 0.2, 2.0, "%.1f");
        PersistantStorage::MapListUiScale = uiScale;

        UI::PushStyleVar(UI::StyleVar::CellPadding, vec2(8 * uiScale, 8 * uiScale));
        UI::PushStyleVar(UI::StyleVar::ItemSpacing, vec2(2, 2));
        UI::PushStyleVar(UI::StyleVar::FramePadding, vec2(4, 4));
        UI::PushStyleColor(UI::Col::TableBorderLight, vec4(.6, .6, .6, 1.));
        UI::PushStyleColor(UI::Col::TableBorderStrong, vec4(1., 1., 1., 1.));
        UI::BeginTable("Bingo_MapList", Match.config.gridSize, UI::TableFlags::SizingFixedFit | UI::TableFlags::Borders);

        if (uiScale <= 0.5) UI::PushFont(Font::Tiny);
        for (uint i = 0; i < Match.gameMaps.Length; i++) {
            auto cell = Match.gameMaps[i];
            UI::TableNextColumn();

            auto startPos = UI::GetCursorPos() + UI::GetWindowPos() - vec2(8 * uiScale, 8 * uiScale) - vec2(0, UI::GetScrollY());

            UI::BeginGroup();
            vec2 thumbnailSize = vec2(160 * uiScale, 116 * uiScale);
            if (@cell.mapImage.m_texture != null) {
                UI::Image(cell.mapImage.m_texture, thumbnailSize);
            } else if (@cell.thumbnail.m_texture != null) {
                UI::Image(cell.thumbnail.m_texture, thumbnailSize);
            } else {
                UI::Dummy(thumbnailSize);
            }

            UI::BeginChild("bingomapname" + i, vec2(160. * uiScale, UI::GetTextLineHeight()));
            string mapName = ColoredString(cell.map.trackName);
            UI::Text(mapName);
            UI::EndChild();

            UI::EndGroup();
            bool mapHovered = UI::IsItemHovered();
            if (mapHovered) {
                UI::BeginTooltip();
                UI::PushFont(Font::Subtitle);
                UI::Text(mapName);
                UI::PopFont();

                UI::PushFont(Font::Regular);
                UI::TextDisabled("By " + cell.map.username);
                UI::NewLine();
                if (cell.IsClaimed()) {
                    Player topPlayer = cell.LeadingRun().player;
                    UI::Text("Claimed by \\$" + UIColor::GetHex(topPlayer.team.color) + topPlayer.name);
                    UI::Text(cell.LeadingRun().recordedRun.Display());
                } else {
                    UI::TextDisabled("This map has not been claimed yet!");
                }
                UI::PopFont();
                UI::EndTooltip();
            }
            if (UI::IsItemClicked()) {
                Visible = false;
                Playground::LoadMap(cell.map.tmxid);
            }

            auto size = UI::GetCursorPos() + UI::GetWindowPos() + vec2(0, 8 * uiScale) - startPos - vec2(0, UI::GetScrollY());
            vec4 rect = vec4(startPos.x, startPos.y, 500, size.y);
            if (cell.IsClaimed())
                drawList.AddRectFilled(rect, UIColor::GetAlphaColor(cell.LeadingRun().player.team.color, 0.1));
            if (mapHovered) drawList.AddRectFilled(rect, vec4(.5, .5, .5, .1));
        }
        if (uiScale <= 0.5) UI::PopFont();

        UI::EndTable();
        UI::PopStyleColor(2);
        UI::PopStyleVar(3);
        UI::PopFont();
        UI::End();
    }
}
