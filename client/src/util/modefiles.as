
namespace Modefiles {
    void EnsureAllModefilesCreated() { CreateBingoModescriptFiles(); }

    void CreateBingoModescriptFiles() {
        CreateFile("data/Bingo_PlayMap_Local.Script.txt",
                   "Scripts/Modes/TrackMania/Bingo_PlayMap_Local.Script.txt");
        CreateFile("data/Bingo_Events.Script.txt", "Scripts/Libs/Bingo/Bingo_Events.Script.txt");
    }

    void CreateFile(const string& in souce, const string& in destination) {
        string targetPath = IO::FromUserGameFolder(destination);
        if (IO::FileExists(targetPath)) {
            // TODO: versioning check. for now, it is considered up to date
            return;
        }
        print("[Modefiles::CreateBingoModescript] Creating " + destination);
        string modeSource = IO::FileSource(souce).ReadToEnd();

        string fileName = targetPath.Split("/")[targetPath.Split("/").Length - 1];
        string folderToCreate = targetPath.SubStr(0, targetPath.Length - fileName.Length);
        IO::CreateFolder(folderToCreate);

        IO::File destFile(targetPath, IO::FileMode::Write);
        destFile.Write(modeSource);
        destFile.Close();
    }

    bool AreModefilesInstalled() {
        return IO::FileExists(
            IO::FromUserGameFolder("Scripts/Modes/TrackMania/Bingo_PlayMap_Local.Script.txt"));
    }
}
