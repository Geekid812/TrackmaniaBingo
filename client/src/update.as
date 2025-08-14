
namespace GameUpdates {
    int64 LastSummonTimestamp;
    bool MapIsCompetitivePatched;
    bool ManialinkInitialized;

    // Run checks and display a warning when using an unsupported config.
    void CheckUnstableConfigurations() {
        if (UI::GetScale() != 1.) {
            ChecksWarn("Openplanet UI scale has been modified (" + tostring(UI::GetScale()) +
                       "x).\nThis is not supported, the layout of the interface might break or be "
                       "unusable. Please reset your Openplanet interface settings if you want to "
                       "use Bingo.");
        }

        if (!Modefiles::AreModefilesInstalled()) {
            ChecksWarn("The plugin could not install the required files into your user folder (" +
                       IO::FromUserGameFolder("Scripts") +
                       "). Please make sure this location is accessible and disable any write "
                       "protection or interfering progams.");
        }
    }

    void ChecksWarn(const string& in warning) {
        warn("[GameUpdates::ChecksWarn] Unsupported configuration: " + warning);
        UI::ShowNotification(Icons::ExclamationCircle +
                                 " Bingo: Unsupported Configuration Detected",
                             warning + "\nYou can disable this warning in the plugin settings.",
                             vec4(.8, .5, 0., 1.),
                             20000);
    }

    // Game tick function. Runs the core logic for one update cycle.
    void TickGameplay() {
        Playground::CheckRunFinished();

        if (!Match.config.competitvePatch && !ManialinkInitialized)
            ManialinkInitialized = Playground::ManialinkInit(Gamemaster::GetCurrentTile());

        if (Gamemaster::IsInJail())
            SummonToJail();
    }

    // Active tick function. Runs when a game is active, even if it is paused or not running.
    void TickUpdates() {
        Playground::UpdateCurrentTileIndex();
        Poll::CleanupExpiredToasts();
        if (Match.config.competitvePatch && !MapIsCompetitivePatched) {
            // Records will only be visible once the game ends
            MapIsCompetitivePatched =
                Playground::SetMapLeaderboardVisible(Match.endState.HasEnded());
        }
    }

    void SummonToJail() {
        auto map = Playground::GetCurrentMap();
        if (@map !is null && map.EdChallengeId != Jail.map.uid &&
            Time::Now - LastSummonTimestamp > 5000) {
            print("[GameUpdates::SummonToJail] Player is not in their jail, summoning them now.");
            UI::ShowNotification("",
                                 Icons::ExclamationCircle +
                                     " You are in jail. You must go to the map where you were "
                                     "emprisoned! To break out of jail, you must beat the current "
                                     "record on this map within the time limit.",
                                 vec4(.6, .2, .2, .9),
                                 20000);
            LastSummonTimestamp = Time::Now;
            Playground::PlayMap(Jail.map);
        }
    }

}
