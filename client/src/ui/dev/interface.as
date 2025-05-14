
namespace UIDevInterface {
    void Render() {
        Board::TileColorUnclaimed = UI::InputColor4("TileColorUnclaimed", Board::TileColorUnclaimed);
        Board::BoardBorderColor = UI::InputColor4("BoardBorderColor", Board::BoardBorderColor);
        Board::BoardTilesAlpha = UI::SliderFloat("BoardTilesAlpha", Board::BoardTilesAlpha, 0, 1);
    }
}
