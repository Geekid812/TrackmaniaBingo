
namespace LayoutTools {
    float GetPadding(float windowSize, float elementSize, float alignment) {
        return (windowSize - elementSize) * alignment;
    }

    void BeginLabelAlign() {
        UI::SetCursorPos(UI::GetCursorPos() + vec2(0, 4));
    }

    void EndLabelAlign() {
        UI::SetCursorPos(UI::GetCursorPos() - vec2(0, 4));
    }

    void MoveTo(float x) {
        UI::SetCursorPos(vec2(x, UI::GetCursorPos().y));
    }
}