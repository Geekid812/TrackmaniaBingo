namespace MapList {
    const string WindowName = Icons::Th + " \\$zMap List";
    bool Visible;

    void Render() {
        if (!Visible) return;

        UI::Begin(WindowName, Visible, UI::WindowFlags::AlwaysAutoResize | UI::WindowFlags::NoCollapse);
        UI::PushFont(Font::Condensed);
        auto DrawList = UI::GetWindowDrawList();

        UI::PushStyleVar(UI::StyleVar::CellPadding, Settings::TinyBoard ? vec2(4, 4) : vec2(8, 8));
        UI::PushStyleVar(UI::StyleVar::ItemSpacing, vec2(2, 2));
        if (Settings::TinyBoard) UI::PushStyleVar(UI::StyleVar::FramePadding, vec2(4, 4));
        UI::PushStyleColor(UI::Col::TableBorderLight, vec4(.6, .6, .6, 1.));
        UI::PushStyleColor(UI::Col::TableBorderStrong, vec4(1., 1., 1., 1.));
        UI::BeginTable("Bingo_MapList", Room.Config.GridSize, UI::TableFlags::SizingFixedFit | UI::TableFlags::Borders);

        if (Settings::TinyBoard) UI::PushFont(Font::Tiny);
        for (uint i = 0; i < Room.MapList.Length; i++) {
            auto Map = Room.MapList[i];
            UI::TableNextColumn();

            auto StartPos = UI::GetCursorPos() + UI::GetWindowPos() - vec2(8, 7) - vec2(0, UI::GetScrollY());

            UI::BeginGroup();
            vec2 ThumbnailSize = vec2(160, 116);
            //if (Settings::TinyBoard) ThumbnailSize = vec2(100, 72);
            if (@Map.MapImage.m_texture != null) {
                UI::Image(Map.MapImage.m_texture, ThumbnailSize);
            } else if (@Map.Thumbnail.m_texture != null) {
                UI::Image(Map.Thumbnail.m_texture, ThumbnailSize);
            } else {
                UI::Dummy(ThumbnailSize);
            }

            UI::BeginChild("bingomapname" + i, vec2(160., UI::GetTextLineHeight()));
            UI::Text(Map.Name);
            UI::EndChild();

            UI::EndGroup();
            bool MapHovered = UI::IsItemHovered();
            if (MapHovered) {
                UI::BeginTooltip();
                UI::PushFont(Font::Subtitle);
                UI::Text(Map.Name);
                UI::PopFont();

                UI::PushFont(Font::Regular);
                UI::TextDisabled("By " + Map.Author);
                UI::NewLine();
                if (Map.ClaimedTeam !is null) {
                    UI::Text("Claimed by \\$" + UIColor::GetHex(Map.ClaimedTeam.Color) + Map.ClaimedPlayerName);
                    UI::Text(Map.ClaimedRun.Display());
                } else {
                    UI::TextDisabled("This map has not been claimed yet!");
                }
                UI::PopFont();
                UI::EndTooltip();
            }
            if (UI::IsItemClicked()) {
                MapList::Visible = false;
                Playground::LoadMap(Map.TmxID);
            }

            // if (Map.ClaimedRun.Time != -1) {
            //     UI::TextDisabled(Settings::TinyBoard ? Map.ClaimedRun.DisplayTime() : Map.ClaimedRun.Display());
            // } else {
            //     UI::TextDisabled("By " + Map.Author);
            // }

            // if (!Room.EndState.HasEnded()) {
            //     UIColor::DarkGreen();
            // } else {
            //     UIColor::Cyan();
            // }
            // if (UI::Button((Settings::TinyBoard ? "" : Icons::Play + " ") + "Play")) {
            //     MapList::Visible = false;
            //     Playground::LoadMap(Map.TmxID);
            // }
            // UIColor::Reset();

            auto Size = UI::GetCursorPos() + UI::GetWindowPos() + vec2(8, 6) - StartPos - vec2(0, UI::GetScrollY());
            vec4 Rect = vec4(StartPos.x, StartPos.y + (Settings::TinyBoard ? 4 : 0), 216, Size.y - (Settings::TinyBoard ? 8 : 0));
            if (Map.ClaimedTeam !is null)
                DrawList.AddRectFilled(Rect, UIColor::GetAlphaColor(Map.ClaimedTeam.Color, 0.1));
            if (MapHovered) DrawList.AddRectFilled(Rect, vec4(.5, .5, .5, .1));
        }
        if (Settings::TinyBoard) UI::PopFont();

        UI::EndTable();
        UI::PopStyleColor(2);
        UI::PopStyleVar(Settings::TinyBoard ? 3 : 2);
        UI::PopFont();
        UI::End();
    }
}