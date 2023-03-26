
namespace UIRoomMenu {
    string JoinCodeInput;
    bool JoinCodeVisible;

    void RoomCodeInput() {
        UITools::AlignedLabel("Room code");
        UI::SetNextItemWidth(200);
        JoinCodeInput = UI::InputText("##bingoroomcode", JoinCodeInput, false, UI::InputTextFlags::CharsUppercase | (JoinCodeVisible? 0 : UI::InputTextFlags::Password));
        UI::SameLine();
        bool colored = false;
        if (!JoinCodeVisible) {
            colored = true;
            UIColor::Gray();
        }
        if (UI::Button(JoinCodeVisible ? Icons::Eye : Icons::EyeSlash)) {
            JoinCodeVisible = !JoinCodeVisible;
        }
        if (colored) UIColor::Reset();
        if (UI::IsItemHovered()) {
            UI::BeginTooltip();
            UI::Text(JoinCodeVisible ? "Room code \\$8f8visible" : "Room code \\$888hidden");
            UI::EndTooltip();
        }
    }

    void RoomMenu() {
        UITools::SectionHeader("Join a Private Room");
        RoomCodeInput();

        UI::BeginDisabled(!Config::CanPlay || Network::GetState() != ConnectionState::Connected);
        if (UI::Button("Join Room") && JoinCodeInput.Length >= 6) {
            startnew(Network::JoinRoom);
        }
        UI::EndDisabled();
        Window::ConnectingIndicator();

        UITools::SectionHeader("Public Rooms");
        // TODO: room list
    }
}