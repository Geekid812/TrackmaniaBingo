
namespace Board {
    // Controlled by BoardLocator
    float BoardSize;
    vec2 Position;
    bool Visible = true;

    const float STROKE_WIDTH = 8.;
    const float CELL_HIGHLIGHT_PADDING = 2.5; // Multiplier for BorderSize, inside offset
    const vec3 CELL_HIGHLIGHT_COLOR = vec3(.9, .9, .9);
    const vec4 BINGO_STROKE_COLOR = vec4(1, 0.6, 0, 0.9);
    const uint64 ANIMATION_START_TIME = 4000;

    const float TILE_SHADING_LIGHT_PERIOD = 1.5 / (2. * Math::PI);
    const float TILE_SHADING_STEP = 0.3;
    const float TILE_SHADING_VARIENCE = 0.08f;

    // Coordinates font size (proportional to the cell size, arbitrary unit)
    const float COORDINATES_FONT_SIZE = 3.;
    const vec4 COORDINATES_FONT_COLOR = vec4(.9, .9, .9, .9);

    const uint64 PING_DURATION = 2500;
    const uint64 PING_PERIOD = 1250;
    const float PING_SCALE = 1.5;

    vec4 TileColorUnclaimed = vec4(.2, .2, .2, .8);
    vec4 BoardBorderColor = vec4(.65, .65, .65, 1.);
    float BoardTilesAlpha = .85f;

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
    vec4
    GetTileFillColor(GameTile @tile) {
        if (tile is null || tile.map is null)
            return vec4(0, 0, 0, BoardTilesAlpha);

        if (tile.paintColor != vec3())
            return UIColor::GetAlphaColor(tile.paintColor, BoardTilesAlpha);

        if (tile.IsClaimed()) {
            Team @tileOwnerTeam = Match.GetTeamWithId(tile.LeadingRun().teamId);

            if (@tileOwnerTeam !is null)
                return UIColor::GetAlphaColor(tileOwnerTeam.color, BoardTilesAlpha);
        }

        return TileColorUnclaimed;
    }

    void Draw() {
        if (!Visible)
            return;
        if (!Gamemaster::IsBingoActive())
            return;

        uint cellsPerRow = Match.config.gridSize;
        BoardSizes sizes = CalculateBoardSizes(cellsPerRow);
        bool isBoardHovered = UI::GetMousePos().x >= Position.x && UI::GetMousePos().y >= Position.y && UI::GetMousePos().x < Position.x + BoardSize && UI::GetMousePos().y < Position.y + BoardSize;
        nvg::BeginPath();

        int64 animationTime = Time::Now - Match.startTime + ANIMATION_START_TIME;

        // Borders
        float timePerBorder = 1. / (cellsPerRow + 1);
        // Columns
        float columnsAnimProgress =
            Animation::GetProgress(animationTime, 0, 1500, Animation::Easing::SineOut);
        if (columnsAnimProgress <= 0.)
            return;
        nvg::FillColor(BoardBorderColor);
        for (uint i = 0; i <= cellsPerRow; i++) {
            float animProgress =
                Animation::GetProgress(columnsAnimProgress, i * timePerBorder, timePerBorder);
            nvg::BeginPath();
            nvg::Rect(Position.x + float(i) * sizes.step,
                      Position.y,
                      sizes.border,
                      BoardSize * animProgress);
            nvg::Fill();
        }

        // Rows
        float rowsAnimProgress =
            Animation::GetProgress(animationTime, 500, 1500, Animation::Easing::SineOut);
        if (rowsAnimProgress <= 0.)
            return;
        for (uint i = 0; i <= cellsPerRow; i++) {
            float animProgress =
                Animation::GetProgress(rowsAnimProgress, i * timePerBorder, timePerBorder);
            nvg::BeginPath();
            nvg::Rect(Position.x,
                      Position.y + float(i) * sizes.step,
                      BoardSize * animProgress,
                      sizes.border);
            nvg::Fill();
        }

        // Cell Fill Color
        float colorAnimProgress = Animation::GetProgress(animationTime, 2000, 500);
        float lightShadingTime = -float(Time::Now - Match.startTime) / 1000.;
        for (uint x = 0; x < cellsPerRow; x++) {
            float tileLightShading =
                Math::Sin((lightShadingTime + x * TILE_SHADING_STEP) / TILE_SHADING_LIGHT_PERIOD);
            float lightness = 1. + TILE_SHADING_VARIENCE * tileLightShading * 0.5;

            for (uint y = 0; y < cellsPerRow; y++) {
                GameTile @tile = Gamemaster::GetTileOnGrid(x, y);

                vec2 cellPosition = CellPosition(x, y, sizes);
                vec4 color = GetTileFillColor(tile);
                color.w *= colorAnimProgress; // opacity modifier
                color.x *= lightness;
                color.y *= lightness;
                color.z *= lightness;

                nvg::BeginPath();
                nvg::FillColor(color);
                nvg::Rect(cellPosition.x, cellPosition.y, sizes.cell, sizes.cell);
                nvg::Fill();
            }
        }

        // Row/Column Coordinates
        if (isBoardHovered && colorAnimProgress >= 1.) {
            DrawCoordinates(cellsPerRow, sizes);
        }

        // Cell highlight
        float highlightBlinkValue = (Math::Sin(float(Time::Now) / 500.) + 1) / 2;
        vec4 highlightColor = vec4(CELL_HIGHLIGHT_COLOR * (0.9 + 0.2 * highlightBlinkValue), .9);
        float paddingValue = CELL_HIGHLIGHT_PADDING * (1); // Currently not animated
        const float highlightWidth = sizes.border * paddingValue;
        const float highlightMarginOffset = sizes.border * (paddingValue - 1.);

        int currentTileIndex = Gamemaster::GetCurrentTileIndex();
        if (currentTileIndex != -1) {
            int row = currentTileIndex / cellsPerRow;
            int col = currentTileIndex % cellsPerRow;
            nvg::BeginPath();
            nvg::FillColor(highlightColor);
            nvg::Rect(Position.x + sizes.step * col,
                      Position.y + sizes.step * row,
                      sizes.cell + sizes.border * 2,
                      highlightWidth);
            nvg::Fill();
            nvg::BeginPath();
            nvg::Rect(Position.x + sizes.step * col,
                      Position.y + sizes.step * (row + 1) - highlightMarginOffset,
                      sizes.cell + sizes.border * 2,
                      highlightWidth);
            nvg::Fill();
            nvg::BeginPath();
            nvg::Rect(Position.x + sizes.step * col,
                      Position.y + sizes.step * row,
                      highlightWidth,
                      sizes.cell + sizes.border * 2);
            nvg::Fill();
            nvg::BeginPath();
            nvg::Rect(Position.x + sizes.step * (col + 1) - highlightMarginOffset,
                      Position.y + sizes.step * row,
                      highlightWidth,
                      sizes.cell + sizes.border * 2);
            nvg::Fill();
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
                nvg::MoveTo(vec2(Position.x - sizes.border,
                                 Position.y - sizes.border + i * (BoardSize + 2 * sizes.border)));
                nvg::LineTo(
                    vec2(Position.x + BoardSize + sizes.border,
                         Position.y - sizes.border + (1 - i) * (BoardSize + 2 * sizes.border)));
                nvg::Stroke();
            }

            nvg::ClosePath();
        }
    }

    void DrawCoordinates(uint cellsPerRow, BoardSizes sizes) {
        float fontSize = COORDINATES_FONT_SIZE * sizes.cell * 0.1;
        float nudgeUnit = sizes.border; // small unit of measurement to make adjustments to the position of text (nothing aligns properly by default)

        nvg::FillColor(COORDINATES_FONT_COLOR);
        nvg::FontSize(fontSize);
        for (uint i = 0; i < cellsPerRow; i++) {
            vec2 cellPosLetter = CellPosition(0, i, sizes);
            cellPosLetter.y += fontSize;
            cellPosLetter.x += nudgeUnit;

            vec2 cellPosNumber = CellPosition(i, cellsPerRow, sizes);
            cellPosNumber.y -= sizes.border + nudgeUnit;
            cellPosNumber.x += sizes.cell;

            string letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
            nvg::TextAlign(nvg::Align::Left);
            nvg::Text(cellPosLetter, letters.SubStr(i % 26, 1));

            nvg::TextAlign(nvg::Align::Right);
            nvg::Text(cellPosNumber, tostring(i + 1));
        }
    }

    vec2 CellPosition(int row, int col, BoardSizes sizes) {
        return vec2(Position.x + float(row) * sizes.step + sizes.border,
                    Position.y + float(col) * sizes.step + sizes.border);
    }

    BoardSizes CalculateBoardSizes(uint cellsPerRow) {
        auto sizes = BoardSizes();
        sizes.border = BoardSize / (30. * cellsPerRow);
        sizes.cell = (BoardSize - sizes.border * (float(cellsPerRow) + 1.)) / float(cellsPerRow);
        sizes.step = sizes.cell + sizes.border;
        return sizes;
    }

    // A unit of drawing is 1/100th of the screen's width.
    float Unit() { return float(Draw::GetWidth() / 100.); }
}
