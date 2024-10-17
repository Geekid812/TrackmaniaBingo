
namespace BoardLocator {
    int clickCell = -1;
    uint64 lastClick;

    const int DOUBLE_CLICK_MILLIS = 500;

    void Render() {
        if (!Gamemaster::IsBingoActive()) return;
        vec2 windowPadding = UI::GetStyleVarVec2(UI::StyleVar::WindowPadding);
        
        UI::SetNextWindowPos(int(79 * Board::Unit()), int(Board::Unit()), UI::Cond::FirstUseEver);
        UI::SetNextWindowSize(int(20 * Board::Unit()), int(20 * Board::Unit()), UI::Cond::FirstUseEver);

        UI::PushStyleColor(UI::Col::WindowBg, vec4(0, 0, 0, 0));
        UI::PushStyleVar(UI::StyleVar::WindowPadding, vec2());
        UI::Begin("Board Locator", UI::WindowFlags::NoCollapse | UI::WindowFlags::NoTitleBar);

        float size = UI::GetWindowSize().y;
        Gamemaster::SetBoardPosition(UI::GetWindowPos());
        Gamemaster::SetBoardSize(size);

        UI::SetWindowSize(vec2(size, size), UI::Cond::Always);

        // Cell zones
        Board::DrawState@ state = Gamemaster::GetDrawState();

        uint tilesPerRow = state.resolution;
        float cellSize = state.sizes.cellSize;
        for (uint i = 0; i < tilesPerRow; i++) {
            for (uint j = 0; j < tilesPerRow; j++) {
                vec2 pos = Board::GetCellPosition(state, i, j);

                UI::SetCursorPos(pos - UI::GetWindowPos());
                UI::Dummy(vec2(cellSize, cellSize));
                if (UI::IsItemClicked()) {
                    OnCellClicked(state, i, j);
                }
                if (UI::IsItemHovered()) {
                    OnCellHovered(state, i, j, windowPadding);
                }
            }
        }

        UI::End();
        UI::PopStyleVar();
        UI::PopStyleColor();
    }

    void OnCellHovered(Board::DrawState@ state, uint x, uint y, vec2 windowPadding) {
        if (!Gamemaster::IsBingoActive()) return;
        
        // Tile hovered, show the map tooltip
        UI::PushStyleVar(UI::StyleVar::WindowPadding, windowPadding);

        GameTile@ tile = Gamemaster::GetTileOnGrid(x, y);
        UIMapList::MapTooltip(tile);

        UI::PopStyleVar();
    }

    void OnCellClicked(Board::DrawState@ state, uint x, uint y) {
        if (!Gamemaster::IsBingoActive()) return;
        uint tileId = Board::TileId(x, y, state.resolution);
        uint64 clickNow = Time::Now;

        if (int(tileId) == clickCell && (clickNow - lastClick <= DOUBLE_CLICK_MILLIS)) {
            OnCellDoubleClicked(state, x, y);
            clickCell = -1;
        } else {
            clickCell = tileId;
        }
        lastClick = clickNow;
    }

    void OnCellDoubleClicked(Board::DrawState@ state, uint x, uint y) {
        // Tile double clicked, quickly enter the selected tile
        uint tileId = Board::TileId(x, y, state.resolution);
        Gamemaster::TileEnter(tileId);
    }
}
