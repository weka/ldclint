// RUN: env LDCLINT_FLAGS="-Wno-all -Wunused-imports" ldc2 -w -c %s -o- --plugin=libldclint.so

// straight import used through a function call
import core.stdc.stdio;
void useStdio() { puts("hi"); }

// straight import used through a global var (SymOffExp / VarExp)
import core.stdc.errno;
int readErrno() { return errno; }

// straight import used through a type (struct/class)
import core.stdc.time;
void useTime(time_t* t) { time(t); }

// straight import used as a function pointer (DelegateExp / SymOffExp)
import core.stdc.stdlib;
auto exitPtr() { return &exit; }

// selective import — used. The use site resolves to the symbol's owning
// module so the parent module gets credited.
import core.stdc.string : strlen;
size_t useString(const(char)* s) { return strlen(s); }

// aliased import — `io.puts(...)` resolves to the function in stdio.
import io = core.stdc.stdio;
void useAliased() { io.puts("via alias"); }

// public/package imports are intentional re-exports — never flagged.
public import core.stdc.signal;
package import core.stdc.locale;

// import only used through a never-instantiated template should not warn:
// the unresolved identifier is matched against the imported module's exports.
import core.stdc.math;

void onlyInUninstantiatedTemplate(T)(T x)
{
    sqrt(x);
}
