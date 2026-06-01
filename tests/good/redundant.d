// RUN: env LDCLINT_FLAGS="-Wno-all -Wredundant" ldc2 -w -c %s -o- --plugin=libldclint.so

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

// -- line comment on same line as opening brace --
void lineCommentSameLine_If(bool c)
{
    if (c) { // intentionally empty
    }
}

void lineCommentSameLine_Else(bool c)
{
    if (c) { return; } else { // intentionally empty
    }
}

void lineCommentSameLine_IfWithElse(bool c)
{
    if (c) { // intentionally empty
    } else { return; }
}

// -- block comment /* */ on same line as opening brace --
void blockCommentSameLine_If(bool c)
{
    if (c) { /* intentionally empty */
    }
}

void blockCommentSameLine_Else(bool c)
{
    if (c) { return; } else { /* intentionally empty */
    }
}

void blockCommentSameLine_IfWithElse(bool c)
{
    if (c) { /* intentionally empty */
    } else { return; }
}

// -- block comment /* */ opening on same line, closing later --
void blockCommentOpenSameLine_If(bool c)
{
    if (c) { /* intentionally
              * empty */
    }
}

void blockCommentOpenSameLine_Else(bool c)
{
    if (c) { return; } else { /* intentionally
                               * empty */
    }
}

void blockCommentOpenSameLine_IfWithElse(bool c)
{
    if (c) { /* intentionally
              * empty */
    } else { return; }
}

// -- nesting comment /+ +/ on same line as opening brace --
void nestingCommentSameLine_If(bool c)
{
    if (c) { /+ intentionally empty +/
    }
}

void nestingCommentSameLine_Else(bool c)
{
    if (c) { return; } else { /+ intentionally empty +/
    }
}

void nestingCommentSameLine_IfWithElse(bool c)
{
    if (c) { /+ intentionally empty +/
    } else { return; }
}

// -- comment on next line (existing coverage kept for context) --
void commentedIfWithElse(bool c)
{
    if (c) {
        // TODO: handle this case
    } else { return; }
}

void nestingCommentedElse(bool c)
{
    if (c) { return; } else { /+ TODO +/ }
}

void nestingCommentedIfWithElse(bool c)
{
    if (c) {
        /+ TODO: handle this case +/
    } else { return; }
}

// mixed comment styles and whitespace in the same block
void mixedCommentsIf(bool c)
{
    if (c) {
        // line comment
        /* block comment */
    }
}

void mixedCommentsElse(bool c)
{
    if (c) { return; } else {
        // line comment
        /* block comment */
    }
}

void mixedCommentsIfWithElse(bool c)
{
    if (c) {
          //   spaced line comment
          /* spaced block comment */
    } else { return; }
}

// version blocks with a false condition are stripped from the AST,
// making the body appear empty — these must not warn
void versionIf(bool c)
{
    if (c) {
        version(Unimplemented) { }
    }
}

void versionElse(bool c)
{
    if (c) { return; } else {
        version(Unimplemented) { }
    }
}

void versionIfWithElse(bool c)
{
    if (c) {
        version(Unimplemented) { }
    } else { return; }
}

// mixed: version + // + /* in different orderings
void versionThenLineCommentIf(bool c)
{
    if (c) {
        version(Unimplemented) { }
        // placeholder
    }
}

void lineCommentThenVersionIf(bool c)
{
    if (c) {
        // placeholder
        version(Unimplemented) { }
    }
}

void blockCommentThenVersionIf(bool c)
{
    if (c) {
        /* placeholder */
        version(Unimplemented) { }
    }
}

void versionThenBlockCommentIf(bool c)
{
    if (c) {
        version(Unimplemented) { }
        /* placeholder */
    }
}

void allThreeOrderOneIf(bool c)
{
    if (c) {
        // line comment
        /* block comment */
        version(Unimplemented) { }
    }
}

void allThreeOrderTwoIf(bool c)
{
    if (c) {
        version(Unimplemented) { }
        // line comment
        /* block comment */
    }
}

void allThreeOrderThreeIf(bool c)
{
    if (c) {
        /* block comment */
        version(Unimplemented) { }
        // line comment
    }
}

void allThreeElse(bool c)
{
    if (c) { return; } else {
        // line comment
        version(Unimplemented) { }
        /* block comment */
    }
}

void allThreeIfWithElse(bool c)
{
    if (c) {
        /* block comment */
        // line comment
        version(Unimplemented) { }
    } else { return; }
}
