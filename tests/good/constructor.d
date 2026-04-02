// RUN: env LDCLINT_FLAGS="-Wno-all -Wstyle-duplicate-ctor" ldc2 -w -c %s -o- --plugin=libldclint.so

// Only has one constructor with a required arg - no ambiguity
class Dog
{
    this() {}
    this(string name) {} // name is required
}

// Only has default-arg constructor, no zero-arg - no ambiguity
class Bird
{
    this(string name = "tweety") {}
}

// Only zero-arg constructor - fine
class Fish
{
    this() {}
}

// Has default arg but also a required arg - not confusing
class Lizard
{
    this() {}
    this(string name = "kittie", int x) {} // x is required
}
