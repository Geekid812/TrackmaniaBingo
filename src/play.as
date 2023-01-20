
namespace Playground {
    // Data for map claim coroutine (see CheckMedals())
    MapClaimStatus MapClaimData;

    class MapClaimStatus {
        int Retries;
        string MapUid;
        RunResult MapResult;
    }

    void LoadMap(int TmxID) {
        startnew(LoadMapCoroutine, CoroutineData(TmxID));
    }

    class CoroutineData {
        int Id;

        CoroutineData(int id) { this.Id = id; }
    }

    // This code is mostly taken from Greep's RMC
    void LoadMapCoroutine(ref@ Data) {
        int TmxID = cast<CoroutineData>(Data).Id;
        auto App = cast<CTrackMania>(GetApp());
        bool MenuDisplayed = App.ManiaPlanetScriptAPI.ActiveContext_InGameMenuDisplayed;
        if (MenuDisplayed) {
            // Close the in-game menu via ::Quit to avoid TM hanging / crashing. Also takes us back to the main menu.
            App.Network.PlaygroundInterfaceScriptHandler.CloseInGameMenu(CGameScriptHandlerPlaygroundInterface::EInGameMenuResult::Quit);
        } else {
            // Go to main menu and wait until map loading is ready
            App.BackToMainMenu();
        }

        // Wait for the active module to be the main menu, and be ready. If getting back to the main menu fails, this will block until the user quits the map.
        while (App.Switcher.ModuleStack.Length == 0 || cast<CTrackManiaMenus>(App.Switcher.ModuleStack[0]) is null) {
            yield();
        }
        while (!App.ManiaTitleControlScriptAPI.IsReady) {
            yield();
        }

        App.ManiaTitleControlScriptAPI.PlayMap("https://trackmania.exchange/maps/download/" + TmxID, "", "");
    }

    CGameCtnChallenge@ GetCurrentMap() {
        auto App = cast<CTrackMania>(GetApp());
        return App.RootMap;
    }

    // Once again, this is mostly from RMC
    // Only returns a defined value during the finish sequence of a run
    RunResult GetRunResult() {
        // This is GetCurrentMap(), but because App is used in the function,
        // we redefine it here
        auto App = cast<CTrackMania>(GetApp());
        auto Map = App.RootMap;

        auto Playground = cast<CGamePlayground>(App.CurrentPlayground);
        if (Map is null || Playground is null) return RunResult();

        int AuthorTime = Map.TMObjective_AuthorTime;
        int GoldTime = Map.TMObjective_GoldTime;
        int SilverTime = Map.TMObjective_SilverTime;
        int BronzeTime = Map.TMObjective_BronzeTime;
        int Time = -1;

        auto PlaygroundScript = cast<CSmArenaRulesMode>(App.PlaygroundScript);
        if (PlaygroundScript is null || Playground.GameTerminals.Length == 0) return RunResult();

        CSmPlayer@ Player = cast<CSmPlayer>(Playground.GameTerminals[0].ControlledPlayer);
        if (Playground.GameTerminals[0].UISequence_Current != SGamePlaygroundUIConfig::EUISequence::Finish || Player is null) return RunResult();

        CSmScriptPlayer@ PlayerScriptAPI = cast<CSmScriptPlayer>(Player.ScriptAPI);
        auto Ghost = PlaygroundScript.Ghost_RetrieveFromPlayer(PlayerScriptAPI);
        if (Ghost is null) return RunResult();

        if (Ghost.Result.Time > 0 && Ghost.Result.Time < 4294967295) Time = Ghost.Result.Time;
        PlaygroundScript.DataFileMgr.Ghost_Release(Ghost.Id);

        if (Time != -1) {
            return RunResult(Time, CalculateMedal(Time, AuthorTime, GoldTime, SilverTime, BronzeTime));
        }
        return RunResult();
    }

    // Watching task that claims cells when certain medals are achieved
    void CheckMedals() {
        if (MapClaimData.Retries > 0) return; // Request in progress
        RunResult Result = GetRunResult();
        if (Result.Time == -1) return;

        auto MapNod = GetCurrentMap();
        auto GameMap = Room.GetMapWithUid(MapNod.EdChallengeId); // Hi, Ed!
        if (GameMap.TmxID == -1) return;
        int CurrentTime = GameMap.ClaimedRun.Time;
        if (CurrentTime != -1 && CurrentTime <= Result.Time) return;

        Medal TargetMedal = Room.TargetMedal;
        if (Result.Medal <= TargetMedal) {
            // Map should be claimed
            MapClaimData.Retries = 3;
            MapClaimData.MapUid = GameMap.Uid;
            MapClaimData.MapResult = Result;
            trace("Claiming map '" + GameMap.Uid + "' with time of " + Result.Time + " (previous time: " + CurrentTime + ")");
            startnew(ClaimMedalCoroutine);
        }
    }

    RunResult@ GetCurrentTimeToBeat() {
        CGameCtnChallenge@ Map = GetCurrentMap();
        if (@Map == null) return null;
        Map GameMap = Room.GetMapWithUid(Map.EdChallengeId);
        if (GameMap.TmxID == -1) return null;
        if (GameMap.ClaimedRun.Time != -1) return GameMap.ClaimedRun;

        return RunResult(GetMedalTime(Map, Room.TargetMedal), Room.TargetMedal);
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
        bool Ok = false;
        while (MapClaimData.Retries > 0) {
            bool Success = Network::ClaimCell(MapClaimData.MapUid, MapClaimData.MapResult);
            MapClaimData.Retries -= 1;
            if (Success) {
                trace("Map successfully claimed.");
                Ok = true;
                break;
            }
            else trace("Map claim failed, retrying... (" + MapClaimData.Retries + " attempts left)");
        }
        if (!Ok) {
            warn("Warning! Failed to claim a map after several retries.");
        }
        MapClaimData.Retries = 0;
    }
}
