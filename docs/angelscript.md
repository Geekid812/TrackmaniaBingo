# Openplanet Plugin for Bingo - Technical Overview
Every file in the plugin defines its own Angelscript namespace for scoping purposes. This name generally matches the file name (eg `gamemaster.as` has the `Gamemaster` namespace) except for UI namespaces which are declared with the `UI` prefix. Classes are defined outside of namespaces unless they are an internal implemetation detail.

### UI Views
Views in the `ui` directory are broken down on a per-file basis. Particularly of note:
- `main.as` handles the main plugin window, each tab of the main menu has its own namespace: `home.as`, `roommenu.as` (Play), `roomsettings.as` (Create).
- Lobby UI is in `room.as` with the player teams table in `players.as` as it is shared with the in-game teams menu (`teams.as`).
- For the game interface, `maplist.as` handles the in-game map grid and `infobar.as` handles the informational subwindows below the grid.
- `items.as` provides helper widgets that are shared in meny places to display player tags, error messages, or input buttons.

The `Layout` utilities from `util/layout.as` are substaintially used in UI code.
