
namespace UIColor {

    string[] HexChars = {"0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "A", "B", "C", "D", "E", "F"};

    void Red() {
        Color(vec4(1., .2, .2, 1.), vec4(1., .4, .4, 1.), vec4(1., .6, .6, 1.));
    }

    void Blue() {
        Color(vec4(.2, .2, 1., 1.), vec4(.4, .4, 1., 1.), vec4(.6, .6, 1., 1.));
    }

    void DarkGreen() {
        Color(vec4(.1, .5, .1, 1.), vec4(.2, .5, .2, 1.), vec4(.3, .5, .3, 1.));
    }

    void DarkRed() {
        Color(vec4(.5, .1, .1, 1.), vec4(.5, .2, .2, 1.), vec4(.5, .3, .3, 1.));
    }

    void Cyan() {
        Color(vec4(.0, .6, .6, 1.), vec4(.0, .7, .7, 1.), vec4(.0, .8, .8, 1.));
    }

    void Lime() {
        Color(vec4(.4, .7, .4, 1.), vec4(.5, .8, .5, 1.), vec4(.6, .9, .6, 1.));
    }

    void Gray() {
        Color(vec4(.2, .2, .2, 1.), vec4(.3, .3, .3, 1.), vec4(.4, .4, .4, 1.));
    }

    void Dark() {
        Color(vec4(.1, .1, .1, .8), vec4(.2, .2, .2, .8), vec4(.3, .3, .3, .8)); 
    }

    void Orange() {
        Color(vec4(.7, .4, .1, 1.), vec4(.8, .5, .1, 1.), vec4(.9, .6, .1, 1.));
    }

    void Crimson() {
        Color(vec4(.75, .25, .25, 1.), vec4(.9, .35, .35, 1.), vec4(.95, .4, .4, 1.));
    }

    void LightGray() {
        Color(vec4(.6, .6, .6, 1.), vec4(.6, .6, .6, 1.), vec4(.6, .6, .6, 1.));
    }

    void Color(vec4 base, vec4 accent, vec4 active) {
        UI::PushStyleColor(UI::Col::CheckMark, base);
        UI::PushStyleColor(UI::Col::Button, base);
        UI::PushStyleColor(UI::Col::ButtonHovered, accent);
        UI::PushStyleColor(UI::Col::ButtonActive, active);
        UI::PushStyleColor(UI::Col::Tab, base);
        UI::PushStyleColor(UI::Col::TabHovered, accent);
        UI::PushStyleColor(UI::Col::TabActive, active);
        UI::PushStyleColor(UI::Col::FrameBgHovered, Brighten(base, .4));
    }

    void Custom(vec3 color){
        Color(GetAlphaColor(Brighten(color, .8), 1), GetAlphaColor(Brighten(color, .9), 1), GetAlphaColor(Brighten(color, 1), 1));
    }

    void Reset() {
        UI::PopStyleColor(8);
    }

    vec4 GetAlphaColor(vec3 color, float alpha) {
        return vec4(color.x, color.y, color.z, alpha);
    }

    string GetHex(vec3 color){
        string hex = "";
        for(int i = 0; i < 3; i++){
            float col;
            if (i == 0) col = color.x;
            else if (i == 1) col = color.y;
            else col = color.z;

            int c = int(col * 15);
            hex += HexChars[c % 16];
        }
        return hex;
    }

    vec3 Brighten(vec3 color, float amount){
        return vec3(color.x * amount, color.y * amount, color.z * amount);
    }

    vec4 Brighten(vec4 color, float amount) {
        return vec4(color.x * amount, color.y * amount, color.z * amount, color.w);
    }
    
    vec3 FromRgb(uint8 r, uint8 g, uint8 b) {
        return vec3(r / 255., g / 255., b / 255.);
    }
}
