
namespace GameUpdates {

    // Game tick function. Runs the core logic for one update cycle.
    void Tick() {
        Playground::CheckRunFinished();
        Playground::UpdateCurrentTileIndex();
        if (Match.config.competitvePatch) Playground::SetMapLeaderboardVisible(false);
    
        Poll::CleanupExpiredPolls();
    }

}
