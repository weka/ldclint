# -*- Python -*-

import ctypes
import os
import platform

import lit.formats

config.name = "LDC Linter Plugin"

config.suffixes = [ ".d" ]
config.excludes = []
config.test_format = lit.formats.ShTest(execute_external=False)

# D's `real` matches the C `long double` ABI. Some targets (notably macOS
# arm64) make `real == double`; tests that depend on `real` being wider
# guard themselves with this feature.
if ctypes.sizeof(ctypes.c_longdouble) > ctypes.sizeof(ctypes.c_double):
    config.available_features.add("real-extended")

config.substitutions.append(("%PATH%", config.environment["PATH"]))

# lit's default config strips dynamic-loader env vars; relay them from the
# parent process so the Makefile (or caller) can point them at libldclint.
for _var in ("LD_LIBRARY_PATH", "DYLD_LIBRARY_PATH"):
    if _var in os.environ:
        config.environment[_var] = os.environ[_var]
