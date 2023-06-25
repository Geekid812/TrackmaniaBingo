
namespace Board {
    // Controlled by BoardLocator
    float BoardSize;
    vec2 Position;

    const float STROKE_WIDTH = 8.;
    const float CELL_HIGHLIGHT_PADDING = 2.5; // Multiplier for BorderSize, inside offset
    const vec4 CELL_HIGHLIGHT_COLOR = vec4(1, 1, 0, 0.9);
    const vec4 BINGO_STROKE_COLOR = vec4(1, 0.6, 0, 0.9);
    const uint64 ANIMATION_START_TIME = 4000;

    void Draw() {
        if (@Match == null) return;

        uint cellsPerRow = Match.config.gridSize;
        float borderSize = BoardSize / (30. * cellsPerRow);
        float cellSize = (BoardSize - borderSize * (float(cellsPerRow) + 1.)) / float(cellsPerRow);
        nvg::BeginPath();

        int64 animationTime = Time::Now - Match.startTime + ANIMATION_START_TIME; 

        // Borders
        float timePerBorder = 1. / (cellsPerRow + 1);
        // Columns
        float columnsAnimProgress = Animation::GetProgress(animationTime, 0, 1500, Animation::Easing::SineOut);
        if (columnsAnimProgress <= 0.) return;
        nvg::FillColor(vec4(.9, .9, .9, 1.));
        for (uint i = 0; i <= cellsPerRow; i++) {
            float animProgress = Animation::GetProgress(columnsAnimProgress, i * timePerBorder, timePerBorder);
            nvg::BeginPath();
            nvg::Rect(Position.x + float(i) * (cellSize + borderSize), Position.y, borderSize, BoardSize * animProgress);
            nvg::Fill();
        }

        // Rows
        float rowsAnimProgress = Animation::GetProgress(animationTime, 500, 1500, Animation::Easing::SineOut);
        if (rowsAnimProgress <= 0.) return;
        for (uint i = 0; i <= cellsPerRow; i++) {
            float animProgress = Animation::GetProgress(rowsAnimProgress, i * timePerBorder, timePerBorder);
            nvg::BeginPath();
            nvg::Rect(Position.x, Position.y + float(i) * (cellSize + borderSize), BoardSize * animProgress, borderSize);
            nvg::Fill();
        }

        // Cell Fill Color
        float colorAnimProgress = Animation::GetProgress(animationTime, 2000, 500);
        for (uint i = 0; i < cellsPerRow; i++) {
            for (uint j = 0; j < cellsPerRow; j++) {
                auto map = Match.gameMaps[j * cellsPerRow + i];
                nvg::BeginPath();
                vec4 color;
                if (map.IsClaimed())
                    color = UIColor::GetAlphaColor(map.LeadingRun().player.team.color, .8);
                else 
                    color = vec4(.3, .3, .3, .8 * colorAnimProgress);
                nvg::FillColor(color);
                nvg::Rect(Position.x + float(i) * (cellSize + borderSize) + borderSize, Position.y + float(j) * (cellSize + borderSize) + borderSize, cellSize, cellSize);
                nvg::Fill();
            }
        }

        // Cell highlight
        const float highlightWidth = borderSize * CELL_HIGHLIGHT_PADDING;
        const float highlightMarginOffset = borderSize * (CELL_HIGHLIGHT_PADDING - 1.);
        CGameCtnChallenge@ currentMap = Playground::GetCurrentMap();
        int cellId = (@currentMap != null) ? Match.GetMapCellId(currentMap.EdChallengeId) : -1;
        if (cellId != -1) {
            int row = cellId / cellsPerRow;
            int col = cellId % cellsPerRow;
            nvg::BeginPath();
            nvg::FillColor(CELL_HIGHLIGHT_COLOR);
            nvg::Rect(Position.x + (cellSize + borderSize) * col, Position.y + (cellSize + borderSize) * row, cellSize + borderSize * 2, highlightWidth);
            nvg::Fill();
            nvg::BeginPath();
            nvg::Rect(Position.x + (cellSize + borderSize) * col, Position.y + (cellSize + borderSize) * (row + 1) - highlightMarginOffset, cellSize + borderSize * 2, highlightWidth);
            nvg::Fill();
            nvg::BeginPath();
            nvg::Rect(Position.x + (cellSize + borderSize) * col, Position.y + (cellSize + borderSize) * row, highlightWidth, cellSize + borderSize * 2);
            nvg::Fill();
            nvg::BeginPath();
            nvg::Rect(Position.x + (cellSize + borderSize) * (col + 1) - highlightMarginOffset, Position.y + (cellSize + borderSize) * row, highlightWidth, cellSize + borderSize * 2);
            nvg::Fill();
        }

        // Winning stroke
        BingoDirection direction = Match.endState.bingoDirection;
        int i = Match.endState.offset;
        nvg::StrokeColor(BINGO_STROKE_COLOR);
        nvg::StrokeWidth(STROKE_WIDTH);
        if (direction == BingoDirection::Horizontal) {
            float yPos = Position.y + borderSize + (cellSize / 2) + i * (cellSize + borderSize);
            nvg::BeginPath();
            nvg::MoveTo(vec2(Position.x - borderSize, yPos));
            nvg::LineTo(vec2(Position.x + BoardSize + borderSize, yPos));
            nvg::Stroke();
        } else if (direction == BingoDirection::Vertical) {
            float xPos = Position.x + borderSize + (cellSize / 2) + i * (cellSize + borderSize);
            nvg::BeginPath();
            nvg::MoveTo(vec2(xPos, Position.y - borderSize));
            nvg::LineTo(vec2(xPos, Position.y + BoardSize + borderSize));
            nvg::Stroke();
        } else if (direction == BingoDirection::Diagonal) {
            nvg::BeginPath();
            nvg::MoveTo(vec2(Position.x - borderSize, Position.y - borderSize + i * (BoardSize + 2 * borderSize)));
            nvg::LineTo(vec2(Position.x + BoardSize + borderSize, Position.y - borderSize + (1 - i) * (BoardSize + 2 * borderSize)));
            nvg::Stroke();
        }

        nvg::ClosePath();
    }

    // A unit of drawing is 1/100th of the screen's width.
    float Unit() {
        return float(Draw::GetWidth() / 100.);
    }
}