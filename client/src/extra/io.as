
namespace Extra::IO {

    /* Get the absolute path to a file within the map downloads user folder. */
    string FromMapDownloadsFolder(const string&in filename) {
        string folderBase = IO::FromUserGameFolder("") + __internal::MAPS_DOWNLOAD_PATH;
        IO::CreateFolder(folderBase);
        return folderBase + "/" + filename;
    }

    /* Convert a file size to a formatted string. */
    string FormatFileSize(uint64 bytes) {
        float format = float(bytes);
        uint suffix = 0;
        while (format >= 1024. && suffix < __internal::FILESIZE_SUFFIXES.Length) {
            format /= 1024.;
            suffix += 1;
        }

        return Text::Format("%.2f", format) + " " + __internal::FILESIZE_SUFFIXES[suffix];
    }

    namespace __internal {
        const string MAPS_DOWNLOAD_PATH = "Maps/Downloaded/Bingo";
        const array<string> FILESIZE_SUFFIXES = { "bytes", "KiB", "MiB" };
    }
}