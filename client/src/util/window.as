namespace Window {
    void Create(const string&in title, bool&out open, int w, int h, int flags = UI::WindowFlags::NoCollapse) {
        UI::SetNextWindowSize(w, h, UI::Cond::Appearing);
        UI::Begin(title, open, flags);
    }
}
