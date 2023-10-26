namespace UIMapList {
    const string WINDOW_NAME = Icons::Th + " \\$zMap List";
    bool Visible;
    bool RerollMenuOpen;

    void Render() {
        if (!Visible || @Match == null) return;

        UI::Begin(WINDOW_NAME, Visible, UI::WindowFlags::AlwaysAutoResize | UI::WindowFlags::NoCollapse);
        UI::PushFont(Font::Condensed);
        UI::BeginDisabled(Network::IsUISuspended());

        if (UI::IsWindowFocused() && UI::IsKeyPressed(UI::Key::Insert)) {
            UIPaintColor::Visible = true;
        }

        VoteToRerollButton();

        UI::SameLine();
        float uiScale = GridScaleSlider();

        MapGrid(Match.gameMaps, Match.config.gridSize, uiScale);
        
        UI::EndDisabled();
        UI::PopFont();
        UI::End();
    }

    void VoteToRerollButton() {
        string rerollText = RerollMenuOpen ? Icons::Times + " Cancel" : Icons::Kenney::ReloadInverse + " Vote to Reroll";

        UI::BeginGroup();
        if (RerollMenuOpen) UIColor::DarkRed();
        else UIColor::Cyan();
        UI::BeginDisabled(!Match.config.rerolls || !Match.canReroll);
        if (UI::Button(rerollText)) {
            RerollMenuOpen = !RerollMenuOpen;
        }
        UI::EndDisabled();
        UIColor::Reset();
        UI::EndGroup();

        if (UI::IsItemHovered()) {
            if (!Match.config.rerolls) {
                UI::BeginTooltip();
                UI::Text("Map rerolls are disabled for this game.");
                UI::EndTooltip();
            } else if (!Match.canReroll) {
                UI::BeginTooltip();
                UI::Text("There are no other maps available for a reroll.");
                UI::EndTooltip();
            }
        }
    }

    float GridScaleSlider() {
        UI::SetNextItemWidth(220);
        float uiScale = PersistantStorage::MapListUiScale;
        uiScale = UI::SliderFloat(uiScale <= 0.5 ? "###gridsize" : "Grid UI Size###gridsize", uiScale, 0.2, 2.0, "%.1f");
        PersistantStorage::MapListUiScale = uiScale;

        return uiScale;
    }

    bool MapGrid(array<MapCell>@&in maps, int gridSize, float uiScale = 1.0, bool interactable = true) {
        bool interacted = false;
        auto drawList = UI::GetWindowDrawList();
        if (uiScale <= 0.5) UI::PushFont(Font::Tiny);
        UI::PushStyleVar(UI::StyleVar::CellPadding, vec2(8 * uiScale, 8 * uiScale));
        UI::PushStyleVar(UI::StyleVar::ItemSpacing, vec2(2, 2));
        UI::PushStyleVar(UI::StyleVar::FramePadding, vec2(4, 4));
        UI::PushStyleColor(UI::Col::TableBorderLight, vec4(.6, .6, .6, 1.));
        UI::PushStyleColor(UI::Col::TableBorderStrong, vec4(1., 1., 1., 1.));
        UI::BeginTable("Bingo_MapList", gridSize, UI::TableFlags::SizingFixedFit | UI::TableFlags::Borders);

        for (uint i = 0; i < maps.Length; i++) {
            auto cell = maps[i];
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
                if (cell.map.style != "") {
                    UI::PushStyleColor(UI::Col::Button, UIColor::GetAlphaColor(StyleToColor(cell.map.style.ToLower()), .7));
                    UI::Button(cell.map.style);
                    UI::PopStyleColor();
                }

                UI::NewLine();
                if (cell.IsClaimed()) {
                    Player topPlayer = cell.LeadingRun().player;
                    UI::Text("Claimed by \\$" + UIColor::GetHex(topPlayer.team.color) + topPlayer.name);
                    UI::Text(cell.LeadingRun().result.Display());
                } else {
                    UI::TextDisabled("This map has not been claimed yet!");
                }

                if (RerollMenuOpen) {
                    uint requiredPlayers = Match.players.Length / 2 + 1;
                    if (cell.IsClaimed()) {
                        UI::Text("\\$f88Cannot reroll this map, it has already been claimed.");
                    } else {
                        UI::Text("\\$066Votes to reroll: " + cell.rerollIds.Length + "/" + requiredPlayers);
                        if (cell.rerollIds.Find(Profile.uid) != -1) UI::Text("\\$ff8You already voted to reroll this map, select this map again to undo.");
                    }
                }
                UI::PopFont();
                UI::EndTooltip();
            }
            if (interactable && UI::IsItemClicked()) {
                if (UIPaintColor::Visible) cell.paintColor = UIPaintColor::SelectedColor;
                else if (RerollMenuOpen) {
                    NetParams::RerollCellId = i;
                    startnew(Network::RerollCell);
                    RerollMenuOpen = false;
                } else {
                    Visible = false;
                    Playground::LoadMap(cell.map.tmxid);
                    interacted = true;
                }
            }

            auto size = UI::GetCursorPos() + UI::GetWindowPos() + vec2(0, 8 * uiScale) - startPos - vec2(0, UI::GetScrollY());
            vec4 rect = vec4(startPos.x, startPos.y, 500, size.y);
            if (!RerollMenuOpen) {
                if (cell.paintColor != vec3())
                    drawList.AddRectFilled(rect, UIColor::GetAlphaColor(cell.paintColor, 0.1));
                if (cell.IsClaimed())
                    drawList.AddRectFilled(rect, UIColor::GetAlphaColor(cell.LeadingRun().player.team.color, 0.1));
            } else {
                if (!cell.IsClaimed()) {
                    if (cell.rerollIds.Length > 0)
                        drawList.AddRectFilled(rect, UIColor::GetAlphaColor(vec3(.0, .3, .3), 0.1));
                    else 
                        drawList.AddRectFilled(rect, UIColor::GetAlphaColor(vec3(.0, .6, .6), 0.1));
                }
            }
            if (mapHovered) drawList.AddRectFilled(rect, vec4(.5, .5, .5, .1));
        }

        UI::EndTable();
        UI::PopStyleColor(2);
        UI::PopStyleVar(3);
        if (uiScale <= 0.5) UI::PopFont();
        return interacted;
    }

    vec3 StyleToColor(const string&in style) {
        if (style == "ice" || style == "bobsleigh") return vec3(.6, .9, 1.);
        if (style == "race" || style == "competitive") return vec3(1., .8, .2);
        if (style == "lol" || style == "mini") return vec3(.8, .6, .9);
        if (style == "kacky" || style == "fullspeed") return vec3(.8, .1, .1);
        if (style == "grass") return vec3(.3, .8, .3);
        if (style == "dirt") return vec3(.8, .2, .1);
        if (style == "water") return vec3(.2, .9, 1.);
        if (style == "plastic") return vec3(.9, .9, .3);
        if (style == "zrt") return vec3(.1, .5, .1);
        return vec3(.6, .6, .6);
    }
}
