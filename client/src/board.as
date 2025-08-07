
namespace Board {
    // Controlled by BoardLocator
    float BoardSize;
    vec2 Position;
    bool Visible = true;

    // Controlled by Powerups
    uint ShiftRowColIndex;
    bool ShiftIsRow; // true = row; false = column
    bool ShiftIsForwards; // true = forward; false = backward
    int64 ShiftStartTimestamp;

    const uint64 SHIFTING_ANIMATION_TIME = 1000;
    const uint64 RAINBOW_COLOR_TICK_DURATION = 3000;

    const float STROKE_WIDTH = 8.;
    const float CELL_HIGHLIGHT_PADDING = 2.5; // Multiplier for BorderSize, inside offset
    const vec3 CELL_HIGHLIGHT_COLOR = vec3(.9, .9, .9);
    const vec4 BINGO_STROKE_COLOR = vec4(1, 0.6, 0, 0.9);
    const uint64 ANIMATION_START_TIME = 4000;

    const float TILE_SHADING_LIGHT_PERIOD = 1.5 / (2. * Math::PI);
    const float TILE_SHADING_STEP = 0.3;
    const float TILE_SHADING_VARIENCE = 0.08f;

    // Coordinates font size (proportional to the cell size, arbitrary unit)
    const float COORDINATES_FONT_SIZE = 2.5;
    const vec4 COORDINATES_FONT_COLOR = vec4(.9, .9, .9, .9);

    const vec3 POWERUP_COLOR = vec3(0., .9, .9);
    const vec3 RALLY_COLOR = vec3(.9, .6, .3);
    const vec3 SPECIALPOWER_COLOR = vec3(1., .8, 0.);
    const vec4 JAIL_BARS_COLOR = vec4(.3, .3, .3, .9);
    const float POWERUP_SYMBOL_FONT_SIZE = 5.;

    const uint64 PING_DURATION = 2500;
    const uint64 PING_PERIOD = 1250;
    const float PING_SCALE = 1.5;

    vec4 TileColorUnclaimed = vec4(.2, .2, .2, .8);
    vec4 BoardBorderColor = vec4(.7, .7, .7, 1.);
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

        if (tile.specialState == TileItemState::Rainbow) {
            float rainbowColorTick = float(Time::Now - Match.startTime) / RAINBOW_COLOR_TICK_DURATION;
            vec3 primaryColor = Match.teams[int(rainbowColorTick) % Match.teams.Length].color;
            vec3 secondaryColor = Match.teams[(int(rainbowColorTick) + 1) % Match.teams.Length].color;
            float transitionProgress = rainbowColorTick - int(rainbowColorTick);

            return UIColor::GetAlphaColor(primaryColor * (1 - transitionProgress) + secondaryColor * transitionProgress, BoardTilesAlpha);
        }

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
        array<CellHighlightDrawData@> cellHightlights;

        bool playingShiftAnimation = (Time::Now - ShiftStartTimestamp) <= SHIFTING_ANIMATION_TIME;
        float shiftDirection = ShiftIsForwards ? 1. : -1.;
        float animationShiftOffset = sizes.step * -shiftDirection + Animation::GetProgress(Time::Now - ShiftStartTimestamp, 0, SHIFTING_ANIMATION_TIME, Animation::Easing::CubicInOut) * sizes.step * shiftDirection;

        // Borders
        float timePerBorder = 1. / (cellsPerRow + 1);
        // Columns
        float columnsAnimProgress =
            Animation::GetProgress(animationTime, 0, 1500, Animation::Easing::SineOut);
        if (columnsAnimProgress <= 0.)
            return;
        nvg::FillColor(BoardBorderColor);
        for (uint i = 0; i <= cellsPerRow; i++) {
            // When animating a shifting row, we seperate the entire column in three arms.
            // The lower and upper arms are not animated while the middle arm is moving.
            // Right now it is not possible to have multiple animated rows/columns simultaneously.
            float upperArmLength = 0.;
            float lowerArmLength = 0.;
            float middleArmLength = 0.;

            if (playingShiftAnimation && ShiftIsRow) {
                // Shifting column
                upperArmLength = sizes.step * float(ShiftRowColIndex);
                middleArmLength = sizes.step;
                lowerArmLength = BoardSize - upperArmLength - middleArmLength;
            } else {
                // Normal column
                float animProgress =
                    Animation::GetProgress(columnsAnimProgress, i * timePerBorder, timePerBorder);
                upperArmLength = BoardSize * animProgress;
            }

            float colX = Position.x + float(i) * sizes.step;
            if (upperArmLength > 0.) {
                nvg::BeginPath();
                nvg::Rect(colX,
                        Position.y,
                        sizes.border,
                        upperArmLength);
                nvg::Fill();
            }

            if (middleArmLength > 0.) {
                nvg::BeginPath();
                nvg::Rect(colX + animationShiftOffset,
                        Position.y + upperArmLength,
                        sizes.border,
                        middleArmLength);
                nvg::Fill();
            }

            if (lowerArmLength > 0.) {
                nvg::BeginPath();
                nvg::Rect(colX,
                        Position.y + upperArmLength + middleArmLength,
                        sizes.border,
                        lowerArmLength);
                nvg::Fill();
            }
        }

        // Rows
        float rowsAnimProgress =
            Animation::GetProgress(animationTime, 500, 1500, Animation::Easing::SineOut);
        if (rowsAnimProgress <= 0.)
            return;
        for (uint i = 0; i <= cellsPerRow; i++) {
            float leftArmLength = 0.;
            float rightArmLength = 0.;
            float middleArmLength = 0.;

            if (playingShiftAnimation && !ShiftIsRow) {
                // Shifting row
                leftArmLength = sizes.step * float(ShiftRowColIndex);
                middleArmLength = sizes.step;
                rightArmLength = BoardSize - leftArmLength - middleArmLength;
            } else {
                // Normal row
                float animProgress =
                    Animation::GetProgress(rowsAnimProgress, i * timePerBorder, timePerBorder);
                leftArmLength = BoardSize * animProgress;
            }

            float rowY = Position.y + float(i) * sizes.step;
            if (leftArmLength > 0.) {
                nvg::BeginPath();
                nvg::Rect(Position.x,
                        rowY,
                        leftArmLength,
                        sizes.border);
                nvg::Fill();
            }

            if (middleArmLength > 0.) {
                nvg::BeginPath();
                nvg::Rect(Position.x + leftArmLength,
                        rowY + animationShiftOffset,
                        middleArmLength,
                        sizes.border);
                nvg::Fill();
            }

            if (rightArmLength > 0.) {
                nvg::BeginPath();
                nvg::Rect(Position.x + leftArmLength + middleArmLength,
                        rowY,
                        rightArmLength,
                        sizes.border);
                nvg::Fill();
            }
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
                cellPosition.x += (playingShiftAnimation && ShiftIsRow && y == ShiftRowColIndex ? animationShiftOffset : 0.);
                cellPosition.y += (playingShiftAnimation && !ShiftIsRow && x == ShiftRowColIndex ? animationShiftOffset : 0);
                color.w *= colorAnimProgress; // opacity modifier
                color.x *= lightness;
                color.y *= lightness;
                color.z *= lightness;

                nvg::BeginPath();
                nvg::FillColor(color);
                nvg::Rect(cellPosition.x, cellPosition.y, sizes.cell, sizes.cell);
                nvg::Fill();

                // If this cell has a special powerup or rally state, queue it for drawing marks and highlights later
                if (tile.specialState == TileItemState::HasPowerup || tile.specialState == TileItemState::HasSpecialPowerup || tile.specialState == TileItemState::Rally) {
                    cellHightlights.InsertLast(CellHighlightDrawData(y, x, true, (tile.specialState == TileItemState::HasSpecialPowerup ? SPECIALPOWER_COLOR : (tile.specialState == TileItemState::HasPowerup ? POWERUP_COLOR : RALLY_COLOR))));
                    DrawPowerupCellMark(tile.specialState, cellPosition, sizes);
                }

                // Draw jail bars
                if (tile.specialState == TileItemState::Jail) {
                    nvg::BeginPath();
                    nvg::FillColor(JAIL_BARS_COLOR);
                    nvg::Rect(cellPosition.x + sizes.cell * 1 / 7, cellPosition.y, sizes.cell / 7, sizes.cell);
                    nvg::Fill();

                    nvg::BeginPath();
                    nvg::Rect(cellPosition.x + sizes.cell * 3 / 7, cellPosition.y, sizes.cell / 7, sizes.cell);
                    nvg::Fill();

                    nvg::BeginPath();
                    nvg::Rect(cellPosition.x + sizes.cell * 5 / 7, cellPosition.y, sizes.cell / 7, sizes.cell);
                    nvg::Fill();
                }
            }
        }

        // Row/Column Coordinates
        if (isBoardHovered && colorAnimProgress >= 1.) {
            DrawCoordinates(cellsPerRow, sizes);
        }

        // Define cell highlight for current player location
        int currentTileIndex = Gamemaster::GetCurrentTileIndex();
        if (currentTileIndex != -1) {
            int row = currentTileIndex / cellsPerRow;
            int col = currentTileIndex % cellsPerRow;
            cellHightlights.InsertLast(CellHighlightDrawData(row, col));        
        }

        // Cell highlight
        float highlightBlinkValue = (Math::Sin(float(Time::Now) / 1000.) + 1) / 2;

        for (uint i = 0; i < cellHightlights.Length; i++) {
            CellHighlightDrawData@ currentHl = cellHightlights[i];
            vec4 highlightColor = vec4(currentHl.color * (0.9 + 0.2 * highlightBlinkValue), .9);
            float paddingValue = CELL_HIGHLIGHT_PADDING * (currentHl.animated ? Math::Clamp(highlightBlinkValue, 0.4, 0.8) : 1); // Currently not animated
            const float highlightWidth = sizes.border * paddingValue;
            const float highlightMarginOffset = sizes.border * (paddingValue - 1.);

            nvg::BeginPath();
            nvg::FillColor(highlightColor);
            nvg::Rect(Position.x + sizes.step * currentHl.col,
                      Position.y + sizes.step * currentHl.row,
                      sizes.cell + sizes.border * 2,
                      highlightWidth);
            nvg::Fill();
            nvg::BeginPath();
            nvg::Rect(Position.x + sizes.step * currentHl.col,
                      Position.y + sizes.step * (currentHl.row + 1) - highlightMarginOffset,
                      sizes.cell + sizes.border * 2,
                      highlightWidth);
            nvg::Fill();
            nvg::BeginPath();
            nvg::Rect(Position.x + sizes.step * currentHl.col,
                      Position.y + sizes.step * currentHl.row,
                      highlightWidth,
                      sizes.cell + sizes.border * 2);
            nvg::Fill();
            nvg::BeginPath();
            nvg::Rect(Position.x + sizes.step * (currentHl.col + 1) - highlightMarginOffset,
                      Position.y + sizes.step * currentHl.row,
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

    void DrawPowerupCellMark(TileItemState state, vec2 cellPosition, BoardSizes sizes) {
        float fontSize = POWERUP_SYMBOL_FONT_SIZE * sizes.cell * 0.1;
        string markSymbol;
        vec3 fontColor;

        switch (state) {
            case TileItemState::HasSpecialPowerup:
                markSymbol = Icons::Magic;
                fontColor = SPECIALPOWER_COLOR;
                break;
            case TileItemState::HasPowerup:
                markSymbol = Icons::Star;
                fontColor = POWERUP_COLOR;
                break;
            case TileItemState::Rally:
                markSymbol = Icons::Flag;
                fontColor = RALLY_COLOR;
                break;
        }

        nvg::BeginPath();
        nvg::FillColor(vec4(0., 0., 0., .3));
        nvg::RoundedRect(cellPosition.x + sizes.border * 5,
                    cellPosition.y + sizes.border * 5,
                    sizes.cell * 0.66,
                    sizes.cell * 0.66, sizes.cell);
        nvg::Fill();

        nvg::FillColor(vec4(fontColor, .5));
        nvg::FontSize(fontSize);
        nvg::TextAlign(nvg::Align::Center);
        nvg::Text(cellPosition + vec2(sizes.step / 2, sizes.step / 1.5), markSymbol);
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

            vec2 cellPosNumber = CellPosition(i, 0, sizes);
            cellPosNumber.y += fontSize;
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

    class CellHighlightDrawData {
        int row;
        int col;
        bool animated;
        vec3 color;

        CellHighlightDrawData(int row, int col, bool animated = false, vec3 color = CELL_HIGHLIGHT_COLOR) {
            this.row = row;
            this.col = col;
            this.animated = animated;
            this.color = color;
        }
    }
}
