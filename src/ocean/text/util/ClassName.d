module ocean.text.util.ClassName;

import tango.transition;

extern (C) private void* memrchr(Const!(void)* s, int c, size_t n);

istring classname ( Object o )
{
    istring mod;

    return classname(o, mod);
}

istring classname ( Object o, out istring mod )
{
    istring str = o.classinfo.name;

    char* lastdot = cast (char*) memrchr(str.ptr, '.', str.length);

    if (lastdot)
    {
        size_t n = lastdot - str.ptr;

        mod = str[0 .. n];

        return str[n + 1 .. $];
    }
    else
    {
        return str;
    }
}
