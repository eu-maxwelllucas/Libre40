// Libre40 - ReXGlue Recompiled Project
//
// Keep this intentionally small until The 40th Day has a measured compatibility
// need. Prefer official ReXGlue behavior over project-specific hooks.

#pragma once

#include "crash_dump.h"
#include "generated/default/l40_init.h"

#include <filesystem>
#include <fstream>
#include <memory>

#include <rex/cvar.h>
#include <rex/filesystem/devices/host_path_device.h>
#include <rex/filesystem/vfs.h>
#include <rex/logging.h>
#include <rex/rex_app.h>
#include <rex/runtime.h>

REXCVAR_DECLARE(bool, l40_mount_shaderdumpxe);
REXCVAR_DECLARE(bool, l40_seed_shader_compare_backend);

class L40App : public rex::ReXApp {
 public:
  using rex::ReXApp::ReXApp;

  static std::unique_ptr<rex::ui::WindowedApp> Create(
      rex::ui::WindowedAppContext& ctx) {
    return std::unique_ptr<L40App>(new L40App(ctx, "l40", PPCImageConfig));
  }

  void OnPostInitLogging() override {
    L40InstallCrashDumpHandler();
    REXLOG_INFO("Libre40: official ReXGlue app initialized");
  }

  void OnPostSetup() override {
    if (!REXCVAR_GET(l40_mount_shaderdumpxe) || !runtime() || !runtime()->file_system()) {
      return;
    }

    auto shader_dump_root = cache_root() / "shaderdumpxe";
    if (REXCVAR_GET(l40_seed_shader_compare_backend)) {
      std::error_code ec;
      std::filesystem::create_directories(shader_dump_root, ec);
      if (ec) {
        REXLOG_WARN("Libre40: failed to create ShaderDumpxe cache {}: {}",
                    shader_dump_root.string(), ec.message());
      } else {
        auto compare_backends = shader_dump_root / "CompareBackEnds";
        if (!std::filesystem::exists(compare_backends, ec)) {
          std::ofstream(compare_backends, std::ios::binary).close();
        }
        if (ec) {
          REXLOG_WARN("Libre40: failed to probe ShaderDumpxe stub {}: {}",
                      compare_backends.string(), ec.message());
        }
      }
    }

    auto device = std::make_unique<rex::filesystem::HostPathDevice>(
        "\\Device\\ShaderDumpxe", shader_dump_root, false);
    if (!device->Initialize()) {
      REXLOG_WARN("Libre40: failed to initialize ShaderDumpxe device at {}",
                  shader_dump_root.string());
      return;
    }

    auto* file_system = runtime()->file_system();
    file_system->RegisterDevice(std::move(device));
    file_system->RegisterSymbolicLink("ShaderDumpxe:", "\\Device\\ShaderDumpxe");
    REXLOG_INFO("Libre40: mounted {} as ShaderDumpxe:", shader_dump_root.string());
  }
};
