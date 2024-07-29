
namespace Gamemaster {
    namespace __internal {
        bool GameActive = false;
    }
    
    /**
     * Return `true` if the Bingo game is currently active.
     */
    bool IsBingoActive() {
        return __internal::GameActive;
    }

    /**
     * Activate/deactivate the Bingo game.
     */
    void SetBingoActive(bool active) {
        __internal::GameActive = active;
        if (active && Match is null) @Match = LiveMatch();
    }

    /**
     * Return the match UID.
     */
    string GetMatchId() {
        return Match.uid;
    }

    /**
     * Set the match UID.
     * If the match UID is set, the plugin will try to reconnect to that match.
     */
    void SetMatchId(const string&in uid) {
        Match.uid = uid;

        PersistantStorage::LastConnectedMatchId = uid;
        Meta::SaveSettings();
    }

    /**
     * Unset the match UID.
     * This also has the effect of disabling reconnection.
     */
    void ClearMatchId() {
        if (Match !is null) Match.uid = "";
        PersistantStorage::ResetConnectedMatch();
    }

    /**
     * Get the game configuration.
     */
    MatchConfiguration@ GetConfiguration() {
        return Match.config;
    }

    /**
     * Apply changes to the match configuration.
     */
    void SetConfiguration(MatchConfiguration config) {
        Match.config = config;
    }

    /**
     * Return the GameTime when the match will transitition to the play phase. 
     */
    int64 GetStartTime() {
        return Match.startTime;
    }

    /**
     * Set the game to transition to the play phase at the specified GameTime.
     */
    void SetStartTime(int64 gameTime) {
        Match.startTime = gameTime;
    }

    /**
     * Get the tile located at the given coordinates on the Bingo grid.
     */
    GameTile@ GetTileOnGrid(uint x, uint y) {        
        uint gridSize = Match.config.gridSize;
        uint index = y * gridSize + x;

        if (index >= Match.tiles.Length) return null;
        return Match.tiles[index];
    }

    /**
     * Get the active play phase.
     */
    GamePhase GetPhase() {
        return Match.phase;
    }

    /**
     * Set the active play phase.
     */
    void SetPhase(GamePhase phase) {
        GamePhase previous = Match.phase;
        Match.phase = phase;

        if (previous == GamePhase::Starting) {
            UIGameRoom::Visible = false;
            UIMapList::Visible = true;
        }

        if (phase == GamePhase::Overtime) {
            Match.overtimeStartTime = Time::Now;
        }
    }

    /**
     * Stop the current game and close the connection.
     */
    void Shutdown() {
        // TODO: this is rudimentary, it doesn't keep connection alive
        trace("[Gamemaster::Shutdown] Closing the game.");
        ResetAll();
        Network::CloseConnection();
    }

    /**
     * Reset the game state to the initial state.
     */
    void ResetAll() {
        SetBingoActive(false);
        ClearMatchId();
        @Match = null;
    }
}
