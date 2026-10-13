// bakugandotc - ReXGlue Recompiled Project
//
// Customize your app by overriding virtual hooks from rex::ReXApp.

#pragma once

#include <rex/rex_app.h>
#include <rex/ui/window.h>
#ifdef _WIN32
#include <windows.h>
#endif

#include "discord/discord_rpc.h"

class BakugandotcApp : public rex::ReXApp {
 public:
  using rex::ReXApp::ReXApp;

  static std::unique_ptr<rex::ui::WindowedApp> Create(
      rex::ui::WindowedAppContext& ctx) {
    return std::unique_ptr<BakugandotcApp>(new BakugandotcApp(ctx, "bakugandotc",
        PPCImageConfig));
  }

  // Override virtual hooks for customization:
  // void OnPostInitLogging() override {}
  // void OnPreSetup(rex::RuntimeConfig& config) override {}
  // void OnLoadXexImage(std::string& xex_image) override {}
  // void OnPostLoadXexImage() override {}
  void OnPostSetup() override {
    window()->SetTitle("Bakugan: Defenders of the Core");
#ifdef _WIN32
    auto module = GetModuleHandleW(nullptr);
    auto resource = FindResourceW(module, MAKEINTRESOURCEW(2), MAKEINTRESOURCEW(10));
    if (resource) {
      auto data = LoadResource(module, resource);
      if (data) window()->SetIcon(LockResource(data), SizeofResource(module, resource));
    }
#endif
    discord::Start();
  }
  // void OnCreateDialogs(rex::ui::ImGuiDrawer* drawer) override {}
  // std::unique_ptr<rex::ui::ImGuiDialog> CreateAchievementsOverlay() override;
  // std::unique_ptr<rex::ui::AchievementNotificationDialog>
  // CreateAchievementNotificationDialog() override;
  void OnShutdown() override { discord::Stop(); }
  // void OnConfigurePaths(rex::PathConfig& paths) override {}
};
