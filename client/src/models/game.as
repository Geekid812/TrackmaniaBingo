/* Game parameters set by the host. */
class GameRules {
    GamePlatform game = GamePlatform::Next;
    uint gridWidth = 5;
    uint gridHeight = 5;
    Medal targetMedal = Medal::Gold;
    int64 mainDuration;
    int64 noBingoDuration;
    string b64GridPattern;

    bool hasOvertime;
    bool hasFreeForAll;
    bool hasRerolls;
    bool hasCompetitvePatch;

    bool canJoinDuringGame;

    GameRules() {}
}

namespace GameRules {
    Json::Value@ Serialize(GameRules cls) {
        auto value = Json::Object();
        value["platform"] = int(cls.game);
        value["grid_width"] = cls.gridWidth;
        value["grid_height"] = cls.gridHeight;
        value["target_medal"] = int(cls.targetMedal);
        value["main_duration"] = cls.mainDuration;
        value["no_bingo_duration"] = cls.noBingoDuration;
        value["b64_grid_pattern"] = cls.b64GridPattern;

        value["has_overtime"] = cls.hasOvertime;
        value["has_free_for_all"] = cls.hasFreeForAll;
        value["has_rerolls"] = cls.hasRerolls;
        value["has_competitve_patch"] = cls.hasCompetitvePatch;
        value["can_join_during_game"] = cls.canJoinDuringGame;

        return value;
    }

    GameRules Deserialize(Json::Value@ value) {
        auto cls = GameRules();
        
        cls.game = GamePlatform(int(value["game"]));
        cls.gridWidth = value["grid_width"];
        cls.gridHeight = value["grid_height"];
        cls.targetMedal = Medal(int(value["target_medal"]));
        cls.mainDuration = value["main_duration"];
        cls.noBingoDuration = value["no_bingo_duration"];
        cls.b64GridPattern = value["b64_grid_pattern"];

        cls.hasOvertime = value["has_overtime"];
        cls.hasFreeForAll = value["has_free_for_all"];
        cls.hasRerolls = value["has_rerolls"];
        cls.hasCompetitvePatch = value["has_competitve_patch"];

        cls.canJoinDuringGame = value["can_join_during_game"];

        return cls;
    }
}

/* Supported game platforms in Bingo. */
enum GamePlatform {
    Next,
    MP4,
    Turbo,
}

/* A Trackmania medal ranking. */
enum Medal {
    Author,
    Gold,
    Silver,
    Bronze,
    None,
}