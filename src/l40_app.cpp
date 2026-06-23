#include "l40_app.h"

REXCVAR_DEFINE_BOOL(l40_mount_shaderdumpxe, true, "L40",
                    "Mount a writable ShaderDumpxe: VFS device for startup shader debug probes");
REXCVAR_DEFINE_BOOL(l40_seed_shader_compare_backend, true, "L40",
                    "Seed a zero-byte ShaderDumpxe:\\CompareBackEnds file for startup probes");
