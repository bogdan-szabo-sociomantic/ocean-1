module ocean.text.util.ClassName;

extern (C) private void* memrchr(void* s, int c, size_t n);

char[] classname ( Object o )
{
    char[] mod;
    
    return classname(o, mod);
}

char[] classname ( Object o, out char[] mod )
{
    char[] str = o.classinfo.name;
    
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
