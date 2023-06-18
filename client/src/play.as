
namespace Playground {
    // Data for map claim coroutine (see CheckMedals())
    MapClaimStatus mapClaimData;

    class MapClaimStatus {
        int retries;
        string mapUid;
        RunResult mapResult;
    }

    void LoadMap(int tmxId) {
        startnew(LoadMapCoroutine, CoroutineData(tmxId));
    }

    class CoroutineData {
        int id;

        CoroutineData(int id) { this.id = id; }
    }

    // This code is mostly taken from Greep's RMC
    void LoadMapCoroutine(ref@ Data) {
        int tmxId = cast<CoroutineData>(Data).id;
        auto app = cast<CTrackMania>(GetApp());
        bool menuDisplayed = app.ManiaPlanetScriptAPI.ActiveContext_InGameMenuDisplayed;
        if (menuDisplayed) {
            // Close the in-game menu via ::Quit to avoid TM hanging / crashing. Also takes us back to the main menu.
            app.Network.PlaygroundInterfaceScriptHandler.CloseInGameMenu(CGameScriptHandlerPlaygroundInterface::EInGameMenuResult::Quit);
        } else {
            // Go to main menu and wait until map loading is ready
            app.BackToMainMenu();
        }

        // Wait for the active module to be the main menu, and be ready. If getting back to the main menu fails, this will block until the user quits the map.
        while (app.Switcher.ModuleStack.Length == 0 || cast<CTrackManiaMenus>(app.Switcher.ModuleStack[0]) is null) {
            yield();
        }
        while (!app.ManiaTitleControlScriptAPI.IsReady) {
            yield();
        }

        app.ManiaTitleControlScriptAPI.PlayMap("https://trackmania.exchange/maps/download/" + tmxId, "", "");
    }

    CGameCtnChallenge@ GetCurrentMap() {
        auto app = cast<CTrackMania>(GetApp());
        return app.RootMap;
    }

    // Once again, this is mostly from RMC
    // Only returns a defined value during the finish sequence of a run
    RunResult GetRunResult() {
        // This is GetCurrentMap(), but because App is used in the function,
        // we redefine it here
        auto app = cast<CTrackMania>(GetApp());
        auto map = app.RootMap;

        auto playground = cast<CGamePlayground>(app.CurrentPlayground);
        if (map is null || playground is null) return RunResult();

        int authorTime = map.TMObjective_AuthorTime;
        int goldTime = map.TMObjective_GoldTime;
        int silverTime = map.TMObjective_SilverTime;
        int bronzeTime = map.TMObjective_BronzeTime;
        int time = -1;

        auto playgroundScript = cast<CSmArenaRulesMode>(app.PlaygroundScript);
        if (playgroundScript is null || playground.GameTerminals.Length == 0) return RunResult();

        CSmPlayer@ player = cast<CSmPlayer>(playground.GameTerminals[0].ControlledPlayer);
        if (playground.GameTerminals[0].UISequence_Current != SGamePlaygroundUIConfig::EUISequence::Finish || player is null) return RunResult();

        CSmScriptPlayer@ playerScriptAPI = cast<CSmScriptPlayer>(player.ScriptAPI);
        auto ghost = playgroundScript.Ghost_RetrieveFromPlayer(playerScriptAPI);
        if (ghost is null) return RunResult();

        if (ghost.Result.Time > 0 && ghost.Result.Time < 4294967295) time = ghost.Result.Time;
        playgroundScript.DataFileMgr.Ghost_Release(ghost.Id);

        if (time != -1) {
            return RunResult(time, CalculateMedal(time, authorTime, goldTime, silverTime, bronzeTime));
        }
        return RunResult();
    }

    // Watching task that claims cells when certain medals are achieved
    void CheckMedals() {
        if (@Match == null) return;
        if (mapClaimData.retries > 0) return; // Request in progress
        RunResult result = GetRunResult();
        if (result.time == -1) return;

        auto mapNod = GetCurrentMap();
        auto mapCell = Match.GetMapWithUid(mapNod.EdChallengeId);
        if (mapCell.map.tmxid == -1) return;
        int currentTime = mapCell.LeadingRun().recordedRun.time;
        if (currentTime != -1 && currentTime <= result.time) return;

        Medal targetMedal = Match.config.targetMedal;
        if (result.medal <= targetMedal) {
            // Map should be claimed
            mapClaimData.retries = 3;
            mapClaimData.mapUid = mapCell.map.uid;
            mapClaimData.mapResult = result;
            trace("Claiming map '" + mapCell.map.uid + "' with time of " + result.time + " (previous time: " + currentTime + ")");
            startnew(ClaimMedalCoroutine);
        }
    }

    RunResult@ GetCurrentTimeToBeat() {
        if (@Match == null) return null;
        CGameCtnChallenge@ map = GetCurrentMap();
        if (@map == null) return null;
        MapCell cell = Match.GetMapWithUid(map.EdChallengeId);
        if (cell.map.tmxid == -1) return null;
        if (cell.IsClaimed()) return cell.LeadingRun().recordedRun;

        return RunResult(GetMedalTime(map, Match.config.targetMedal), Match.config.targetMedal);
    }

    Medal CalculateMedal(int time, int author, int gold, int silver, int bronze) {
            Medal medal = Medal::None;
            if (time <= bronze) medal = Medal::Bronze;
            if (time <= silver) medal = Medal::Silver;
            if (time <= gold) medal = Medal::Gold;
            if (time <= author) medal = Medal::Author;
            return medal;
    }

    int GetMedalTime(CGameCtnChallenge@ map, Medal medal) {
        if (medal == Medal::Author) return map.TMObjective_AuthorTime;
        if (medal == Medal::Gold) return map.TMObjective_GoldTime;
        if (medal == Medal::Silver) return map.TMObjective_SilverTime;
        if (medal == Medal::Bronze) return map.TMObjective_BronzeTime;
        return -1;
    }

    void ClaimMedalCoroutine() {
        bool ok = false;
        while (mapClaimData.retries > 0) {
            bool Success = Network::ClaimCell(mapClaimData.mapUid, mapClaimData.mapResult);
            mapClaimData.retries -= 1;
            if (Success) {
                trace("Map successfully claimed.");
                ok = true;
                break;
            }
            else trace("Map claim failed, retrying... (" + mapClaimData.retries + " attempts left)");
        }
        if (!ok) {
            warn("Warning! Failed to claim a map after several retries.");
        }
        mapClaimData.retries = 0;
    }
}
