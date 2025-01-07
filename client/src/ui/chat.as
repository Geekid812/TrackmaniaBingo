
namespace UIChat {
    const int CHAT_POSITION_OFFSET = 16;
    const int CHAT_INPUT_HEIGHT = 42;
    const int CHAT_WINDOW_MARGIN = 8;
    const uint64 CHAT_FADE_TIME_MILLIS = 500;
    const uint64 CHAT_HOLD_TIME_MILLIS = 500;
    const uint64 CHAT_MESSAGE_EXPIRE_SECONDS = 45;
    const float MIN_CHAT_OPACITY = 0;
    const float MAX_CHAT_OPACITY = 0.7;
    array<ChatMessage> MessageHistory;
    bool InputEnabled;
    bool InputFocused;
    uint64 LastMessageTimestamp;
    string ChatInput;

    bool ShouldDisplay() {
        return @Room !is null || @Match !is null;
    }

    void RemoveExpiredMessages() {
        uint i = 0;
        while (i < MessageHistory.Length) {
            if (Time::Stamp - MessageHistory[i].timestamp >= CHAT_MESSAGE_EXPIRE_SECONDS)
                MessageHistory.RemoveAt(i);
            else
                i++;
        }
    }

    void Render() {
        if (!ShouldDisplay()) return;
        RemoveExpiredMessages();
        bool open = true;

        vec4 color = UI::GetStyleColor(UI::Col::WindowBg);
        int64 millisSinceMessage = Time::Now - LastMessageTimestamp;
        color.w = Math::Clamp(1. - float(millisSinceMessage - CHAT_HOLD_TIME_MILLIS) / CHAT_FADE_TIME_MILLIS, MIN_CHAT_OPACITY, MAX_CHAT_OPACITY);
        UI::PushStyleColor(UI::Col::WindowBg, color);

        UI::SetNextWindowPos(CHAT_POSITION_OFFSET, Draw::GetHeight() - CHAT_POSITION_OFFSET - CHAT_INPUT_HEIGHT - CHAT_WINDOW_MARGIN, UI::Cond::Appearing, 0., 1.);
        Window::Create("##bingochat", open, 500, 200, UI::WindowFlags::NoTitleBar | UI::WindowFlags::NoScrollbar | UI::WindowFlags::NoFocusOnAppearing | UI::WindowFlags::NoInputs | UI::WindowFlags::NoMove | UI::WindowFlags::NoResize);
        
        // add a buffer zone to the chat window so that new messages appear at the bottom
        for (uint i = 0; i < 10 - MessageHistory.Length; i++)
            UI::NewLine();

        for (uint i = 0; i < MessageHistory.Length; i++) {
            RenderChatMessage(MessageHistory[i]);
        }
        UI::SetScrollHereY();
        UI::End();
        UI::PopStyleColor();

        UI::PushStyleColor(UI::Col::WindowBg, vec4(0.));
        UI::PushStyleVar(UI::StyleVar::WindowPadding, vec2(0.));

        UI::SetNextWindowPos(CHAT_POSITION_OFFSET, Draw::GetHeight() - CHAT_POSITION_OFFSET, UI::Cond::Appearing, 0., 1.);
        Window::Create("##bingoinput", open, 500, CHAT_INPUT_HEIGHT, UI::WindowFlags::AlwaysAutoResize | UI::WindowFlags::NoTitleBar | UI::WindowFlags::NoMove | UI::WindowFlags::NoResize);


        if (InputEnabled) {
            UI::SetKeyboardFocusHere();
            InputEnabled = false;
        }
        UI::PushStyleColor(UI::Col::FrameBg, vec4(0., 0., 0., InputFocused ? MAX_CHAT_OPACITY : 0.));
        UI::SetNextItemWidth(500);

        bool submitted = false;
        ChatInput = UI::InputText("##inputtext", ChatInput, submitted, UI::InputTextFlags::EnterReturnsTrue);
        InputFocused = UI::IsItemActive();

        if (submitted && ChatInput != "") {
            SendChatMessage(ChatInput);
            ChatInput = "";
        }

        UI::PopStyleColor();
        UI::End();  
        UI::PopStyleVar();
        UI::PopStyleColor();
    }

    void RenderChatMessage(ChatMessage msg) {
        Player@ messageAuthor = Gamemaster::IsBingoActive() ? Match.GetPlayer(msg.uid) : null;

        Font::Set(Font::Style::Bold, Font::Size::Medium);
        UI::Text("\\$" + (messageAuthor is null ? "ccc" : UIColor::GetHex(messageAuthor.team.color)) + msg.name + ":");
        Font::Unset();
        
        UI::SameLine();

        Font::Set(Font::Style::Regular, Font::Size::Medium);
        UI::TextWrappedWindow(msg.content);
        Font::Unset();
    }

    void SendChatMessage(const string&in textContent) {
        NetParams::ChatMessage = textContent;
        startnew(Network::SendChatMessage);
    }

    UI::InputBlocking OnKeyPress(bool down, VirtualKey key) {
        if (!ShouldDisplay()) return UI::InputBlocking::DoNothing;

        if (down && key == VirtualKey::Return) {
            InputEnabled = !InputEnabled;
            return UI::InputBlocking::Block;
        }

        return UI::InputBlocking::DoNothing;
    }
}
