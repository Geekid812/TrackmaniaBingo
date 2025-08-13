
namespace UIItemSelect {
    bool Visible;
    Powerup Powerup;

    void Render() {
        if (!Visible) return;
        if (!Gamemaster::IsBingoActive()) {
            Visible = false;
            return;
        }
        UI::Begin(Icons::StarO + " Item: " + itemName(Powerup), Visible, UI::WindowFlags::NoCollapse | UI::WindowFlags::AlwaysAutoResize);

        UI::BeginDisabled(Network::IsUISuspended());
        switch (Powerup) {
            case Powerup::RowShift:
                RenderRowShift();
                break;
            case Powerup::ColumnShift:
                RenderColumnShift();
                break;
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
        float rowWidth = 160 * uiScale + cellPadding;
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
        float itemSpacing = 2.;
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
}
