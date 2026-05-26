// RUN: env LDCLINT_FLAGS="-Wno-all -Wimport-cycle" ldc2 -w -c %s -o- --plugin=libldclint.so
module import_cycle;

import object;
import core.stdc.stdio;
