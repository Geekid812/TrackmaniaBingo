
namespace Board {
    float Width = 20.;
    vec2 Position = vec2(79, 1);
    const float StrokeWidth = 8.;
    const vec4 BingoStrokeColor = vec4(1, 0.6, 0, 0.9);

    void Draw() {
        if (!Room.InGame) return;

        float u = Unit();
        float BoardSize = Width * u;
        float BorderSize = BoardSize / 120.;
        float CellSize = (BoardSize - BorderSize * 6.) / 5.;
        float TLBoardX = Position.x * u;
        float TLBoardY = Position.y * u;
        nvg::BeginPath();

        // Board
        //nvg::Rect(TLBoardX, TLBoardY, BoardSize, BoardSize);
        //nvg::Fill();

        // Borders
        // Columns
        nvg::FillColor(vec4(.9, .9, .9, 1.));
        for (uint i = 0; i < 6; i++) {
            nvg::BeginPath();
            nvg::Rect(TLBoardX + float(i) * (CellSize + BorderSize), TLBoardY, BorderSize, BoardSize);
            nvg::Fill();
        }
        // Rows
        for (uint i = 0; i < 6; i++) {
            nvg::BeginPath();
            nvg::Rect(TLBoardX, TLBoardY + float(i) * (CellSize + BorderSize), BoardSize, BorderSize);
            nvg::Fill();
        }

        // Cell Fill Color
        for (uint i = 0; i < 5; i++) {
            for (uint j = 0; j < 5; j++) {
                auto Map = Room.MapList[j * 5 + i];
                nvg::BeginPath();
                vec4 color;
                switch (Map.ClaimedTeam) {
                    case 0:
                        color = vec4(.9, .3, .3, 1.);
                        break;
                    case 1:
                        color = vec4(.3, .3, .9, 1.);
                        break;
                    default:
                        color = vec4(.3, .3, .3, .8);
                }
                nvg::FillColor(color);
                nvg::Rect(TLBoardX + float(i) * (CellSize + BorderSize) + BorderSize, TLBoardY + float(j) * (CellSize + BorderSize) + BorderSize, CellSize, CellSize);
                nvg::Fill();
            }
        }

        // Winning stroke
        BingoDirection Direction = Room.EndState.BingoDirection;
        int i = Room.EndState.Offset;
        nvg::StrokeColor(BingoStrokeColor);
        nvg::StrokeWidth(StrokeWidth);
        if (Room.EndState.BingoDirection == BingoDirection::Horizontal) {
            float yPos = TLBoardY + BorderSize + (CellSize / 2) + i * (CellSize + BorderSize);
            nvg::BeginPath();
            nvg::MoveTo(vec2(TLBoardX - BorderSize, yPos));
            nvg::LineTo(vec2(TLBoardX + BoardSize + BorderSize, yPos));
            nvg::Stroke();
        } else if (Room.EndState.BingoDirection == BingoDirection::Vertical) {
            float xPos = TLBoardX + BorderSize + (CellSize / 2) + i * (CellSize + BorderSize);
            nvg::BeginPath();
            nvg::MoveTo(vec2(xPos, TLBoardY - BorderSize));
            nvg::LineTo(vec2(xPos, TLBoardY + BoardSize + BorderSize));
            nvg::Stroke();
        } else if (Room.EndState.BingoDirection == BingoDirection::Diagonal) {
            nvg::BeginPath();
            nvg::MoveTo(vec2(TLBoardX - BorderSize, TLBoardY - BorderSize + i * (BoardSize + 2 * BorderSize)));
            nvg::LineTo(vec2(TLBoardX + BoardSize + BorderSize, TLBoardY - BorderSize + (1 - i) * (BoardSize + 2 * BorderSize)));
            nvg::Stroke();
        }

        nvg::ClosePath();
    }

    // A unit of drawing is 1/100th of the screen's width.
    float Unit() {
        return float(Draw::GetWidth() / 100.);
    }
}