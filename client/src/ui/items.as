
namespace UITools {
    void AlignedLabel(const string& in text) {
        Layout::BeginLabelAlign();
        UI::Text(text);
        UI::SameLine();
        Layout::EndLabelAlign();
    }

    class InputResult {
        int value;
        int state;

        InputResult(int value, int state) {
            this.value = value;
            this.state = state;
        }

    }

    InputResult
    MixedInputButton(const string& in label,
                     const string& in id,
                     int min,
                     int max,
                     int step,
                     int value,
                     int state) {

        UI::BeginDisabled(value <= min);
        UI::PushStyleVar(UI::StyleVar::FramePadding, vec2(9, 4));
        if (UI::Button("-##minus" + id)) {
            value -= step;
        }
        UI::PopStyleVar();
        UI::EndDisabled();
        UI::SameLine();

        // 0b10: input element is active
        // 0b01: input element was just opened
#if TMNEXT
        UI::SetCursorPos(UI::GetCursorPos() - vec2(0, 4));
#endif
        if (grzero(state & 0b10)) {
            if (grzero(state & 0b01)) {
                UI::SetKeyboardFocusHere();
            }
            UI::SetNextItemWidth(80);
            UI::PushStyleColor(UI::Col::FrameBg, vec4(.1, .1, .1, .8));
            value = UI::InputInt("##" + id, value, 0);
            UI::PopStyleColor();
            state &= toint(UI::IsItemActive() || grzero(state & 0b01)) << 1;
        } else {
            UIColor::Dark();
            UI::PushStyleVar(UI::StyleVar::FramePadding,
                             vec2((80 - Draw::MeasureString(label, Font::Current()).x) / 2, 4));
            if (UI::Button(label + "##button" + id)) {
                state = 0b11;
            }
            UI::PopStyleVar();
            UIColor::Reset();
        }
        UI::SameLine();
#if TMNEXT
        UI::SetCursorPos(UI::GetCursorPos() - vec2(0, 4));
#endif
        UI::BeginDisabled(value >= max);
        UI::PushStyleVar(UI::StyleVar::FramePadding, vec2(9, 4));
        if (UI::Button("+##plus" + id)) {
            value += step;
        }
        UI::PopStyleVar();
        UI::EndDisabled();

        return InputResult(Math::Clamp(value, min, max), state);
    }

    void SectionHeader(string& in text) {
        Font::Set(Font::Style::Bold, Font::Size::Large);
        UI::Text(text);
        Font::Unset();
    }

    void HelpTooltip(const string& in content) {
        UI::Text("\\$666" + Icons::QuestionCircle);
        if (UI::IsItemHovered()) {
            UI::BeginTooltip();
            UI::Text(content);
            UI::EndTooltip();
        }
    }

    void ErrorMessage(const string& in type) {
        string err = Network::GetError(type);
        if (err != "") {
            string message = "\\$ff8" + err;
            if (err == "timeout")
                message = "\\$888It looks like the server is not responding.\nIf this is an issue, "
                          "try reconnecting to the server.";
            UI::TextWrapped(message);

            if (err == "timeout") {
                UI::SameLine();
                ReconnectButton();
            }
        }
    }

    void ReconnectButton() {
        if (UI::Button(Icons::Globe + " Reconnect"))
            startnew(function() {
                Network::CloseConnection();
                Network::Connect();
            });
    }

    void ConnectingIndicator() {
        if (Network::GetState() == ConnectionState::Connecting) {
            UI::SameLine();
            UI::Text("\\$58f" + GetConnectingIcon() + " \\$zConnecting to server...");
        }
    }

    string GetConnectingIcon() {
        int sequence = int(Time::Now / 333) % 3;
        if (sequence == 0)
            return Icons::Kenney::SignalLow;
        if (sequence == 1)
            return Icons::Kenney::SignalMedium;
        return Icons::Kenney::SignalHigh;
    }

    void PlayerTag(Player player) {
        vec3 color = player.team.color;
        UI::Text("\\$" + UIColor::GetHex(color) + player.name);
        if (UI::IsItemHovered()) {
            UI::BeginTooltip();
            UIProfile::RenderProfile(player.profile, false);
            UI::EndTooltip();
        }
    }

    void CenterText(const string& in text) {
        UI::Font @font = Font::Current();
        Layout::MoveTo(Layout::GetPadding(
            UI::GetWindowSize().x, Draw::MeasureString(text, font, font.FontSize).x, 0.5));
        UI::Text(text);
    }

    void CenterTextDisabled(const string& in text) {
        UI::Font @font = Font::Current();
        Layout::MoveTo(Layout::GetPadding(
            UI::GetWindowSize().x, Draw::MeasureString(text, font, font.FontSize).x, 0.5));
        UI::TextDisabled(text);
    }

    bool grzero(int x) { return x > 0; }

    int toint(bool x) { return x ? 1 : 0; }
}
