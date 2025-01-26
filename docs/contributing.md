## Contributing to Trackmania Bingo
This page seeks to describe the architecture and working process of the Bingo Openplanet plugin project. As of writing this document, the Bingo project has so far been led and developped mostly by myself (`@geekid`), and thus this documentation's goal is to enpower more developers in the Trackmania community to contribute their ideas and code to what I consider one of the longest standing community gamemodes for the game. This documentation may also be of interest to learn about the technical details of this plugin, even if you did not consider contributing to the project.

### Overall Architecture
Since this has a much bigger scope than an ordinary Openplanet plugin, there are many moving parts of a whole solution working together to provide the functionality of the Bingo plugin:

The main driver is of course the Angelscript plugin (located in `/client`) which provides no less functionality than a protocol stack driven by JSON messages on top of TCP sockets to communicate with the game server, a UI framework to work with layouts and animations rendering the many pages of ImGui/Nvg user interfaces, and a serialization library for exchanging network messages to Angelscript classes.

On the other end of the network, the Bingo game server (located in `/server`), written in Rust, connects all of the Trackmania clients together and drives the main logic of the game. It is backed by an embedded SQLite database for storing persistent records of player profiles and past matches, and it integrates with external services such as [trackmania.exchange] and [trackmania.io] to provide lookup functionality for game tracks and players respectively.

Another relatively new and still in development project part is a Flask web frontend (located in `/web`) designed for server administration and, perhaps eventually, competition management. This simple stateless web server, while not currently suited for production use, has the express goal of providing an interface to managing the Bingo game server. It is an entirely optional part of the stack, so much as it has not existed until very recently.

Finally, in order to facilicate communication within the stack as there exists multiple shared common data structures that are exchanged over the network, there is a custom tool for generating bindings to game structures from a shared definition. The `typegen` script (located in `/common`), using a special XML definition of several game data strctures, generates parsing code and creates special datatypes by converting them into Angelscript, Rust and Python classes.

### Recommended Setup
As is common practice within plugin developers, using a VSCode-compatible editor is recommended to work in this project.

As a tooling reference, you may find the following extensions useful:
- [Openplanet Angelscript] to work with Angelscript plugin code
- [rust-analyzer] for working on the Rust server code
- [Python] language support if editing the Flask frontend or one of the support scripts
- The [XML] extension provides rich language support for editing `types.xml` with the provided schema

Certain toolchains are required for some parts of the project:
- A recent (edge) build of Openplanet in Developer mode to run the unpackaged plugin
- A [Rust] toolchain is required to build and run the game server
- [uv] is used for Python project management in the web frontend

### Workflow
Before getting started, consider that the `main` branch of the repository tracks the latest development version of Bingo and may not be compatible with the current released version of the plugin, as the network interface or internal APIs may have been changed! If you are basing your work off of `main`, you will need to run the game server locally (see [this documentation page]). As an alternative solution, the `stable` branch should reflect the latest released version of the plugin, but your changes will need to be rebased when submitted upstream and merged into `main`.
