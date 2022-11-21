
namespace Board {
    // Controlled by BoardLocator
    float BoardSize;
    vec2 Position;

    const float StrokeWidth = 8.;
    const vec4 BingoStrokeColor = vec4(1, 0.6, 0, 0.9);

    void Draw() {
        if (!Room.InGame) return;

        float BorderSize = BoardSize / 120.;
        float CellSize = (BoardSize - BorderSize * 6.) / 5.;
        nvg::BeginPath();

        // Board
        //nvg::Rect(Position.x, Position.y, BoardSize, BoardSize);
        //nvg::Fill();

        // Borders
        // Columns
        nvg::FillColor(vec4(.9, .9, .9, 1.));
        for (uint i = 0; i < 6; i++) {
            nvg::BeginPath();
            nvg::Rect(Position.x + float(i) * (CellSize + BorderSize), Position.y, BorderSize, BoardSize);
            nvg::Fill();
        }
        // Rows
        for (uint i = 0; i < 6; i++) {
            nvg::BeginPath();
            nvg::Rect(Position.x, Position.y + float(i) * (CellSize + BorderSize), BoardSize, BorderSize);
            nvg::Fill();
        }

        // Cell Fill Color
        for (uint i = 0; i < 5; i++) {
            for (uint j = 0; j < 5; j++) {
                auto Map = Room.MapList[j * 5 + i];
                nvg::BeginPath();
                vec4 color;
                if (Map.ClaimedTeam is null)
                    color = vec4(.3, .3, .3, .8);
                else 
                    color = UIColor::GetAlphaColor(Map.ClaimedTeam.Color, .8);
                nvg::FillColor(color);
                nvg::Rect(Position.x + float(i) * (CellSize + BorderSize) + BorderSize, Position.y + float(j) * (CellSize + BorderSize) + BorderSize, CellSize, CellSize);
                nvg::Fill();
            }
        }

        // Winning stroke
        BingoDirection Direction = Room.EndState.BingoDirection;
        int i = Room.EndState.Offset;
        nvg::StrokeColor(BingoStrokeColor);
        nvg::StrokeWidth(StrokeWidth);
        if (Room.EndState.BingoDirection == BingoDirection::Horizontal) {
            float yPos = Position.y + BorderSize + (CellSize / 2) + i * (CellSize + BorderSize);
            nvg::BeginPath();
            nvg::MoveTo(vec2(Position.x - BorderSize, yPos));
            nvg::LineTo(vec2(Position.x + BoardSize + BorderSize, yPos));
            nvg::Stroke();
        } else if (Room.EndState.BingoDirection == BingoDirection::Vertical) {
            float xPos = Position.x + BorderSize + (CellSize / 2) + i * (CellSize + BorderSize);
            nvg::BeginPath();
            nvg::MoveTo(vec2(xPos, Position.y - BorderSize));
            nvg::LineTo(vec2(xPos, Position.y + BoardSize + BorderSize));
            nvg::Stroke();
        } else if (Room.EndState.BingoDirection == BingoDirection::Diagonal) {
            nvg::BeginPath();
            nvg::MoveTo(vec2(Position.x - BorderSize, Position.y - BorderSize + i * (BoardSize + 2 * BorderSize)));
            nvg::LineTo(vec2(Position.x + BoardSize + BorderSize, Position.y - BorderSize + (1 - i) * (BoardSize + 2 * BorderSize)));
            nvg::Stroke();
        }

        nvg::ClosePath();
    }

    // A unit of drawing is 1/100th of the screen's width.
    float Unit() {
        return float(Draw::GetWidth() / 100.);
    }
}