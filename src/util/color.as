
namespace UIColor {

    string[] HexChars = {"0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "A", "B", "C", "D", "E", "F"};

    void Red() {
        UI::PushStyleColor(UI::Col::Button, vec4(1., .2, .2, 1.));
        UI::PushStyleColor(UI::Col::ButtonHovered, vec4(1., .4, .4, 1.));
        UI::PushStyleColor(UI::Col::ButtonActive, vec4(1., .6, .6, 1.));   
    }

    void Blue() {
        UI::PushStyleColor(UI::Col::Button, vec4(.2, .2, 1., 1.));
        UI::PushStyleColor(UI::Col::ButtonHovered, vec4(.4, .4, 1., 1.));
        UI::PushStyleColor(UI::Col::ButtonActive, vec4(.6, .6, 1., 1.));
    }

    void DarkGreen() {
        UI::PushStyleColor(UI::Col::Button, vec4(.1, .5, .1, 1.));
        UI::PushStyleColor(UI::Col::ButtonHovered, vec4(.2, .5, .2, 1.));
        UI::PushStyleColor(UI::Col::ButtonActive, vec4(.3, .5, .3, 1.));
    }

    void DarkRed() {
        UI::PushStyleColor(UI::Col::Button, vec4(.5, .1, .1, 1.));
        UI::PushStyleColor(UI::Col::ButtonHovered, vec4(.5, .2, .2, 1.));
        UI::PushStyleColor(UI::Col::ButtonActive, vec4(.5, .3, .3, 1.));   
    }

    void Gray() {
        UI::PushStyleColor(UI::Col::Button, vec4(.2, .2, .2, 1.));
        UI::PushStyleColor(UI::Col::ButtonHovered, vec4(.3, .3, .3, 1.));
        UI::PushStyleColor(UI::Col::ButtonActive, vec4(.4, .4, .4, 1.));   
    }

    void Custom(vec3 color){
        UI::PushStyleColor(UI::Col::Button, vec4(color.x, color.y, color.z, 1.));
        UI::PushStyleColor(UI::Col::ButtonHovered, vec4(color.x, color.y, color.z, 1.));
        UI::PushStyleColor(UI::Col::ButtonActive, vec4(color.x, color.y, color.z, 1.));   
    }

    void Reset() {
        UI::PopStyleColor(3);
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
        vec3 newColor = color;
        for(int i = 0; i < 3; i++){
            float col;
            if (i == 0) col = color.x;
            else if (i == 1) col = color.y;
            else col = color.z;

            col *= amount;
            if (col > 1) col = 1;
            else if (col < 0) col = 0;
            if (i == 0) newColor.x = col;
            else if (i == 1) newColor.y = col;
            else newColor.z = col;
        }
        return newColor;
    }
}