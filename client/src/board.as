
namespace Board {
    const float TILE_ALPHA = 0.8;

    class BatchedRect {
        vec2 position;
        vec2 size;
        vec4 color;

        BatchedRect(float x, float y, float w, float h, vec4 color) {
            this.position = vec2(x, y);
            this.size = vec2(w, h);
            this.color = color;
        }
    }

    class DrawState {
        vec2 position;
        float size;
        uint resolution;
        BoardSizes sizes;
        vec4 borderColor = vec4(.9, .9, .9, 1.);
        array<TileDraw@> tileData = {};

        DrawState(vec2 position, float size, uint resolution) {
            this.position = position;
            this.size = size;
            this.resolution = resolution;
            if (resolution != 0) CalculateInnerSizes();
        }

        void CalculateInnerSizes() {
            uint cellsPerRow = this.resolution;

            BoardSizes sizes();
            sizes.borderSize = this.size / (30. * cellsPerRow);
            sizes.cellSize = (this.size - sizes.borderSize * (float(cellsPerRow) + 1.)) / float(cellsPerRow);
            sizes.stepLength = sizes.cellSize + sizes.borderSize;

            this.sizes = sizes;
        }

        void ResizeTileData() {
            uint numCells = this.resolution * this.resolution;

            this.tileData.Resize(numCells);
        }

        TileDraw@ IndexTile(uint x, uint y) {
            if (x >= this.resolution || y >= this.resolution) return null;
        
            return UncheckedIndexTile(x, y);
        }

        TileDraw@ UncheckedIndexTile(uint x, uint y) {
            uint index = y * this.resolution + x;
            return this.tileData[index];
        }
    }

    class TileDraw {
        vec3 tileColor;
    }

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
        float borderSize; // Width/Height of a border
        float cellSize; // Size of one inner cell (without borders)
        float stepLength; // Size of one cell, border + cell
    }

    class CellPing {
        uint64 time;
        uint cellId;
    }

    /**
     * Determine which color the tile should be.
     */
    vec4 GetTileFillColor(GameTile@ tile) {
        if (tile is null || tile.map is null)
            return vec4(0, 0, 0, .8);

        if (tile.paintColor != vec3())
            return UIColor::GetAlphaColor(tile.paintColor, .8);

        else if (tile.IsClaimed())
            return UIColor::GetAlphaColor(tile.LeadingRun().player.team.color, .8);

        else
            return vec4(.3, .3, .3, .8);
    }

    void BatchDraw(array<BatchedRect@>@ drawCalls) {
        uint n = drawCalls.Length;
        for (uint i = 0; i < n; i++) {
            BatchedRect@ rect = drawCalls[i];
            nvg::FillColor(rect.color);
            nvg::BeginPath();
            nvg::Rect(rect.position, rect.size);
            nvg::Fill();
        }
    }

    void RenderAll() {
        if (Match !is null && Gamemaster::IsBingoActive()) {
            BatchDraw(Match.boardDrawCalls);
        }
    }

    array<BatchedRect@>@ Render(DrawState@ state) {
        if (state is null) throw("Board: state is null.");

        array<BatchedRect@>@ drawCalls = {};
        DrawColumns(state, drawCalls);
        DrawRows(state, drawCalls);
        FillTiles(state, drawCalls);

        return drawCalls;
    }

    void DrawPositionHelper(DrawState@ state, vec4 color) {
        nvg::FillColor(color);
        nvg::BeginPath();
        nvg::Rect(state.position, state.size);
        nvg::Fill();
    }

    void DrawColumns(DrawState@ state, array<BatchedRect@>@ drawCalls) {
        uint columns = state.resolution + 1;

        for (uint i = 0; i < columns; i++) {
            float startX = state.position.x + (i * state.sizes.stepLength);
            float borderSize = state.sizes.borderSize;

            uint j = 0;
            while (j < state.resolution) {
                while (j < state.resolution && !IsColumnSegmentRendered(state, i, j)) j++;

                uint startJ = j;
                float startY = state.position.y + (j * state.sizes.stepLength);
                while (j < state.resolution && IsColumnSegmentRendered(state, i, j)) j++;

                if (j != startJ) {
                    float length = (j - startJ) * state.sizes.stepLength;

                    BatchedRect rect(startX, startY, borderSize, length + borderSize, state.borderColor);
                    drawCalls.InsertLast(rect);
                }
            }

        }
    }

    void DrawRows(DrawState@ state, array<BatchedRect@>@ drawCalls) {
        uint rows = state.resolution + 1;

        for (uint i = 0; i < rows; i++) {
            float startY = state.position.y + (i * state.sizes.stepLength);
            float borderSize = state.sizes.borderSize;

            uint j = 0;
            while (j < state.resolution) {
                while (j < state.resolution && !IsRowSegmentRendered(state, j, i)) j++;

                uint startJ = j;
                float startX = state.position.x + (j * state.sizes.stepLength);
                while (j < state.resolution && IsRowSegmentRendered(state, j, i)) j++;

                if (j != startJ) {
                    float length = (j - startJ) * state.sizes.stepLength;

                    BatchedRect rect(startX, startY, length + borderSize, borderSize, state.borderColor);
                    drawCalls.InsertLast(rect);
                }
            }
        }
    }

    void FillTiles(DrawState@ state, array<BatchedRect@>@ drawCalls) {
        for (uint x = 0; x < state.resolution; x++) {
            for (uint y = 0; y < state.resolution; y++) {
                TileDraw@ tileData = state.IndexTile(x, y);
                if (tileData is null) continue;

                vec2 startPos = GetCellPosition(state, x, y);
                BatchedRect rect(startPos.x, startPos.y, state.sizes.cellSize, state.sizes.cellSize, vec4(tileData.tileColor, TILE_ALPHA));
                drawCalls.InsertLast(rect);
            }
        }
    }

    bool IsColumnSegmentRendered(DrawState@ state, uint x, uint y) {        
        return state.IndexTile(x - 1, y) !is null || state.IndexTile(x, y) !is null;
    }

    bool IsRowSegmentRendered(DrawState@ state, uint x, uint y) {
        return state.IndexTile(x, y - 1) !is null || state.IndexTile(x, y) !is null;
    }

    vec2 GetCellPosition(DrawState@ state, uint x, uint y) {
        return vec2(state.position.x + state.sizes.borderSize + (x * state.sizes.stepLength), state.position.y + state.sizes.borderSize + (y * state.sizes.stepLength));
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
            nvg::Rect(Position.x + float(i) * sizes.stepLength, Position.y, sizes.borderSize, BoardSize * animProgress);
            nvg::Fill();
        }

        // Rows
        float rowsAnimProgress = Animation::GetProgress(animationTime, 500, 1500, Animation::Easing::SineOut);
        if (rowsAnimProgress <= 0.) return;
        for (uint i = 0; i <= cellsPerRow; i++) {
            float animProgress = Animation::GetProgress(rowsAnimProgress, i * timePerBorder, timePerBorder);
            nvg::BeginPath();
            nvg::Rect(Position.x, Position.y + float(i) * sizes.stepLength, BoardSize * animProgress, sizes.borderSize);
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
                nvg::Rect(cellPosition.x, cellPosition.y, sizes.cellSize, sizes.cellSize);
                nvg::Fill();
            }
        
        }

        // Cell highlight
        float highlightBlinkValue = (Math::Sin(float(Time::Now) / 1000.) + 1) / 2;
        float paddingValue = CELL_HIGHLIGHT_PADDING * (0.8 + 0.2 * highlightBlinkValue);
        const float highlightWidth = sizes.borderSize * paddingValue;
        const float highlightMarginOffset = sizes.borderSize * (paddingValue - 1.);
        CGameCtnChallenge@ currentMap = Playground::GetCurrentMap();
        int cellId = (@currentMap != null) ? Match.GetMapCellId(currentMap.EdChallengeId) : -1;
        if (cellId != -1) {
            int row = cellId / cellsPerRow;
            int col = cellId % cellsPerRow;
            nvg::BeginPath();
            nvg::FillColor(CELL_HIGHLIGHT_COLOR);
            nvg::Rect(Position.x + sizes.stepLength * col, Position.y + sizes.stepLength * row, sizes.cellSize + sizes.borderSize * 2, highlightWidth);
            nvg::Fill();
            nvg::BeginPath();
            nvg::Rect(Position.x + sizes.stepLength * col, Position.y + sizes.stepLength * (row + 1) - highlightMarginOffset, sizes.cellSize + sizes.borderSize * 2, highlightWidth);
            nvg::Fill();
            nvg::BeginPath();
            nvg::Rect(Position.x + sizes.stepLength * col, Position.y + sizes.stepLength * row, highlightWidth, sizes.cellSize + sizes.borderSize * 2);
            nvg::Fill();
            nvg::BeginPath();
            nvg::Rect(Position.x + sizes.stepLength * (col + 1) - highlightMarginOffset, Position.y + sizes.stepLength * row, highlightWidth, sizes.cellSize + sizes.borderSize * 2);
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
                float posOffset = sizes.cellSize / 2 - sizes.cellSize * pingScale / 2;

                nvg::BeginPath();
                nvg::FillColor(vec4(1., 1., 1., (1. - pingAnimProgress)));
                nvg::Rect(pos.x + posOffset, pos.y + posOffset, sizes.cellSize * pingScale, sizes.cellSize * pingScale);
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
                float yPos = Position.y + sizes.borderSize + (sizes.cellSize / 2) + i * sizes.stepLength;
                nvg::BeginPath();
                nvg::MoveTo(vec2(Position.x - sizes.borderSize, yPos));
                nvg::LineTo(vec2(Position.x + BoardSize + sizes.borderSize, yPos));
                nvg::Stroke();
            } else if (direction == BingoDirection::Vertical) {
                float xPos = Position.x + sizes.borderSize + (sizes.cellSize / 2) + i * sizes.stepLength;
                nvg::BeginPath();
                nvg::MoveTo(vec2(xPos, Position.y - sizes.borderSize));
                nvg::LineTo(vec2(xPos, Position.y + BoardSize + sizes.borderSize));
                nvg::Stroke();
            } else if (direction == BingoDirection::Diagonal) {
                nvg::BeginPath();
                nvg::MoveTo(vec2(Position.x - sizes.borderSize, Position.y - sizes.borderSize + i * (BoardSize + 2 * sizes.borderSize)));
                nvg::LineTo(vec2(Position.x + BoardSize + sizes.borderSize, Position.y - sizes.borderSize + (1 - i) * (BoardSize + 2 * sizes.borderSize)));
                nvg::Stroke();
            }

            nvg::ClosePath();
        }
    }

    uint TileId(uint x, uint y, uint resolution) {
        return y * resolution + x;
    }

    vec2 CellPosition(int row, int col, BoardSizes sizes) {
        return vec2(Position.x + float(row) * sizes.stepLength + sizes.borderSize, Position.y + float(col) * sizes.stepLength + sizes.borderSize);
    }

    BoardSizes CalculateBoardSizes(uint cellsPerRow) {
        auto sizes = BoardSizes();
        sizes.borderSize = BoardSize / (30. * cellsPerRow);
        sizes.cellSize = (BoardSize - sizes.borderSize * (float(cellsPerRow) + 1.)) / float(cellsPerRow);
        sizes.stepLength = sizes.cellSize + sizes.borderSize;
        return sizes;
    }

    // A unit of drawing is 1/100th of the screen's width.
    float Unit() {
        return float(Draw::GetWidth() / 100.);
    }
}
