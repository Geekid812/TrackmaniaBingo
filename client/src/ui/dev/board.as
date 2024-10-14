
namespace UIDevBoard {
    bool PositionHelper = false;
    bool TileSelector = false;
    bool RenderEveryFrame = false;
    Board::DrawState DrawState(vec2(100, 100), 500, 5);
    array<Board::BatchedRect@>@ BatchedBoard = {};

    void Render() {
        DrawState.position = UI::SliderFloat2("Position", DrawState.position, 0, Draw::GetWidth());
        DrawState.size = UI::SliderFloat("Size", DrawState.size, 0, 1000);
        DrawState.resolution = UI::SliderInt("Resolution", DrawState.resolution, 1, 50);
        DrawState.CalculateInnerSizes();
        DrawState.ResizeTileData();

        PositionHelper = UI::Checkbox("Show Position Helper", PositionHelper);
        if (PositionHelper) Board::DrawPositionHelper(DrawState, vec4(.9, .1, .9, .5));

        RenderEveryFrame = UI::Checkbox("Compute Board Every Frame", RenderEveryFrame);
        if (RenderEveryFrame) BatchedBoard = Board::Render(DrawState);

        UI::SameLine();
        if (UI::Button(Icons::ThumbTack + " Compute Once")) {
            BatchedBoard = Board::Render(DrawState);
        }

        TileSelector = UI::Checkbox("Show Tile Selector", TileSelector);
        if (TileSelector) BoardTileSelector();

        Board::BatchDraw(BatchedBoard);
    }

    void BoardTileSelector() {
        UI::BeginChild("bingodevtileselector");
        if (UI::BeginTable("###bingodevtiles", DrawState.resolution, UI::TableFlags::SizingFixedFit | UI::TableFlags::Borders)) {
            
            UI::PushStyleColor(UI::Col::Button, vec4(0, 0, 0, 0));
            for (uint y = 0; y < DrawState.resolution; y++) {
                for (uint x = 0; x < DrawState.resolution; x++) {
                    UI::TableNextColumn();

                    Board::TileDraw@ data = DrawState.IndexTile(x, y);

                    if (UI::Button((data !is null ? "O" : " - ") + "###devtile" + x + ":" + y)) {
                        uint index = y * DrawState.resolution + x;

                        Board::TileDraw@ newData = data is null ? Board::TileDraw() : null;
                        @DrawState.tileData[index] = newData;
                    }
                }
            }

            UI::PopStyleColor();
            UI::EndTable();
        }
        UI::EndChild();
    }
}
