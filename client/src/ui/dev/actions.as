namespace UIDevActions {
    bool Visible;

    void Render() {
        if (!Visible) return;
        UI::Begin(DEVELOPER_WINDOW_NAME, Visible);

        UI::BeginTabBar("bingodev_tabs");

        if (UI::BeginTabItem(Icons::Bug + " Actions")) {
            ClientTokenControl();

            UIColor::Cyan();

            CacheCleaner();
            UI::SameLine();
            DummyGameLauncher();

            UIColor::Reset();
            UIColor::Dark();

            TextureResourceCache();

            UIColor::Reset();

            UI::EndTabItem();
        }

        if (UI::BeginTabItem(Icons::Font + " Fonts")) {
            UIDevFonts::RenderFontMatrix();
            
            UI::EndTabItem();
        }

        if (UI::BeginTabItem(Icons::MapO + " Map Cache")) {
            UIDevMapCache::RenderCache();

            UI::EndTabItem();
        }

        if (UI::BeginTabItem(Icons::AddressCard + " Game Stats")) {
            if (!Gamemaster::IsBingoActive()) {
                UI::NewLine();
                UITools::CenterText("No Bingo game is currently running.");
            } else {
                UIDevGameStat::Render();
            }

            UI::EndTabItem();
        }

        UI::EndTabBar();

        UI::End();
    }

    void ClientTokenControl() {
        PersistantStorage::ClientToken = UI::InputText("Client Token", PersistantStorage::ClientToken);
        UI::SameLine();
        if (UI::Button("Clear")) {
            PersistantStorage::ClientToken = "";
        };
    }

    void CacheCleaner() {
        if (UI::Button(Icons::Stethoscope + " Clear Local Storage")) {
            PersistantStorage::ResetStorage();
        }
    }

    void DummyGameLauncher() {
        if (UI::Button(Icons::PlayCircle + " Launch Dummy Game")) {
            trace("[UIDevActions::DummyGameLauncher] Starting a dummy Bingo game.");
            Gamemaster::ResetAll();

            Gamemaster::SetBingoActive(true);
            Gamemaster::InitializeTiles();

            // Prefill tiles with maps from local cache
            for (uint i = 0; i < Gamemaster::GetTileCount(); i++) {
                if (i >= MapCache.Length) break;

                Gamemaster::TileSetMap(i, MapCache[i]);
            }

            Gamemaster::SetStartTime(Time::Now);
            Gamemaster::SetPhase(GamePhase::Running);

            UIDevActions::Visible = false;
        }
    }

    void TextureResourceCache() {
        if (UI::Button(Icons::Bug + " Texture Cache")) {
            LocalStorage::DebugEnumerateTextureStorage();
        }
    }
}
