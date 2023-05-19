
namespace UITools {
    void AlignedLabel(const string&in text) {
        LayoutTools::BeginLabelAlign();
        UI::Text(text);
        UI::SameLine();
        LayoutTools::EndLabelAlign();
    }

    class InputResult {
        int value;
        int state;

        InputResult(int value, int state) {
            this.value = value;
            this.state = state;
        }
    }

    InputResult MixedInputButton(const string&in label, const string&in id, int min, int max, int step, int value, int state) {
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
            UI::PushStyleVar(UI::StyleVar::FramePadding, vec2((80 - Draw::MeasureString(label, Font::Regular).x) / 2, 4));
            if (UI::Button(label + "##button" + id)) {
                state = 0b11;
            }
            UI::PopStyleVar();
            UIColor::Reset();
        }
        UI::SameLine();
        UI::BeginDisabled(value >= max);
        UI::PushStyleVar(UI::StyleVar::FramePadding, vec2(9, 4));
        if (UI::Button("+##plus" + id)) {
            value += step;
        }
        UI::PopStyleVar();
        UI::EndDisabled();

        return InputResult(Math::Clamp(value, min, max), state);
    }

    void SectionHeader(string&in text) {
        UI::PushFont(Font::Bold);
        UI::Text(text);
        UI::PopFont();
    }

    void HelpTooltip(const string&in content) {
        UI::Text("\\$666" + Icons::QuestionCircle);
        if (UI::IsItemHovered()) {
            UI::BeginTooltip();
            UI::Text(content);
            UI::EndTooltip();
        }
    }

    bool grzero(int x) { return x > 0; }
    int toint(bool x) { return x ? 1 : 0; } 
}
