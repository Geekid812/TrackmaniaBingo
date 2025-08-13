#if TMNEXT
namespace Playground {

    /* Load a map in the game playground. */
    void PlayMap(const string& in filePath, const string& in modeName = "") {
        if (!Permissions::PlayLocalMap()) {
            warn("[Playground::PlayMap] Aborting, player does not have required permissions!");
            return;
        }

        trace("[Playground::PlayMap] Loading map '" + filePath + "'...");
        __internal::CurrentLoadingPath = filePath;
        __internal::PlayMapCoroutineData data(filePath, modeName);
        startnew(__internal::PlayMapCoroutine, data);
    }

    /* Get the currently loaded map's Challenge nod. */
    CGameCtnChallenge @GetCurrentMap() {
        auto app = cast<CTrackMania>(GetApp());
        return app.RootMap;
    }

    /* Set the visibility of the records leaderbaord manialink module. */
    bool SetMapLeaderboardVisible(bool visible) {
        auto network = GetApp().Network;
        if (network is null)
            return false;
        auto appPlayground = network.ClientManiaAppPlayground;
        if (appPlayground is null)
            return false;
        auto uiLayers = appPlayground.UILayers;
        for (uint i = 0; i < uiLayers.Length; i++) {
            auto module = uiLayers[i];
            if (module !is null &&
                module.ManialinkPage.SubStr(0, 100).Contains("UIModule_Race_Record")) {
                module.IsVisible = visible;
                return true;
            }
        }

        return false;
    }

    /* Send a manialink event to update the mode UI of a new record. */
    void UpdateCurrentPlaygroundRecord(const string&in accountId, int time, array<uint> checkpoints) {
        trace("[Playground::UpdateCurrentPlaygroundRecord] (" + accountId + ") - " + Time::Format(time));
        auto app = cast<CTrackMania>(GetApp());
        CGameManiaAppPlayground@ playground = app.Network.ClientManiaAppPlayground;
        if (playground is null) return;

        MwFastBuffer<wstring> arguments;
        arguments.Add(accountId);
        arguments.Add(tostring(time));
        for (uint i = 0; i < checkpoints.Length; i++) {
            arguments.Add(tostring(checkpoints[i]));
        }

        playground.SendCustomEvent("Bingo_UpdateRecord", arguments);
    }

    /* Maniascript map load events initialization. */
    bool ManialinkInit(GameTile@ tile) {
        if (@tile is null) return false;

        auto app = cast<CTrackMania>(GetApp());
        CGameManiaAppPlayground@ playground = app.Network.ClientManiaAppPlayground;
        if (playground is null) return false;

        auto config = playground.UI;
        if (config is null || config.UISequence != CGamePlaygroundUIConfig::EUISequence::Intro) return false;

        auto rank = tile.attemptRanking;
        trace("[Playground::ManialinkInit] Initializing " + rank.Length + " record" + (rank.Length == 1 ? "" : "s") + "...");
        for (uint i = 0; i < rank.Length; i++) {
            Player@ player = rank[i].player;
            UpdateCurrentPlaygroundRecord((@player !is null ? player.profile.accountId : ""), rank[i].result.time, rank[i].result.checkpoints);
        }

        return true;
    }

    namespace __internal {
        class PlayMapCoroutineData {
            string filePath;
            string modeName;

            PlayMapCoroutineData() {}

            PlayMapCoroutineData(const string& in filePath, const string& in modeName) {
                this.filePath = filePath;
                this.modeName = modeName;
            }

        }

        class InitManialinkCoroutineData {
            array<MapClaim> ranking;

            InitManialinkCoroutineData() {}

            InitManialinkCoroutineData(array<MapClaim> ranking) {
                this.ranking = ranking;
            }

        }

        void
        PlayMapCoroutine(ref @arg) {

            PlayMapCoroutineData data = cast<PlayMapCoroutineData>(arg);

            Playground::BackToMainMenu();
            auto app = cast<CTrackMania>(GetApp());

            // Wait for the active module to be the main menu, and be ready. If getting back to the
            // main menu fails, this will block until the user quits the map.
            while (app.Switcher.ModuleStack.Length == 0 ||
                   cast<CTrackManiaMenus>(app.Switcher.ModuleStack[0]) is null) {
                if (__internal::CurrentLoadingPath != data.filePath) {
                    warn("[Playground::PlayMapCoroutine] A new map has been requested, aborting "
                         "previous load.");
                    return;
                }
                yield();
            }
            while (!app.ManiaTitleControlScriptAPI.IsReady) {
                if (__internal::CurrentLoadingPath != data.filePath) {
                    warn("[Playground::PlayMapCoroutine] A new map has been requested, aborting "
                         "previous load.");
                    return;
                }
                yield();
            }

            app.ManiaTitleControlScriptAPI.PlayMap(data.filePath, data.modeName, "");
            trace("[Playground::PlayMap] Load coroutine completed.");
        }

        void
        InitManialinkCoroutine(ref @arg) {
            InitManialinkCoroutineData data = cast<InitManialinkCoroutineData>(arg);

            auto app = cast<CTrackMania>(GetApp());
            CGameManiaAppPlayground@ playground = app.Network.ClientManiaAppPlayground;
            auto config = cast<CGamePlaygroundUIConfig>(playground.UI);
            
            while (playground !is null && config.UISequence != CGamePlaygroundUIConfig::EUISequence::Intro) yield();
            if (playground is null) return;
            while (playground !is null && config.UISequence != CGamePlaygroundUIConfig::EUISequence::Playing) yield();
            if (playground is null) return;
            yield(10);
            if (playground is null) return;
        }
    }
}
#endif
