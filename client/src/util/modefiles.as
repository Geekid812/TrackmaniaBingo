
namespace Modefiles {
    void EnsureAllModefilesCreated() {
        CreateBingoModescript();
    }

    void CreateBingoModescript() {
        string targetPath = IO::FromUserGameFolder("Scripts/Modes/TrackMania/Bingo_PlayMap_Local.Script.txt");
        if (IO::FileExists(targetPath)) {
            // TODO: versioning check. for now, it is considered up to date
            return;
        }
        print("[Modefiles::CreateBingoModescript] Creating Bingo_PlayMap_Local.Script.txt");
		string modeSource = IO::FileSource("data/Bingo_PlayMap_Local.Script.txt").ReadToEnd();

		string fileName = targetPath.Split("/")[targetPath.Split("/").Length - 1];
		string folderToCreate = targetPath.SubStr(0, targetPath.Length - fileName.Length);
		IO::CreateFolder(folderToCreate);

		IO::File destFile(targetPath, IO::FileMode::Write);
		destFile.Write(modeSource);
		destFile.Close();
    }
}
