// Minimal Discord Rich Presence client (raw IPC, no SDK/DLL dependency).
//
// Implements just enough of Discord's local IPC protocol to set a static
// activity: game name, a short status line, a large icon, and an
// automatically-updating "elapsed" timer. Runs on its own background
// thread, so it never touches the guest game loop or anything under
// generated/ - completely independent of codegen.
//
// Setup required before this actually shows anything in Discord:
//   1. Go to https://discord.com/developers/applications and create a new
//      application (any name - it's just used internally as an ID).
//   2. Copy its "Application ID" from the General Information page into
//      kClientId in discord_rpc.cpp.
//   3. In that same app, go to Rich Presence -> Art Assets and upload an
//      image (the game's icon/logo). Give it an asset key (e.g. "icon")
//      and put that same key in kLargeImageKey in discord_rpc.cpp.
//   4. The user just needs the Discord desktop app running locally -
//      nothing else to configure on their end.
//
// Until step 2 is done (kClientId is still the placeholder), Start() will
// simply fail to connect and retry quietly in the background - it will
// never crash or block startup.

#pragma once

namespace discord {

// Starts the background IPC thread. Safe to call once, early in startup
// (BakugandotcApp::OnPostSetup). Non-blocking: connects lazily and keeps
// retrying in the background if Discord isn't running yet.
void Start();

// Stops the background thread and clears the activity. Call from
// BakugandotcApp::OnShutdown().
void Stop();

}  // namespace discord
