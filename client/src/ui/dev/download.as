
namespace UIDownloads {
    const float BOTTOM_ANCHOR_OFFSET = 0.02;

    void Render() {
        if (DownloadManager::GetItemsInQueue() == 0)
            return;

        UI::Begin("##bingodownloads",
                  UI::WindowFlags::NoTitleBar | UI::WindowFlags::AlwaysAutoResize |
                      UI::WindowFlags::NoMove);

        uint mapDownloads = DownloadManager::GetItemTypeInQueue(AssetType::Map);
        uint imageDownloads = DownloadManager::GetItemTypeInQueue(AssetType::Image);

        if (mapDownloads > 0)
            UI::Text(tostring(mapDownloads) + " maps downloading");
        if (imageDownloads > 0)
            UI::Text(tostring(imageDownloads) + " images downloading");

        vec2 size = UI::GetWindowSize();
        vec2 full = vec2(Draw::GetWidth(), Draw::GetHeight());
        UI::SetWindowPos(full - size -
                         vec2(full.y * BOTTOM_ANCHOR_OFFSET, full.y * BOTTOM_ANCHOR_OFFSET));
        UI::End();
    }
}
