
namespace IO::Extra {

    /* Get the absolute path to a file within the map downloads user folder. */
    string FromMapDownloadsFolder(const string&in filename) {
        string folderBase = IO::FromUserGameFolder("") + __internal::MAPS_DOWNLOAD_PATH;
        IO::CreateFolder(folderBase);
        return folderBase + "/" + filename;
    }

    namespace __internal {
        const string MAPS_DOWNLOAD_PATH = "Maps/Downloaded/Bingo";
    }
}