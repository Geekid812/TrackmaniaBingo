namespace UIDevActions {
    bool Visible;

    void Render() {
        if (!Visible)
            return;
        UI::Begin(DEVELOPER_WINDOW_NAME, Visible);

        UI::BeginTabBar("bingodev_tabs");

        if (UI::BeginTabItem(Icons::Bug + " Actions")) {
            ClientTokenControl();
            LastConnectedMatchControl();

            UIColor::Cyan();

            CacheCleaner();
            UI::SameLine();
            DummyGameLauncher();

            FakePlayersControl();

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

        if (UI::BeginTabItem(Icons::WindowMaximize + " UI Windows")) {
            UIDevWindows::Render();
            UI::EndTabItem();
        }

        if (UI::BeginTabItem(Icons::AlignJustify + " Interface")) {
            UIDevInterface::Render();
            UI::EndTabItem();
        }

        UI::EndTabBar();

        UI::End();
    }

    void ClientTokenControl() {
        PersistantStorage::ClientToken =
            UI::InputText("Client Token", PersistantStorage::ClientToken);
        UI::SameLine();
        if (UI::Button("Clear##bingoclearclienttoken")) {
            PersistantStorage::ClientToken = "";
        };
    }

    void LastConnectedMatchControl() {
        PersistantStorage::LastConnectedMatchId =
            UI::InputText("Last Connected Match ID", PersistantStorage::LastConnectedMatchId);
        UI::SameLine();
        if (UI::Button("Clear##bingoclearlastmatch")) {
            PersistantStorage::LastConnectedMatchId = "";
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
                if (i >= MapCache.Length)
                    break;

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

    void FakePlayersControl() {
        if (UI::Button(Icons::UserCircle + " Add Fake Player")) {
            AddFakePlayer();
        }

        UI::SameLine();
        if (UI::Button(Icons::TrashO + " Clear Fake Players")) {
            ClearAllFakePlayers();
        }
    }

    void AddFakePlayer() {
        if (!Gamemaster::IsBingoActive()) {
            warn("[UIDevActions::AddFakePlayer] Cannot add a player, Bingo is not active!");
            return;
        }

        Team randomTeam = Match.teams[Math::Rand(0, Match.teams.Length)];
        PlayerProfile fakeProfile();
        fakeProfile.uid = -1;
        fakeProfile.name = "Player " + Math::Rand(100, 1000);
        fakeProfile.countryCode = "WOR";
        Match.players.InsertLast(Player(fakeProfile, randomTeam));
    }

    void ClearAllFakePlayers() {
        if (!Gamemaster::IsBingoActive()) {
            warn("[UIDevActions::ClearAllFakePlayers] Cannot add a player, Bingo is not active!");
            return;
        }

        uint i = 0;
        while (i < Match.players.Length) {
            if (Match.players[i].profile.uid == -1) {
                Match.players.RemoveAt(i);
            } else {
                i++;
            }
        }
    }
}
