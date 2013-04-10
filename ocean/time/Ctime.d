module ocean.time.Ctime;

private import tango.stdc.time: time_t;
private import tango.stdc.posix.time: ctime_r;
private import tango.stdc.string: strlen;

const ctime_min_length = 26;

char[] ctime ( ref char[] dst, time_t t )
{
    if (dst.length < ctime_min_length)
    {
        dst.length = ctime_min_length;
    }

    return ctime_(dst, t);
}

char[] ctimeStatArr ( char[26] dst, time_t t )
{
    return ctime_(dst, t);
}

private char[] ctime_ ( char[] dst, time_t t )
{
    char* str = ctime_r(&t, dst.ptr);

    return str? str[0 .. strlen(dst.ptr) - 1] : null;
}
