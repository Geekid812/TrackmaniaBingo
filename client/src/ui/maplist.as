namespace UIMapList {
    const string WINDOW_NAME = Icons::Th + " \\$zMap List";
    bool Visible;
    bool RerollMenuOpen;

    void Render() {
        if (!Visible || @Match == null)
            return;

        UI::Begin(
            WINDOW_NAME, Visible, UI::WindowFlags::AlwaysAutoResize | UI::WindowFlags::NoCollapse);
        UI::BeginDisabled(Network::IsUISuspended());

        if (UI::IsWindowFocused() && UI::IsKeyPressed(UI::Key::Insert)) {
            UIPaintColor::Visible = true;
        }

        VoteToRerollButton();

        UI::SameLine();
        float uiScale = GridScaleSlider();

        MapGrid(Match.tiles, Match.config.gridSize, uiScale);

        UI::EndDisabled();
        UI::End();
    }

    void VoteToRerollButton() {
        string rerollText = RerollMenuOpen ? Icons::Times + " Cancel"
                                           : Icons::Kenney::ReloadInverse + " Vote to Reroll";

        UI::BeginGroup();
        if (RerollMenuOpen)
            UIColor::DarkRed();
        else
            UIColor::Cyan();
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
        uiScale = UI::SliderFloat(
            uiScale <= 0.5 ? "###gridsize" : "Grid UI Size###gridsize", uiScale, 0.2, 2.0, "%.1f");
        PersistantStorage::MapListUiScale = uiScale;

        return uiScale;
    }

    bool MapGrid(array<GameTile> @& in maps,
                 int gridSize,
                 float uiScale = 1.0,
                 bool interactable = true) {
        bool interacted = false;
        auto drawList = UI::GetWindowDrawList();

        Font::Set(Font::Style::Regular, Font::Size::Medium);

        UI::PushStyleVar(UI::StyleVar::CellPadding, vec2(8 * uiScale, 8 * uiScale));
        UI::PushStyleVar(UI::StyleVar::ItemSpacing, vec2(2, 2));
        UI::PushStyleVar(UI::StyleVar::FramePadding, vec2(4, 4));
        UI::PushStyleColor(UI::Col::TableBorderLight, vec4(.6, .6, .6, 1.));
        UI::PushStyleColor(UI::Col::TableBorderStrong, vec4(1., 1., 1., 1.));
        UI::BeginTable("Bingo_MapList",
                       gridSize,
                       UI::TableFlags::SizingFixedFit | UI::TableFlags::Borders,
                       vec2((176 * uiScale) * gridSize + 6, 0.));

        for (uint i = 0; i < maps.Length; i++) {
            auto cell = maps[i];
            UI::TableNextColumn();

            auto startPos = UI::GetCursorPos() + UI::GetWindowPos() -
                            vec2(8 * uiScale, 8 * uiScale) - vec2(0, UI::GetScrollY());

            UI::BeginGroup();
            vec2 thumbnailSize = vec2(160 * uiScale, 116 * uiScale);
            if (cell.mapImage !is null && cell.mapImage.Data !is null) {
                UI::Image(cell.mapImage.Data, thumbnailSize);
            } else if (cell.thumbnail !is null && cell.thumbnail.Data !is null) {
                UI::Image(cell.thumbnail.Data, thumbnailSize);
            } else {
                UI::Dummy(thumbnailSize);
            }

            UI::BeginChild("bingomapname" + i, vec2(160. * uiScale, UI::GetTextLineHeight()));

            string mapName =
                cell.map !is null ? Text::OpenplanetFormatCodes(cell.map.trackName) : "";
            UI::Text(mapName);

            UI::EndChild();

            UI::EndGroup();
            bool mapHovered = UI::IsItemHovered();
            if (mapHovered && cell.map !is null) {
                ShowTileTooltip(cell, (i % gridSize), (i / gridSize));
            }
            if (interactable && UI::IsItemClicked()) {
                if (UIPaintColor::Visible)
                    cell.paintColor = UIPaintColor::SelectedColor;
                else if (RerollMenuOpen) {
                    NetParams::RerollCellId = i;
                    startnew(Network::RerollCell);
                    RerollMenuOpen = false;
                } else if (UIItemSelect::HookingMapClick) {
                    if (cell.specialState == TileItemState::Empty ||
                        cell.specialState == TileItemState::HasPowerup ||
                        cell.specialState == TileItemState::HasSpecialPowerup) {
                        UIItemSelect::OnTileClicked(i);
                        interacted = true;
                    }
                } else if (cell.map !is null) {
                    Visible = false;

                    // Playground::DebugClaim(i);
                    OnTileClicked(cell);

                    interacted = true;
                }
            }

            auto size = UI::GetCursorPos() + UI::GetWindowPos() + vec2(0, 8 * uiScale) - startPos -
                        vec2(0, UI::GetScrollY());
            vec4 rect = vec4(startPos.x, startPos.y, 500, size.y);
            if (!RerollMenuOpen) {
                if (cell.paintColor != vec3())
                    drawList.AddRectFilled(rect, UIColor::GetAlphaColor(cell.paintColor, 0.1));
                if (cell.specialState == TileItemState::Rainbow)
                    drawList.AddRectFilledMultiColor(rect,
                                                     TeamColorIndex(0),
                                                     TeamColorIndex(1),
                                                     TeamColorIndex(2),
                                                     TeamColorIndex(3));
                if (cell.claimant.id != -1)
                    drawList.AddRectFilled(rect, UIColor::GetAlphaColor(cell.claimant.color, 0.1));
                if (cell.HasRunSubmissions())
                    drawList.AddRectFilled(
                        rect, UIColor::GetAlphaColor(cell.LeadingRun().player.team.color, 0.1));
            } else {
                if (!cell.HasRunSubmissions() && cell.claimant.id == -1) {
                    drawList.AddRectFilled(rect, UIColor::GetAlphaColor(vec3(.0, .6, .6), 0.1));
                }
            }
            if (mapHovered)
                drawList.AddRectFilled(rect, vec4(.5, .5, .5, .1));
        }

        UI::EndTable();
        UI::PopStyleColor(2);
        UI::PopStyleVar(3);
        Font::Unset();

        return interacted;
    }

    vec4 TeamColorIndex(uint idx) {
        return UIColor::GetAlphaColor(Match.teams[idx % Match.teams.Length].color, 0.15);
    }

    string GetTileTitle(GameTile tile, int x = -1, int y = -1) {
        string mapName = tile.map !is null ? Text::OpenplanetFormatCodes(tile.map.trackName) : "";
        string cellCoordinates =
            (Settings::ShowCellCoordinates
                 ? "\\$888[ \\$ff8" + GetTextCoordinates(x, y) + " \\$888] \\$z"
                 : "");

        return cellCoordinates + mapName;
    }

    void ShowTileTooltip(GameTile tile, int x = -1, int y = -1) {
        if (tile.map is null) {
            return;
        }

        UI::BeginTooltip();

        if (tile.specialState == TileItemState::Rainbow) {
            UI::Text(
                "\\$F55R\\$E65a\\$D85i\\$BA5n\\$AB6b\\$9D6o\\$9D6w \\$7BAT\\$6BBi\\$5ADl\\$49Fe");
        }

        string mapTitle = GetTileTitle(tile, x, y);
        UI::Text(mapTitle);

        if (tile.map.username != "")
            UI::TextDisabled("By " + tile.map.username);
        if (tile.map.style != "") {
            UI::PushStyleColor(UI::Col::Button,
                               UIColor::GetAlphaColor(StyleToColor(tile.map.style.ToLower()), .7));
            UI::Button(tile.map.style);
            UI::PopStyleColor();
        }

        UI::NewLine();
        if (tile.claimant.id != -1) {
            UI::Text("Claimed by \\$" + UIColor::GetHex(tile.claimant.color) + tile.claimant.name);
        }
        if (tile.HasRunSubmissions()) {
            Player topPlayer = tile.LeadingRun().player;
            UI::Text((tile.claimant.id != -1 ? "Current record by \\$" : "Claimed by \\$") +
                     UIColor::GetHex(topPlayer.team.color) + topPlayer.name);
            UI::Text(tile.LeadingRun().result.Display());
        } else {
            UI::TextDisabled("This map has not been claimed yet!");
        }

        if (RerollMenuOpen) {
            if (tile.HasRunSubmissions() || tile.claimant.id != -1) {
                UI::Text("\\$f88Cannot reroll this map, it has already been claimed.");
            } else {
                UI::Text("\\$066Click to start a vote to reroll this map.");
            }
        }

        switch (tile.specialState) {
        case TileItemState::HasPowerup:
            UI::Text("\\$8ffA powerup can be obtained on this map!");
            break;
        case TileItemState::HasSpecialPowerup:
            UI::Text("\\$fb0A SPECIAL powerup can be obtained on this map!");
            break;
        case TileItemState::Rally:
            UI::Text("\\$fcaA rally is currently taking place on this map!");
            break;
        case TileItemState::Jail: {
            Player @jailedPlayer = Match.GetPlayer(tile.statePlayerTarget.uid);
            vec3 teamColor = jailedPlayer !is null ? jailedPlayer.team.color : vec3(.5, .5, .5);
            UI::Text("\\$" + UIColor::GetHex(teamColor) + tile.statePlayerTarget.name +
                     " \\$f88is in jail here.\n(\\$ff8" +
                     Time::Format(tile.stateTimeDeadline - Time::Now, false) + " \\$f88remaining)");
            break;
        }
        }

        if (UIItemSelect::HookingMapClick) {
            if (tile.specialState != TileItemState::Empty &&
                tile.specialState != TileItemState::HasPowerup &&
                tile.specialState != TileItemState::HasSpecialPowerup) {
                UI::Text("\\$f88Cannot select this tile, there is already a powerup active here.");
            }
        }

        UI::EndTooltip();
    }

    bool OnKeyPress(bool down, VirtualKey key) {
        if (!Gamemaster::IsBingoActive())
            return false;

        if (down && key == Settings::MaplistBindingKey) {
            Visible = !Visible;
            return true;
        }

        return false;
    }

    void OnTileClicked(GameTile @cell) {
        if (@Jail !is null && @Jail != @cell) {
            // action cancelled, you cannot switch maps in jail
            Powerups::NotifyJail();
        } else {
            Playground::PlayMap(cell.map);
        }
    }

    string GetTextCoordinates(int x, int y) {
        if (x == -1 || y == -1)
            return "";

        string letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
        return letters.SubStr(y % 26, 1) + tostring(x + 1);
    }

    vec3 StyleToColor(const string& in style) {
        if (style == "ice" || style == "bobsleigh")
            return vec3(.6, .9, 1.);
        if (style == "race" || style == "competitive")
            return vec3(1., .8, .2);
        if (style == "lol" || style == "mini")
            return vec3(.8, .6, .9);
        if (style == "kacky" || style == "fullspeed")
            return vec3(.8, .1, .1);
        if (style == "grass")
            return vec3(.3, .8, .3);
        if (style == "dirt")
            return vec3(.8, .2, .1);
        if (style == "water")
            return vec3(.2, .9, 1.);
        if (style == "plastic")
            return vec3(.9, .9, .3);
        if (style == "zrt")
            return vec3(.1, .5, .1);
        if (style == "multilap")
            return vec3(.8, .1, .2);
        return vec3(.6, .6, .6);
    }
}
