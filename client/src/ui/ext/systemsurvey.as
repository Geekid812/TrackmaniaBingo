
namespace UISystemSurvey {
    bool Visible;
    string SurveySummary;

    // Current UI screen for the survey window
    SurveyViewState State = SurveyViewState::Consent;

    enum SurveyViewState {
        Consent,
        Summary,
        Accepted,
        Cancelled
    }

    string GetWindowTitle() {
        return Icons::Search + " Bingo System Survey";
    }

    void Render() {
        if (!Visible) return;

        UI::PushStyleVar(UI::StyleVar::WindowMinSize, vec2(400, 400));
        UI::Begin(GetWindowTitle(), Visible);

        UI::BeginChild("System Survey View", vec2(0, -36));

        switch (State) {
            case SurveyViewState::Consent:
                RenderConsentView();
                break;
            case SurveyViewState::Summary:
                RenderSummaryView();
                break;
            case SurveyViewState::Accepted:
                RenderAcceptedView();
                break;
            case SurveyViewState::Cancelled:
                RenderCancelledView();
                break;
        }

        UI::EndChild();

        UI::Separator();
        SurveyChoiceButtons();

        UI::End();
        UI::PopStyleVar();
    }

    void RenderConsentView() {
        UI::TextWrapped("Hello! We are running a short automated survey to understand what system configuration Bingo players are using, similar to the Steam hardware survey.\n\nThe plugin will gather some basic information which you can choose to send to the developer of Trackmania Bingo for consideration in the development of future updates to the plugin. Do you want to participate?");
    }

    void RenderSummaryView() {
        if (SurveySummary == "") {
            SurveySummary = SurveyService::GatherTextSummary();
        }

        UI::TextWrapped("Here is a summary of the information gathered about your setup. You can review it and continue if you accept to share it with the developer:");

        UI::BeginChild("Survey Summary Text");
    
        Font::Set(Font::Style::Mono, Font::Size::Medium);
        UI::TextWrapped(SurveySummary);
        Font::Unset();

        UI::EndChild();
    }

    void RenderAcceptedView() {
        UI::TextWrapped("Thanks for participating!\n\nIf you are interested in hearing about development news and what is being done, you can always join the Discord server.\n\nHave fun!");
    }

    void RenderCancelledView() {
        UI::TextWrapped("The survey was cancelled and you won't be asked to participate again. If you find any issues while using the plugin, please make sure to report them in the Discord server or on GitHub so they can be fixed as soon as possible!");
    }

    void SurveyChoiceButtons() {
        string denyButtonText = Icons::Times + " Cancel";
        string acceptButtonText = Icons::Check + " Accept";

        bool canShowDenyButton = State == SurveyViewState::Consent || State == SurveyViewState::Summary;
        if (canShowDenyButton) {
            if (UI::ButtonColored(denyButtonText, 0.05)) {
                State = SurveyViewState::Cancelled;
                warn("[UISystemSurvey::SurveyChoiceButtons] System surveying explicitly cancelled by the user.");
            }
        } else {
            UI::Dummy(UI::GetStyleVarVec2(UI::StyleVar::FramePadding));
        }

        UI::SameLine();
        vec2 availableSpace = UI::GetContentRegionAvail();
        float yesBtnWidth = Draw::MeasureString(acceptButtonText).x + UI::GetStyleVarVec2(UI::StyleVar::FramePadding).x;
        float gapWidth = Math::Max(availableSpace.x - yesBtnWidth - UI::GetStyleVarVec2(UI::StyleVar::ItemSpacing).x, 0.0);

        UI::SetCursorPos(UI::GetCursorPos() + vec2(gapWidth, 0));

        if (UI::ButtonColored(acceptButtonText, 0.4)) {
            switch (State) {
                case SurveyViewState::Consent:
                    State = SurveyViewState::Summary;
                    break;
                case SurveyViewState::Summary:
                    // Survey was accepted
                    startnew(SurveyService::SubmitSurveyToServer);
                    State = SurveyViewState::Accepted;
                    break;
                default:
                    // End state, close this window
                    Settings::ShowSystemSurvey = false;
                    Visible = !Visible;
                    break;
            }
        }
    }
}
