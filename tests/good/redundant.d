// RUN: ldc2 -w -c %s -o- --plugin=libldclint.so

// No false positives on non-redundant expressions

int foo(int p1, int p2)
{
    bool ret;
    int acc;

    // different variables - not redundant
    ret |= p1 == p2;
    ret |= p1 != p2;
    ret |= p1 > p2;
    ret |= p1 < p2;
    ret |= p1 >= p2;
    ret |= p1 <= p2;
    ret |= p1 is p2;
    ret |= p1 !is p2;
    ret |= p1 && p2;
    ret |= p1 || p2;
    acc += p1 & p2;
    acc += p1 | p2;
    acc += p1 ^ p2;
    acc += p1 - p2;

    // assignment to different variable
    p1 = p2;

    return ret + p1 + acc;
}

// empty blocks with comments should not warn
void commentedIf(bool c)
{
    if (c) { // intentionally empty
    }
}

void commentedElse(bool c)
{
    if (c) { return; } else { /* TODO */ }
}

void commentedIfWithElse(bool c)
{
    if (c) {
        // TODO: handle this case
    } else { return; }
}
