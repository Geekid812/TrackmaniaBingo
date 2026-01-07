
namespace UIItemSelect {
    bool Visible;
    bool HookingMapClick;
    bool HookingPlayerClick;
    bool IsSelectingNewTile;
    int SelectedPlayerUid = -1;
    int SelectedBoardIndex = -1;
    array<GameMap> MapChoices = {};
    Powerup Powerup;

    void Render() {
        if (!Visible)
            return;
        if (!Gamemaster::IsBingoActive() || Powerup == Powerup::Empty) {
            Visible = false;
            return;
        }
        UI::Begin(Icons::StarO + " Item: " + itemName(Powerup),
                  Visible,
                  UI::WindowFlags::NoCollapse | UI::WindowFlags::AlwaysAutoResize);
        NetParams::Powerup = Powerup;

        UI::BeginDisabled(Network::IsUISuspended());
        switch (Powerup) {
        case Powerup::RowShift:
            RenderRowShift();
            break;
        case Powerup::ColumnShift:
            RenderColumnShift();
            break;
        case Powerup::Rally:
        case Powerup::RainbowTile:
        case Powerup::GoldenDice:
            if (SelectedBoardIndex == -1) {
                RenderSelectTile();
            } else {
                RenderDiceMapChoice();
            }
            break;
        case Powerup::Jail: {
            if (SelectedPlayerUid == -1) {
                RenderSelectJailPlayer();
            } else {
                RenderSelectTile();
            }
        }
        }
        UI::EndDisabled();

        UI::End();
    }

    void RenderRowShift() {
        UI::SeparatorText("Select a row and direction");

        float uiScale = PersistantStorage::MapListUiScale - 0.1;
        vec2 originalPosition = UI::GetCursorPos();

        UI::PushStyleVar(UI::StyleVar::ItemSpacing, vec2());
        float cellPadding = 8 * uiScale * 2;
        float itemSpacing = 2.;
        float rowHeight = 116 * uiScale + UI::GetTextLineHeight() + cellPadding + itemSpacing;
        for (uint i = 0; i < Match.config.gridSize; i++) {
            if (UI::Button(Icons::ArrowRight + "##bingoboarditemR" + i, vec2(30., rowHeight))) {
                NetParams::PowerupBoardIndex = i;
                NetParams::PowerupBoardIsForward = true;
                startnew(Network::ActivatePowerup);
            }

            UI::SameLine();
            UI::SetCursorPosX((176 * uiScale) * Match.config.gridSize + 60);
            if (UI::Button(Icons::ArrowLeft + "##bingoboarditemL" + i, vec2(30., rowHeight))) {
                NetParams::PowerupBoardIndex = i;
                NetParams::PowerupBoardIsForward = false;
                startnew(Network::ActivatePowerup);
            }
        }
        UI::PopStyleVar();

        UI::SetCursorPos(originalPosition + vec2(38., 0));
        UI::BeginDisabled();
        UIMapList::MapGrid(Match.tiles, Match.config.gridSize, uiScale, false);
        UI::EndDisabled();
    }

    void RenderColumnShift() {
        UI::SeparatorText("Select a column and direction");

        float uiScale = PersistantStorage::MapListUiScale - 0.1;
        vec2 originalPosition = UI::GetCursorPos();

        float cellPadding = 8 * uiScale * 2;
        float rowWidth = 160 * uiScale + cellPadding + 1;

        UI::PushStyleVar(UI::StyleVar::ItemSpacing, vec2());
        for (uint i = 0; i < Match.config.gridSize; i++) {
            if (UI::Button(Icons::ArrowDown + "##bingoboarditemD" + i, vec2(rowWidth, 30.))) {
                NetParams::PowerupBoardIndex = i;
                NetParams::PowerupBoardIsForward = true;
                startnew(Network::ActivatePowerup);
            }
            UI::SameLine();
        }
        UI::NewLine();
        UI::PopStyleVar();

        UI::SetCursorPos(originalPosition + vec2(0., 32.));
        UI::BeginDisabled();
        UIMapList::MapGrid(Match.tiles, Match.config.gridSize, uiScale, false);
        UI::EndDisabled();

        UI::PushStyleVar(UI::StyleVar::ItemSpacing, vec2());
        for (uint i = 0; i < Match.config.gridSize; i++) {
            if (UI::Button(Icons::ArrowUp + "##bingoboarditemU" + i, vec2(rowWidth, 30.))) {
                NetParams::PowerupBoardIndex = i;
                NetParams::PowerupBoardIsForward = false;
                startnew(Network::ActivatePowerup);
            }
            UI::SameLine();
        }
        UI::PopStyleVar();
    }

    void RenderSelectTile() {
        UI::SeparatorText("Select the tile for " + itemName(Powerup));
        float uiScale = PersistantStorage::MapListUiScale - 0.1;

        HookingMapClick = true;
        UIMapList::MapGrid(Match.tiles, Match.config.gridSize, uiScale, true);
        HookingMapClick = false;
    }

    void RenderSelectJailPlayer() {
        UI::SeparatorText("Select a player to send to jail");
        HookingPlayerClick = true;
        UIPlayers::PlayerTable(Match.teams, Match.players);
        HookingPlayerClick = false;
    }

    void RenderDiceMapChoice() {
        UI::SeparatorText("Select one of three new maps from the Golden Dice");
        if (MapChoices.Length == 0) {
            UITools::CenterText("\n\n\\$ff8" + Icons::Star + " \\$zRolling the dice...\n\n");
        } else {
            array<GameTile> tiles = {};
            for (uint i = 0; i < MapChoices.Length; i++) {
                GameTile tile(MapChoices[i]);
                tiles.InsertLast(tile);
            }

            HookingMapClick = true;
            IsSelectingNewTile = true;
            UIMapList::MapGrid(tiles, 3, 1.2, true, false);
            IsSelectingNewTile = false;
            HookingMapClick = false;
        }
    }

    void OnTileClicked(uint tileIndex) {
        if (Powerup == Powerup::GoldenDice) {
            if (IsSelectingNewTile) {
                NetParams::PowerupChoiceIndex = tileIndex;
                NetParams::PowerupBoardIndex = SelectedBoardIndex;
                SelectedBoardIndex = -1;
                startnew(Network::ActivatePowerup);
            } else {
                SelectedBoardIndex = tileIndex;
                MapChoices = {};
                startnew(Network::GetDiceChoices);
            }
        } else {
            NetParams::PowerupBoardIndex = tileIndex;
            NetParams::PlayerSelectUid = SelectedPlayerUid;
            SelectedPlayerUid = -1;
            startnew(Network::ActivatePowerup);
        }
    }

    void OnPlayerClicked(Player @player) { SelectedPlayerUid = player.profile.uid; }
}
