
string GetLocalUsername() {
#if TMNEXT
    return GetLocalLogin();
#elif TURBO
    auto playground = GetApp().Network.PlaygroundInterfaceScriptHandler;
    if (playground is null) return "";
    return playground.LocalPlayerInfo.Name;
#endif
}
