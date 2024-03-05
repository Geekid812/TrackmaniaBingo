
namespace Playground {
    // Data for map claim coroutine (see CheckMedals())
    MapClaimStatus mapClaimData;

    class MapClaimStatus {
        int retries;
        string mapUid;
        RunResult mapResult;
        CampaignMap campaign;
    }

    class CoroutineData {
        int id;

        CoroutineData(int id) { this.id = id; }
    }

#if TMNEXT
    void LoadMap(int tmxId) {
        startnew(LoadMapCoroutine, CoroutineData(tmxId));
    }
#elif TURBO
    void LoadMapCampaign(int trackNum) {
        startnew(InternalLoadMapCampaign, CoroutineData(trackNum));
    }
#endif

    void BackToMainMenu(CGameManiaPlanet@ app) {
        bool menuDisplayed = app.ManiaPlanetScriptAPI.ActiveContext_InGameMenuDisplayed;
        if (menuDisplayed) {
            // Close the in-game menu via ::Quit to avoid TM hanging / crashing. Also takes us back to the main menu.
            app.Network.PlaygroundInterfaceScriptHandler.CloseInGameMenu(CGameScriptHandlerPlaygroundInterface::EInGameMenuResult::Quit);
        } else {
            // Go to main menu and wait until map loading is ready
            app.BackToMainMenu();
        }
    }

#if TMNEXT
    // This code is mostly taken from Greep's RMC
    void LoadMapCoroutine(ref@ Data) {
        if (!Permissions::PlayLocalMap()) {
            warn("Playground: aborting LoadMap, player does not have required permissions!");
            return;
        }

        int tmxId = cast<CoroutineData>(Data).id;
        auto app = cast<CTrackMania>(GetApp());
        BackToMainMenu(app);

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
#elif TURBO
    void InternalLoadMapCampaign(ref@ Data) {
        auto app = cast<CGameManiaPlanet>(GetApp());
        BackToMainMenu(app);

        // Wait until script API is available
        auto scriptAPI = app.ManiaTitleFlowScriptAPI;
        while (!scriptAPI.IsReady) yield();

        int mapId = cast<CoroutineData>(Data).id - 1;
        int difficultyId = mapId / 40;
        int enviId = (mapId % 40) / 10;
        array<string> enviNames = {"Canyon", "Valley", "Lagoon", "Stadium"};
        array<string> difficulties = {"White", "Green", "Blue", "Red", "Black"};
        
        string filename = "Campaigns\\" + Text::Format("%02i", difficultyId + 1)
        + "_" + difficulties[difficultyId] +"\\" + Text::Format("%02i", enviId + 1)
        + "_" + enviNames[enviId] + "\\" + Text::Format("%03i", mapId + 1) + ".Map.Gbx";
        string modeName = "TMC_CampaignSolo.Script.txt";

        scriptAPI.PlayMap(filename, modeName, "");
    }

    CGameCtnChallenge@ GetCurrentMap() {
        auto app = cast<CGameCtnApp>(GetApp());
        return app.Challenge;
    }
#endif


    // Once again, this is mostly from RMC
    // Only returns a defined value during the finish sequence of a run
    RunResult GetRunResult() {
        auto app = cast<CTrackMania>(GetApp());
        auto map = GetCurrentMap();

        auto playground = cast<CGamePlayground>(app.CurrentPlayground);
        if (map is null || playground is null) return RunResult();

        int authorTime = map.TMObjective_AuthorTime;
        int goldTime = map.TMObjective_GoldTime;
        int silverTime = map.TMObjective_SilverTime;
        int bronzeTime = map.TMObjective_BronzeTime;
        int time = -1;

        auto playgroundScript = cast<CGamePlaygroundScript>(app.PlaygroundScript);
        if (playgroundScript is null || playground.GameTerminals.Length == 0) return RunResult();

#if TMNEXT
        CSmPlayer@ player = cast<CSmPlayer>(playground.GameTerminals[0].ControlledPlayer);
        if (playground.GameTerminals[0].UISequence_Current != SGamePlaygroundUIConfig::EUISequence::Finish || player is null) return RunResult();

        CSmScriptPlayer@ playerScriptAPI = cast<CSmScriptPlayer>(player.ScriptAPI);
        auto ghost = cast<CSmArenaRulesMode>(playgroundScript).Ghost_RetrieveFromPlayer(playerScriptAPI);
        if (ghost is null) return RunResult();

        if (ghost.Result.Time > 0 && ghost.Result.Time < 4294967295) time = ghost.Result.Time;
        playgroundScript.DataFileMgr.Ghost_Release(ghost.Id);
#elif TURBO
        CTrackManiaPlayer@ player = cast<CTrackManiaPlayer>(playground.GameTerminals[0].ControlledPlayer);
        if (player.RaceState != CTrackManiaPlayer::ERaceState::Finished || player is null) return RunResult();

        time = player.CurRace.Time;
#endif

        if (time != -1) {
            return RunResult(time, CalculateMedal(time, authorTime, goldTime, silverTime, bronzeTime));
        }
        return RunResult();
    }

    // Watching task that claims cells when a run has ended
    void CheckRunFinished() {
        if (@Match == null) return;
        if (mapClaimData.retries > 0) return; // Request in progress
        RunResult result = GetRunResult();
        if (result.time == -1) return;

        auto mapNod = GetCurrentMap();
        auto mapCell = Match.GetMapWithUid(mapNod.EdChallengeId);
        if (@mapCell.map is null) return;

        auto myRun = mapCell.GetLocalPlayerRun();
        if (@myRun !is null && myRun.result.time <= result.time) return;

        int medalTime = GetMedalTime(mapNod, Match.config.targetMedal);
        if (medalTime != -1 && result.time > medalTime) return;

        // Map should be claimed
        mapClaimData.retries = 3;
        mapClaimData.mapUid = mapCell.map.uid;
        mapClaimData.mapResult = result;

        auto campaign = CampaignMap();
        if (mapCell.map.type == MapType::Campaign) {
            campaign.campaignId = 0;
            campaign.map = mapCell.map.id;
        }
        mapClaimData.campaign = campaign;

        trace("Claiming map '" + mapCell.map.uid + "' with time of " + result.time);
        startnew(ClaimMedalCoroutine);
    }

    RunResult@ GetCurrentTimeToBeat(bool basetime = false) {
        if (@Match == null) return null;
        CGameCtnChallenge@ map = GetCurrentMap();
        if (@map == null) return null;
        MapCell cell = Match.GetMapWithUid(map.EdChallengeId);
        if (@cell.map is null) return null;
        if (!basetime && cell.IsClaimed()) return cell.LeadingRun().result;

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

    void DebugClaim(MapCell mapCell) {
        mapClaimData.retries = 3;
        mapClaimData.mapUid = mapCell.map.uid;
        mapClaimData.mapResult = RunResult(3600000, Medal::None);
        startnew(ClaimMedalCoroutine);
    }

    void ClaimMedalCoroutine() {
        bool ok = false;
        while (mapClaimData.retries > 0) {
            bool Success = Network::ClaimCell(mapClaimData.mapUid, mapClaimData.campaign, mapClaimData.mapResult);
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

    void SetMapLeaderboardVisible(bool visible) {
        auto network = GetApp().Network;
        if (@network is null) return;
        auto appPlayground = network.ClientManiaAppPlayground;
        if (@appPlayground is null) return;
        auto uiLayers = appPlayground.UILayers;
        for (uint i = 0; i < uiLayers.Length; i++) {
            auto module = uiLayers[i];
            if (@module !is null && module.ManialinkPage.SubStr(0, 100).Contains("UIModule_Race_Record")) {
                module.IsVisible = visible;
            }
        }
    }
}
