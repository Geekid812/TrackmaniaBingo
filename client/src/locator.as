
namespace BoardLocator {
    int clickCell = -1;
    uint64 lastClick;

    const int DOUBLE_CLICK_MILLIS = 500;

    void Render() {
        if (!Gamemaster::IsBingoActive()) return;
        
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
                UI::Dummy(vec2(sizes.cellSize, sizes.cellSize));
                if (UI::IsItemClicked()) {
                    OnCellClicked(i, j);
                }
            }
        }

        UI::End();
        UI::PopStyleVar();
        UI::PopStyleColor();
    }

    void OnCellClicked(int row, int col) {
        if (!Gamemaster::IsBingoActive()) return;
        int cellId = row * Match.config.gridSize + col;
        uint64 clickNow = Time::Now;

        if (cellId == clickCell && (clickNow - lastClick <= DOUBLE_CLICK_MILLIS)) {
            OnCellDoubleClicked(cellId);
            clickCell = -1;
        } else {
            clickCell = cellId;
        }
        lastClick = clickNow;
    }

    void OnCellDoubleClicked(int cellId) {
        // TODO: there was cell ping, now what?
    }
}
