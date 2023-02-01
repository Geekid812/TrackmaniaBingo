namespace MapList {
    const string WindowName = Icons::Th + " \\$zMap List";
    bool Visible;

    [Setting hidden] // Persistently saved
    float UiScale = 1.0f;

    void Render() {
        if (!Visible) return;

        UI::Begin(WindowName, Visible, UI::WindowFlags::AlwaysAutoResize | UI::WindowFlags::NoCollapse);
        UI::PushFont(Font::Condensed);
        auto DrawList = UI::GetWindowDrawList();

        UI::SetNextItemWidth(220);
        UiScale = UI::SliderFloat(UiScale <= 0.2 ? "###gridsize" : "Grid UI Size###gridsize", UiScale, 0.2, 2.0, "%.1f");

        UI::PushStyleVar(UI::StyleVar::CellPadding, vec2(8 * UiScale, 8 * UiScale));
        UI::PushStyleVar(UI::StyleVar::ItemSpacing, vec2(2, 2));
        UI::PushStyleVar(UI::StyleVar::FramePadding, vec2(4, 4));
        UI::PushStyleColor(UI::Col::TableBorderLight, vec4(.6, .6, .6, 1.));
        UI::PushStyleColor(UI::Col::TableBorderStrong, vec4(1., 1., 1., 1.));
        UI::BeginTable("Bingo_MapList", Room.Config.GridSize, UI::TableFlags::SizingFixedFit | UI::TableFlags::Borders);

        if (UiScale <= 0.5) UI::PushFont(Font::Tiny);
        for (uint i = 0; i < Room.MapList.Length; i++) {
            auto Map = Room.MapList[i];
            UI::TableNextColumn();

            auto StartPos = UI::GetCursorPos() + UI::GetWindowPos() - vec2(8 * UiScale, 8 * UiScale) - vec2(0, UI::GetScrollY());

            UI::BeginGroup();
            vec2 ThumbnailSize = vec2(160 * UiScale, 116 * UiScale);
            if (@Map.MapImage.m_texture != null) {
                UI::Image(Map.MapImage.m_texture, ThumbnailSize);
            } else if (@Map.Thumbnail.m_texture != null) {
                UI::Image(Map.Thumbnail.m_texture, ThumbnailSize);
            } else {
                UI::Dummy(ThumbnailSize);
            }

            UI::BeginChild("bingomapname" + i, vec2(160. * UiScale, UI::GetTextLineHeight()));
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
                //Playground::LoadMap(Map.TmxID);
                Playground::MapClaimData.Retries = 3;
                Playground::MapClaimData.MapUid = Map.Uid;
                Playground::MapClaimData.MapResult = RunResult(0, Medal::Author);
                startnew(Playground::ClaimMedalCoroutine);
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

            auto Size = UI::GetCursorPos() + UI::GetWindowPos() + vec2(0, 8 * UiScale) - StartPos - vec2(0, UI::GetScrollY());
            vec4 Rect = vec4(StartPos.x, StartPos.y, 500, Size.y);
            if (Map.ClaimedTeam !is null)
                DrawList.AddRectFilled(Rect, UIColor::GetAlphaColor(Map.ClaimedTeam.Color, 0.1));
            if (MapHovered) DrawList.AddRectFilled(Rect, vec4(.5, .5, .5, .1));
        }
        if (UiScale <= 0.5) UI::PopFont();

        UI::EndTable();
        UI::PopStyleColor(2);
        UI::PopStyleVar(3);
        UI::PopFont();
        UI::End();
    }
}