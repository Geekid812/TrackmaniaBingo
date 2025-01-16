
namespace Board {
    // Controlled by BoardLocator
    float BoardSize;
    vec2 Position;
    array<CellPing> Pings;

    const float STROKE_WIDTH = 8.;
    const float CELL_HIGHLIGHT_PADDING = 3.5; // Multiplier for BorderSize, inside offset
    const vec4 CELL_HIGHLIGHT_COLOR = vec4(1, 1, 1, 0.9);
    const vec4 BINGO_STROKE_COLOR = vec4(1, 0.6, 0, 0.9);
    const uint64 ANIMATION_START_TIME = 4000;

    const uint64 PING_DURATION = 2500;
    const uint64 PING_PERIOD = 1250;
    const float PING_SCALE = 1.5;

    class BoardSizes {
        float border;
        float cell;
        float step;
    }

    class CellPing {
        uint64 time;
        uint cellId;
    }

    /**
     * Determine which color the tile should be.
     */
    vec4 GetTileFillColor(GameTile@ tile) {
        if (tile is null || tile.map is null) return vec4(0, 0, 0, .8);
        
        if (tile.paintColor != vec3())
            return UIColor::GetAlphaColor(tile.paintColor, .8);

        if (tile.IsClaimed()) {
            Team@ tileOwnerTeam = Match.GetTeamWithId(tile.LeadingRun().teamId);

            if (@tileOwnerTeam !is null)
                return UIColor::GetAlphaColor(tileOwnerTeam.color, .8);
        }
        
        return vec4(.3, .3, .3, .8);
    }

    void Draw() {
        if (!Gamemaster::IsBingoActive()) return;

        uint cellsPerRow = Match.config.gridSize;
        BoardSizes sizes = CalculateBoardSizes(cellsPerRow);
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
            nvg::Rect(Position.x + float(i) * sizes.step, Position.y, sizes.border, BoardSize * animProgress);
            nvg::Fill();
        }

        // Rows
        float rowsAnimProgress = Animation::GetProgress(animationTime, 500, 1500, Animation::Easing::SineOut);
        if (rowsAnimProgress <= 0.) return;
        for (uint i = 0; i <= cellsPerRow; i++) {
            float animProgress = Animation::GetProgress(rowsAnimProgress, i * timePerBorder, timePerBorder);
            nvg::BeginPath();
            nvg::Rect(Position.x, Position.y + float(i) * sizes.step, BoardSize * animProgress, sizes.border);
            nvg::Fill();
        }

        // Cell Fill Color
        float colorAnimProgress = Animation::GetProgress(animationTime, 2000, 500);
        for (uint x = 0; x < cellsPerRow; x++) {
            
            for (uint y = 0; y < cellsPerRow; y++) {
                GameTile@ tile = Gamemaster::GetTileOnGrid(x, y);

                vec2 cellPosition = CellPosition(x, y, sizes);
                vec4 color = GetTileFillColor(tile);
                color.w *= colorAnimProgress; // opacity modifier
                
                nvg::BeginPath();
                nvg::FillColor(color);
                nvg::Rect(cellPosition.x, cellPosition.y, sizes.cell, sizes.cell);
                nvg::Fill();
            }
        
        }

        // Cell highlight
        float highlightBlinkValue = (Math::Sin(float(Time::Now) / 1000.) + 1) / 2;
        float paddingValue = CELL_HIGHLIGHT_PADDING * (0.8 + 0.2 * highlightBlinkValue);
        const float highlightWidth = sizes.border * paddingValue;
        const float highlightMarginOffset = sizes.border * (paddingValue - 1.);
        
        int currentTileIndex = Gamemaster::GetCurrentTileIndex();
        if (currentTileIndex != -1) {
            int row = currentTileIndex / cellsPerRow;
            int col = currentTileIndex % cellsPerRow;
            nvg::BeginPath();
            nvg::FillColor(CELL_HIGHLIGHT_COLOR);
            nvg::Rect(Position.x + sizes.step * col, Position.y + sizes.step * row, sizes.cell + sizes.border * 2, highlightWidth);
            nvg::Fill();
            nvg::BeginPath();
            nvg::Rect(Position.x + sizes.step * col, Position.y + sizes.step * (row + 1) - highlightMarginOffset, sizes.cell + sizes.border * 2, highlightWidth);
            nvg::Fill();
            nvg::BeginPath();
            nvg::Rect(Position.x + sizes.step * col, Position.y + sizes.step * row, highlightWidth, sizes.cell + sizes.border * 2);
            nvg::Fill();
            nvg::BeginPath();
            nvg::Rect(Position.x + sizes.step * (col + 1) - highlightMarginOffset, Position.y + sizes.step * row, highlightWidth, sizes.cell + sizes.border * 2);
            nvg::Fill();
        }

        // Cell ping
        for (uint i = 0; i < Pings.Length; i++) {
            auto ping = Pings[i];
            uint64 pingAnimationTime = Time::Now - ping.time;
            if (pingAnimationTime > PING_DURATION) {
                Pings.RemoveAt(i);
                continue;
            }

            int row = ping.cellId / cellsPerRow;
            int col = ping.cellId % cellsPerRow;
            vec2 pos = CellPosition(row, col, sizes);

            pingAnimationTime %= PING_PERIOD;
            for (uint n = 0; n < 2; n++) {
                float pingAnimProgress = Animation::GetProgress(pingAnimationTime - n * 200, 0, 1000, Animation::Easing::SineOut);
                float pingScale = pingAnimProgress * PING_SCALE;
                float posOffset = sizes.cell / 2 - sizes.cell * pingScale / 2;

                nvg::BeginPath();
                nvg::FillColor(vec4(1., 1., 1., (1. - pingAnimProgress)));
                nvg::Rect(pos.x + posOffset, pos.y + posOffset, sizes.cell * pingScale, sizes.cell * pingScale);
                nvg::Fill();
            }
        }

        // Winning stroke
        for (uint j = 0; j < Match.endState.bingoLines.Length; j++) {
            BingoLine line = Match.endState.bingoLines[j];
            BingoDirection direction = line.bingoDirection;
            int i = line.offset;
            nvg::StrokeColor(BINGO_STROKE_COLOR);
            nvg::StrokeWidth(STROKE_WIDTH);
            if (direction == BingoDirection::Horizontal) {
                float yPos = Position.y + sizes.border + (sizes.cell / 2) + i * sizes.step;
                nvg::BeginPath();
                nvg::MoveTo(vec2(Position.x - sizes.border, yPos));
                nvg::LineTo(vec2(Position.x + BoardSize + sizes.border, yPos));
                nvg::Stroke();
            } else if (direction == BingoDirection::Vertical) {
                float xPos = Position.x + sizes.border + (sizes.cell / 2) + i * sizes.step;
                nvg::BeginPath();
                nvg::MoveTo(vec2(xPos, Position.y - sizes.border));
                nvg::LineTo(vec2(xPos, Position.y + BoardSize + sizes.border));
                nvg::Stroke();
            } else if (direction == BingoDirection::Diagonal) {
                nvg::BeginPath();
                nvg::MoveTo(vec2(Position.x - sizes.border, Position.y - sizes.border + i * (BoardSize + 2 * sizes.border)));
                nvg::LineTo(vec2(Position.x + BoardSize + sizes.border, Position.y - sizes.border + (1 - i) * (BoardSize + 2 * sizes.border)));
                nvg::Stroke();
            }

            nvg::ClosePath();
        }
    }

    vec2 CellPosition(int row, int col, BoardSizes sizes) {
        return vec2(Position.x + float(row) * sizes.step + sizes.border, Position.y + float(col) * sizes.step + sizes.border);
    }

    BoardSizes CalculateBoardSizes(uint cellsPerRow) {
        auto sizes = BoardSizes();
        sizes.border = BoardSize / (30. * cellsPerRow);
        sizes.cell = (BoardSize - sizes.border * (float(cellsPerRow) + 1.)) / float(cellsPerRow);
        sizes.step = sizes.cell + sizes.border;
        return sizes;
    }

    // A unit of drawing is 1/100th of the screen's width.
    float Unit() {
        return float(Draw::GetWidth() / 100.);
    }
}
