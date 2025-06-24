
namespace GameUpdates {

    // Run checks and display a warning when using an unsupported config.
    void CheckUnstableConfigurations() {
        if (UI::GetScale() != 1.) {
            ChecksWarn("Openplanet UI scale has been modified (" + tostring(UI::GetScale()) + "x).\nThis is not supported, the layout of the interface might break or be unusable. Please reset your Openplanet interface settings if you want to use Bingo.");
        }
    }

    void ChecksWarn(const string&in warning) {
        warn("[GameUpdates::ChecksWarn] Unsupported configuration: " + warning);
        UI::ShowNotification(Icons::ExclamationCircle + " Bingo: Unsupported Configuration Detected", warning + "\nYou can disable this warning in the plugin settings.", vec4(.8, .5, 0., 1.), 20000);
    }

    // Game tick function. Runs the core logic for one update cycle.
    void TickGameplay() {
        Playground::CheckRunFinished();
        if (Match.config.competitvePatch)
            Playground::SetMapLeaderboardVisible(false);
    }

    // Active tick function. Runs when a game is active, even if it is paused or not running.
    void TickUpdates() {
        Playground::UpdateCurrentTileIndex();
        Poll::CleanupExpiredPolls();
    }

}
