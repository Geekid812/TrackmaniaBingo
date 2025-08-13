
namespace SurveyService {
    const string SURVEY_ENDPOINT = "http://38.242.214.20:8082/survey";

    // Check if we are currently running under Wine
    bool IsWineLinux() {
#if WINDOWS_WINE
        return true;
#else
        return false;
#endif
    }

    // Get a plaintext summary of the information that is about to be surveyed.
    string GatherTextSummary() {
        return "Openplanet version " + Meta::OpenplanetVersion()
        + "\nBuild: " + Meta::OpenplanetBuildInfo()
        + "\nSubmitted on " + Time::FormatStringUTC("%a %Y-%m-%d %H:%M") + " UTC"
        + "\n" + Meta::AllPlugins().Length + " plugins loaded"
        + "\nResolution: " + Draw::GetWidth() + "x" + Draw::GetHeight()
        + "\nUI Scale: " + UI::GetScale()
        + "\nDeveloper mode: " + (Meta::IsDeveloperMode() ? "ON" : "OFF")
        + "\nRunning under Wine: " + (IsWineLinux() ? "True" : "False");
    }

    // Gather a JSON object of the survey contents.
    Json::Value@ GatherSurveyData() {
        Json::Value@ surveyData = Json::Object();
        surveyData["op"] = Meta::OpenplanetBuildInfo();
        surveyData["timestamp"] = Time::Stamp;
        surveyData["timestring"] = Time::FormatStringUTC("%a %Y-%m-%d %H:%M") + " UTC";
        surveyData["pluginCount"] = Meta::AllPlugins().Length;
        surveyData["width"] = Draw::GetWidth();
        surveyData["height"] = Draw::GetHeight();
        surveyData["scale"] = UI::GetScale();
        surveyData["developer"] = Meta::IsDeveloperMode();
        surveyData["wine"] = IsWineLinux();
        
        return surveyData;
    }

    // Coroutine: Submit a survey entry to the server, after the user has accepted to participate.
    void SubmitSurveyToServer() {
        Json::Value@ surveyData = GatherSurveyData();
        Net::HttpRequest@ req = Net::HttpPost(SURVEY_ENDPOINT, Json::Write(surveyData), "application/json");

        while (!req.Finished()) yield();

        Extra::Net::RequestRaiseError("SurveyService::SubmitSurveyToServer", req);
    }
}
