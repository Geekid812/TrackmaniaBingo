
namespace UIColor {
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

    void Reset() {
        UI::PopStyleColor(3);
    }
}