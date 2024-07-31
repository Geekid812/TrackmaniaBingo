
namespace Playground {
    namespace __internal {
        bool MapLoading = false;
    }
    
    /* Get the objective time for a specific medal on a map. */
    int GetMedalTime(CGameCtnChallenge@ map, Medal medal) {
        if (medal == Medal::Author) return map.TMObjective_AuthorTime;
        if (medal == Medal::Gold) return map.TMObjective_GoldTime;
        if (medal == Medal::Silver) return map.TMObjective_SilverTime;
        if (medal == Medal::Bronze) return map.TMObjective_BronzeTime;
        return -1;
    }

    /* Return to the main menu. */
    void BackToMainMenu() {
        auto app = cast<CGameManiaPlanet>(GetApp());
        bool menuDisplayed = app.ManiaPlanetScriptAPI.ActiveContext_InGameMenuDisplayed;
        if (menuDisplayed) {
            // Close the in-game menu via ::Quit to avoid TM hanging / crashing. Also takes us back to the main menu.
            app.Network.PlaygroundInterfaceScriptHandler.CloseInGameMenu(CGameScriptHandlerPlaygroundInterface::EInGameMenuResult::Quit);
        } else {
            // Go to main menu and wait until map loading is ready
            app.BackToMainMenu();
        }
    }

    /* Launch the playground from the specified map. */
    void PlayMap(GameMap map) {
        switch (map.type) {
            case MapType::TMX:
                PlayMap("https://trackmania.exchange/maps/download/" + map.id);
                break;
            default:
                warn("[Playground::PlayMap] Unhandled MapType: " + tostring(map.type));
        }
    }
}
