
namespace UIDevWindows {
    void Render() {
        UI::Columns(2, "bingodevwindows", false);
        UIGameRoom::Visible = UI::Checkbox("UIGameRoom", UIGameRoom::Visible);
        UIInfoBar::Visible = UI::Checkbox("UIInfoBar", UIInfoBar::Visible);
        UIMapList::Visible = UI::Checkbox("UIMapList", UIMapList::Visible);
        UIPaintColor::Visible = UI::Checkbox("UIPaintColor", UIPaintColor::Visible);
        UITeams::Visible = UI::Checkbox("UITeams", UITeams::Visible);
        UITeamEditor::Visible = UI::Checkbox("UITeamEditor", UITeamEditor::Visible);
        Board::Visible = UI::Checkbox("Board", Board::Visible);

        UI::NextColumn();
        UIEditSettings::Visible = UI::Checkbox("UIEditSettings", UIEditSettings::Visible);
        UIChat::Visible = UI::Checkbox("UIChat", UIChat::Visible);
        UIMainWindow::Visible = UI::Checkbox("UIMainWindow", UIMainWindow::Visible);
        UINews::Visible = UI::Checkbox("UINews", UINews::Visible);
        UIDevActions::Visible = UI::Checkbox("UIDevActions", UIDevActions::Visible);
        BoardLocator::Visible = UI::Checkbox("BoardLocator", BoardLocator::Visible);
        UIItemSettings::Visible = UI::Checkbox("UIItemSettings", UIItemSettings::Visible);
        UIItemSelect::Visible = UI::Checkbox("UIItemSelect", UIItemSelect::Visible);

        UI::Columns(1);
    }
}
