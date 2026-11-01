# The bot station

The development build of SANDBOX for a second PC that runs the bots, so the host's machine measures the host alone (D-145, [BOTS_AND_DEV_BUILDS.md › Bots on a second PC](https://github.com/dmelo10/SANDBOX-GAME/blob/main/Docs/Game/BOTS_AND_DEV_BUILDS.md)).

- **The release `dev-latest`** holds the latest quick development build (`SANDBOX-dev.zip`) and its version (`version.txt`). `tools/publish-dev-build.ps1` replaces both from the host's machine.
- **`station.bat`** runs `station.ps1`: 15 headless bots joining the host at `192.168.0.3`. It takes each new build by itself, and starts again a bot that quits.

## Once, on the second PC
1. Install the GitHub CLI (https://cli.github.com) and sign in: `gh auth login`.
2. Download this repository (Code › Download ZIP) and unpack it anywhere.
3. Double-click `station.bat`, and leave it open. Close it, or press Ctrl+C, to stop the bots.

The bots join every match the host starts. Builds go to `builds\`, the bots' logs to `logs\`.
