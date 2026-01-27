
namespace Layout {
    float GetPadding(float windowSize, float elementSize, float alignment) {
        return Math::Max((windowSize - elementSize) * alignment, 0.);
    }

    void BeginLabelAlign() { UI::SetCursorPos(UI::GetCursorPos() + vec2(0, 4)); }

    void EndLabelAlign() { UI::SetCursorPos(UI::GetCursorPos() - vec2(0, 4)); }

    void MoveTo(float x) { UI::SetCursorPos(vec2(x, UI::GetCursorPos().y)); }

    void MoveToY(float y) { UI::SetCursorPos(vec2(UI::GetCursorPos().x, y)); }

    float ButtonWidth(const string& in text) {
        return UI::MeasureString(text).x +
               2 * UI::GetStyleVarVec2(UI::StyleVar::FramePadding).x;
    }

    void AlignButton(const string& in text, float alignment) {
        float width = ButtonWidth(text);
        MoveTo(GetPadding(UI::GetWindowSize().x, width, alignment));
    }

    void AlignText(const string& in text, float alignment) {
        MoveTo(GetPadding(
            UI::GetWindowSize().x, UI::MeasureString(text).x, alignment));
    }
}
