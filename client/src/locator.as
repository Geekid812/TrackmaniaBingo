
namespace BoardLocator {
    void Render() {
        if (!Gamemaster::IsBingoActive()) return;

        vec2 defaultWindowPadding = UI::GetStyleVarVec2(UI::StyleVar::WindowPadding);
        UI::SetNextWindowPos(int(79 * Board::Unit()), int(Board::Unit()), UI::Cond::FirstUseEver);
        UI::SetNextWindowSize(int(20 * Board::Unit()), int(20 * Board::Unit()), UI::Cond::FirstUseEver);

        UI::PushStyleColor(UI::Col::WindowBg, vec4(0, 0, 0, 0));
        UI::PushStyleVar(UI::StyleVar::WindowPadding, vec2());
        UI::Begin("Board Locator", UI::WindowFlags::NoCollapse | UI::WindowFlags::NoTitleBar);
        Board::BoardSize = UI::GetWindowSize().y;
        Board::Position = UI::GetWindowPos();
        UI::SetWindowSize(vec2(Board::BoardSize, Board::BoardSize), UI::Cond::Always);

        // Cell zones
        uint cellsPerRow = Match.config.gridSize;
        auto sizes = Board::CalculateBoardSizes(cellsPerRow);
        for (uint i = 0; i < cellsPerRow; i++) {
            for (uint j = 0; j < cellsPerRow; j++) {
                vec2 pos = Board::CellPosition(i, j, sizes);
                UI::SetCursorPos(pos - UI::GetWindowPos());
                UI::Dummy(vec2(sizes.cell, sizes.cell));
                
                if (UI::IsItemHovered()) {
                    UI::PushStyleVar(UI::StyleVar::WindowPadding, defaultWindowPadding);
                    UIMapList::ShowTileTooltip(Gamemaster::GetTileOnGrid(i, j));
                    UI::PopStyleVar();
                }
                
                if (UI::IsItemHovered() && UI::IsMouseDoubleClicked()) {
                    OnCellClicked(i, j);
                }
            }
        }

        UI::End();
        UI::PopStyleVar();
        UI::PopStyleColor();
    }

    void OnCellClicked(int row, int col) {
        GameTile@ tile = Gamemaster::GetTileOnGrid(row, col);
        
        if (tile.map !is null)
            Playground::PlayMap(tile.map);
    }
}
