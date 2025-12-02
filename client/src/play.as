
namespace Playground {
    // Data for map claim coroutine (see CheckMedals())
    MapClaimStatus mapClaimData;

    class MapClaimStatus {
        int retries;
        int tileIndex;
        RunResult mapResult;
        CampaignMap campaign;

    }

    // Once again, this is mostly from RMC
    // Only returns a defined value during the finish sequence of a run
    RunResult @GetRunResult() {

        auto app = cast<CTrackMania>(GetApp());
        auto map = GetCurrentMap();

        auto playground = cast<CGamePlayground>(app.CurrentPlayground);
        if (map is null || playground is null)
            return null;

        int authorTime = map.TMObjective_AuthorTime;
        int goldTime = map.TMObjective_GoldTime;
        int silverTime = map.TMObjective_SilverTime;
        int bronzeTime = map.TMObjective_BronzeTime;
        int time = -1;

        auto playgroundScript = cast<CGamePlaygroundScript>(app.PlaygroundScript);
        if (playgroundScript is null || playground.GameTerminals.Length == 0)
            return null;

        CSmPlayer @player = cast<CSmPlayer>(playground.GameTerminals[0].ControlledPlayer);
        if (playground.GameTerminals[0].UISequence_Current !=
                SGamePlaygroundUIConfig::EUISequence::Finish ||
            player is null)
            return null;

        CSmScriptPlayer @playerScriptAPI = cast<CSmScriptPlayer>(player.ScriptAPI);
        auto ghost =
            cast<CSmArenaRulesMode>(playgroundScript).Ghost_RetrieveFromPlayer(playerScriptAPI);
        if (ghost is null)
            return null;

        if (ghost.Result.Time > 0 && ghost.Result.Time < 4294967295)
            time = ghost.Result.Time;

        array<uint> checkpoints;
        for (uint i = 0; i < ghost.Result.Checkpoints.Length; i++) {
            checkpoints.InsertLast(ghost.Result.Checkpoints[i]);
        }

        playgroundScript.DataFileMgr.Ghost_Release(ghost.Id);

        if (time != -1) {
            return RunResult(time,
                             CalculateMedal(time, authorTime, goldTime, silverTime, bronzeTime),
                             checkpoints);
        }
        return null;
    }

    // Update CurrentTileIndex according to the currently open map
    void UpdateCurrentTileIndex() {
        CGameCtnChallenge @challenge = Playground::GetCurrentMap();

        if (challenge is null) {
            Gamemaster::SetCurrentTileIndex(-1);
            return;
        }

        // Check if the tile doesn't need updating
        GameTile @oldTile = Gamemaster::GetCurrentTile();
        if (oldTile !is null && oldTile.map !is null && oldTile.map.uid == challenge.EdChallengeId)
            return;

        // find a map where EdChallengeId == map.uid, set it as the current index
        for (uint i = 0; i < Gamemaster::GetTileCount(); i++) {
            GameTile @candidate = Gamemaster::GetTileFromIndex(i);

            if (candidate !is null && candidate.map !is null &&
                candidate.map.uid == challenge.EdChallengeId) {
                Gamemaster::SetCurrentTileIndex(i);
                return;
            }
        }

        // No candidates found, reset tile index
        Gamemaster::SetCurrentTileIndex(-1);
    }

    // Watching task that claims cells when a run has ended
    void CheckRunFinished() {
        if (mapClaimData.retries > 0)
            return; // Request in progress

        GameTile @currentTile = Gamemaster::GetCurrentTile();
        if (currentTile is null)
            return;
        if (currentTile.map is null)
            return;

        CGameCtnChallenge @map = Playground::GetCurrentMap();
        if (map is null)
            return;

        if (map.EdChallengeId != currentTile.map.uid) {
            // uid mismatch, this is not the right map!
            Gamemaster::FlagCurrentMapAsBroken();
            return;
        }

        RunResult @result = GetRunResult();
        if (result is null)
            return;

        MatchConfiguration config = Gamemaster::GetConfiguration();

        MapClaim @myRun = currentTile.GetLocalPlayerRun();
        if (myRun !is null && myRun.result.time <= result.time)
            return;

        int minimumTime = Playground::GetCurrentTimeToBeat(true).time;
        if (minimumTime != -1 && result.time > minimumTime)
            return;

        // Map should be claimed
        mapClaimData.retries = 3;
        mapClaimData.tileIndex = Gamemaster::GetCurrentTileIndex();
        mapClaimData.mapResult = result;

        logtrace("[Playground::CheckRunFinished] Claiming map '" + map.MapName + "' with time of " +
              result.time);
        startnew(ClaimMedalCoroutine);
    }

    RunResult @GetCurrentTimeToBeat(bool ignorePlayerClaims = false) {
        if (!Gamemaster::IsBingoActive())
            return null;

        GameTile @currentTile = Gamemaster::GetCurrentTile();
        if (currentTile is null)
            return null;
        if (currentTile.map is null)
            return null;

        // Map is claimed, return the top run
        if (!ignorePlayerClaims && currentTile.HasRunSubmissions())
            return currentTile.LeadingRun().result;

        // Map is not claimed, get the target medal time
        return RunResult(objectiveOf(Match.config.targetMedal, currentTile.map), Match.config.targetMedal);
    }

    Medal CalculateMedal(int time, int author, int gold, int silver, int bronze) {
        Medal medal = Medal::None;
        if (time <= bronze)
            medal = Medal::Bronze;
        if (time <= silver)
            medal = Medal::Silver;
        if (time <= gold)
            medal = Medal::Gold;
        if (time <= author)
            medal = Medal::Author;
        return medal;
    }

    void DebugClaim(uint tileIndex) {
        mapClaimData.retries = 3;
        mapClaimData.tileIndex = tileIndex;
        mapClaimData.mapResult = RunResult(3600000, Medal::None);
        startnew(ClaimMedalCoroutine);
    }

    void ClaimMedalCoroutine() {
        bool ok = false;
        while (mapClaimData.retries > 0) {
            bool Success = Network::ClaimCell(
                mapClaimData.tileIndex, mapClaimData.campaign, mapClaimData.mapResult);
            mapClaimData.retries -= 1;
            if (Success) {
                logtrace("[Playground::ClaimMedalCoroutine] Map successfully claimed.");
                ok = true;
                break;
            } else
                logtrace("[Playground::ClaimMedalCoroutine] Map claim failed, retrying... (" +
                      mapClaimData.retries + " attempts left)");
        }
        if (!ok) {
            logwarn("[Playground::ClaimMedalCoroutine] Warning! Failed to claim a map after several "
                 "retries.");
        }
        mapClaimData.retries = 0;
    }
}
