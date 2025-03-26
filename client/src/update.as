
namespace GameUpdates {

    // Game tick function. Runs the core logic for one update cycle.
    void TickGameplay() {
        Playground::CheckRunFinished();
        if (Match.config.competitvePatch) Playground::SetMapLeaderboardVisible(false);    
    }

    // Active tick function. Runs when a game is active, even if it is paused or not running.
    void TickUpdates() {
        Playground::UpdateCurrentTileIndex();
        Poll::CleanupExpiredPolls();
    }

}
