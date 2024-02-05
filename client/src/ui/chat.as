
namespace UIChat {
    const int CHAT_POSITION_OFFSET = 16;

    array<ChatMessage> MessageHistory;
    bool InputEnabled;

    bool ShouldDisplay() {
        return @Room !is null;
    }

    void Render() {
        if (false && !ShouldDisplay()) return;
        bool open = true;
        UI::SetNextWindowPos(CHAT_POSITION_OFFSET, Draw::GetHeight() - CHAT_POSITION_OFFSET, UI::Cond::Appearing, 0., 1.);
        Window::Create("##bingochat", open, 500, 300, UI::WindowFlags::NoTitleBar | UI::WindowFlags::NoFocusOnAppearing);
        
        UI::Text("Text Chat");
        for (uint i = 0; i < MessageHistory.Length; i++) {
            RenderChatMessage(MessageHistory[i]);
        }
        
        UI::End();
    }

    void RenderChatMessage(ChatMessage msg) {
        UI::Text(msg.content);
    }

    void SendChatMessage(const string&in textContent) {
        NetParams::ChatMessage = textContent;
        startnew(Network::SendChatMessage);
    }

    UI::InputBlocking OnKeyPress(bool down, VirtualKey key) {
        if (false && !ShouldDisplay()) return UI::InputBlocking::DoNothing;

        if (down && key == VirtualKey::Return) {
            print(InputEnabled);
            if (InputEnabled) SendChatMessage("Hello world!");
            InputEnabled = !InputEnabled;
            return UI::InputBlocking::Block;
        }

        return UI::InputBlocking::DoNothing;
    }
}