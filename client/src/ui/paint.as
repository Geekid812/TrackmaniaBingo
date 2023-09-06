
namespace UIPaintColor {
    bool Visible = false;
    array<vec3> ColorHistory = {};
    vec3 InputColor = vec3();
    vec3 SelectedColor = vec3();

    void Render() {
        if (!Visible) return;

        UI::Begin(Icons::PaintBrush + " Bingo Paint Mode", Visible, UI::WindowFlags::NoCollapse | UI::WindowFlags::AlwaysAutoResize);
        InputColor = UI::InputColor3("Selected Color", InputColor);
        if (!UI::IsItemFocused()) {
            if (InputColor != SelectedColor) ColorHistory.InsertLast(SelectedColor);
            SelectedColor = InputColor;
        }

        for (uint i = 0; i < ColorHistory.Length; i++) {
            if (i % 5 != 0) UI::SameLine();
            vec3 color = ColorHistory[i];
            UIColor::Custom(color);
            if (UI::Button(UIColor::GetHex(color))) {
                SelectedColor = color;
                InputColor = color;
            }
            UIColor::Reset();
        }
        UI::End();

        if (!Visible) ColorHistory = {};
    }
}