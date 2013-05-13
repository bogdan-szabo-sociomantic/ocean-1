/*******************************************************************************

    copyright:      Copyright (c) 2004 Kris Bell. All rights reserved

    license:        BSD style: $(LICENSE)

    version:        Initial release: Nov 2005
                    Ocean adaptation: July 2012

    author:         Kris, Gavin Norman

    A set of functions for converting strings to integer values.

    This module is adapted from tango.text.convert.Integer. The functions have
    been modified so that they do not throw exceptions, instead denoting errors
    via their bool return value. This is more efficient and avoids the tango
    style of always throwing new Exceptions upon error.

*******************************************************************************/

module ocean.text.convert.Integer;


/*******************************************************************************

    Parse an integer value from the provided string. The exact type of integer
    parsed is determined by the template parameter T (see below).

    The string is inspected for a sign and an optional radix prefix. A radix may
    be provided as an argument instead, whereupon it must match the prefix
    (where present). When radix is set to zero, conversion will default to
    decimal.

    Template params:
        C = char type of string
        T = type of integer to parse (must be int, uint, long or ulong)

    Params:
        digits = string to parse
        value = receives parsed integer
        radix = specifies which radix to interpret the string as

    Returns:
        true if parsing succeeded

*******************************************************************************/

public bool toInteger ( C, T ) ( C[] digits, out T value, uint radix = 0 )
{
    static if ( is(T == int) )
    {
        return toInt(digits, value, radix);
    }
    else static if ( is(T == uint) )
    {
        return toUint(digits, value, radix);
    }
    else static if ( is(T == long) )
    {
        return toLong(digits, value, radix);
    }
    else static if ( is(T == ulong) )
    {
        return toUlong(digits, value, radix);
    }
    else
    {
        static assert(false, "toInteger: T must be one of {int, uint, long, ulong}, not "
            ~ T.stringof);
    }
}


/*******************************************************************************

    Parse an integer value from the provided string.

    The string is inspected for a sign and an optional radix prefix. A radix may
    be provided as an argument instead, whereupon it must match the prefix
    (where present). When radix is set to zero, conversion will default to
    decimal.

    Template params:
        T = char type of string

    Params:
        digits = string to parse
        value = receives parsed integer
        radix = specifies which radix to interpret the string as

    Returns:
        true if parsing succeeded

*******************************************************************************/

public bool toInt ( T ) ( T[] digits, out int value, uint radix = 0 )
{
    long long_value;
    if ( !toLong(digits, long_value, radix) )
    {
        return false;
    }

    if ( long_value > value.max || long_value < value.min )
    {
        return false;
    }

    value = long_value;
    return true;
}


/*******************************************************************************

    Parse an unsigned integer value from the provided string.

    The string is inspected for a sign and an optional radix prefix. A radix may
    be provided as an argument instead, whereupon it must match the prefix
    (where present). When radix is set to zero, conversion will default to
    decimal.

    Template params:
        T = char type of string

    Params:
        digits = string to parse
        value = receives parsed integer
        radix = specifies which radix to interpret the string as

    Returns:
        true if parsing succeeded

*******************************************************************************/

public bool toUint ( T ) ( T[] digits, out uint value, uint radix = 0 )
{
    ulong long_value;
    if ( !toUlong(digits, long_value, radix) )
    {
        return false;
    }

    if ( long_value > value.max || long_value < value.min )
    {
        return false;
    }

    value = long_value;
    return true;
}


/*******************************************************************************

    Parse a long value from the provided string.

    The string is inspected for a sign and an optional radix prefix. A radix may
    be provided as an argument instead, whereupon it must match the prefix
    (where present). When radix is set to zero, conversion will default to
    decimal.

    Template params:
        T = char type of string

    Params:
        digits = string to parse
        value = receives parsed integer
        radix = specifies which radix to interpret the string as

    Returns:
        true if parsing succeeded

*******************************************************************************/

public bool toLong ( T ) ( T[] digits, out long value, uint radix = 0 )
{
    bool negative;
    uint len;
    ulong x;

    auto trimmed = trim(digits, negative, radix);
    convert(digits[trimmed..$], x, len, radix);

    if ( len == 0 || trimmed + len < digits.length )
    {
        return false;
    }

    if ( (negative && -x < value.min) || (!negative && x > value.max) )
    {
        return false;
    }

    value = cast(long)(negative ? -x : x);
    return true;
}


/*******************************************************************************

    Parse an unsigned long value from the provided string.

    The string is inspected for a sign and an optional radix prefix. A radix may
    be provided as an argument instead, whereupon it must match the prefix
    (where present). When radix is set to zero, conversion will default to
    decimal.

    Template params:
        T = char type of string

    Params:
        digits = string to parse
        value = receives parsed integer
        radix = specifies which radix to interpret the string as

    Returns:
        true if parsing succeeded

*******************************************************************************/

public bool toUlong ( T ) ( T[] digits, out ulong value, uint radix = 0 )
{
    bool negative;
    uint len;
    ulong x;

    auto trimmed = trim(digits, negative, radix);
    if ( negative )
    {
        return false;
    }

    convert(digits[trimmed..$], x, len, radix);
    if ( len == 0 || trimmed + len < digits.length )
    {
        return false;
    }

    value = x;
    return true;
}


/*******************************************************************************

    Convert the provided 'digits' into an integer value,
    without checking for a sign or radix. The radix defaults
    to decimal (10).

    Returns the value and updates 'ate' with the number of
    characters consumed.

    Throws: none. The 'ate' param should be checked for valid input.

*******************************************************************************/

private bool convert ( T ) ( T[] digits, out ulong value, out uint eaten,
    uint radix = 10 )
{
    foreach (c; digits)
    {
        if (c >= '0' && c <= '9')
        {}
        else
           if (c >= 'a' && c <= 'z')
               c -= 39;
           else
              if (c >= 'A' && c <= 'Z')
                  c -= 7;
              else
                 break;

        if ((c -= '0') < radix)
        {
            auto old_value = value;
            value = value * radix + c;
            if ( value < old_value ) // integer overflow
            {
                return false;
            }

            ++eaten;
        }
        else
           break;
    }

    return true;
}


/*******************************************************************************

    Strip leading whitespace, extract an optional +/- sign,
    and an optional radix prefix. If the radix value matches
    an optional prefix, or the radix is zero, the prefix will
    be consumed and assigned. Where the radix is non zero and
    does not match an explicit prefix, the latter will remain
    unconsumed. Otherwise, radix will default to 10.

    Returns the number of characters consumed.

*******************************************************************************/

private uint trim ( T ) ( T[] digits, ref bool negative, ref uint radix )
{
    T       c;
    T*      p = digits.ptr;
    auto    len = digits.length;

    if (len)
       {
       // strip off whitespace and sign characters
       for (c = *p; len; c = *++p, --len)
            if (c is ' ' || c is '\t')
               {}
            else
               if (c is '-')
                   negative = true;
               else
                  if (c is '+')
                      negative = false;
               else
                  break;

       // strip off a radix specifier also?
       auto r = radix;
       if (c is '0' && len > 1)
           switch (*++p)
                  {
                  case 'x':
                  case 'X':
                       ++p;
                       r = 16;
                       break;

                  case 'b':
                  case 'B':
                       ++p;
                       r = 2;
                       break;

                  case 'o':
                  case 'O':
                       ++p;
                       r = 8;
                       break;

                  default:
                        --p;
                       break;
                  }

       // default the radix to 10
       if (r is 0)
           radix = 10;
       else
          // explicit radix must match (optional) prefix
          if (radix != r)
              if (radix)
                  p -= 2;
              else
                 radix = r;
       }

    // return number of characters eaten
    return (p - digits.ptr);
}



/*******************************************************************************

    Unit test

*******************************************************************************/

unittest
{
    int i;
    uint ui;
    long l;
    ulong ul;

    // basic functionality
    toInt("1", i); assert (i == 1);
    toUint("1", ui); assert (i == 1);
    toLong("1", l); assert (l == 1);
    toUlong("1", ul); assert (ul == 1);

    // basic functionality with wide chars
    toInt("1"w, i); assert (i == 1);
    toUint("1"w, ui); assert (i == 1);
    toLong("1"w, l); assert (l == 1);
    toUlong("1"w, ul); assert (ul == 1);

    // basic functionality with double chars
    toInt("1"d, i); assert (i == 1);
    toUint("1"d, ui); assert (i == 1);
    toLong("1"d, l); assert (l == 1);
    toUlong("1"d, ul); assert (ul == 1);

    // basic signed functionality
    toInt("+1", i); assert (i == 1);
    toUint("+1", ui); assert (i == 1);
    toLong("+1", l); assert (l == 1);
    toUlong("+1", ul); assert (ul == 1);

    toInt("-1", i); assert (i == -1);
    assert(toUint("-1", ui) == false);
    toLong("-1", l); assert (l == -1);
    assert(toUlong("-1", ul) == false);

    // basic functionality + radix
    toInt("1", i, 10); assert (i == 1);
    toUint("1", ui, 10); assert (i == 1);
    toLong("1", l, 10); assert (l == 1);
    toUlong("1", ul, 10); assert (ul == 1);

    // numerical limits
    toInt("-2147483648", i); assert(i == int.min);
    toInt("2147483647", i); assert(i == int.max);
    toUint("4294967295", ui); assert(ui == uint.max);
    toLong("-9223372036854775808", l); assert(l == long.min);
    toLong("9223372036854775807", l); assert(l == long.max);
    toUlong("18446744073709551615", ul); assert(ul == ulong.max);

    // beyond numerical limits
    assert(toInt("-2147483649", i) == false);
    assert(toInt("2147483648", i) == false);
    assert(toUint("4294967296", ui) == false);
    assert(toLong("-9223372036854775809", l) == false);
    assert(toLong("9223372036854775808", l) == false);
    assert(toUlong("18446744073709551616", ul) == false);

    // hex
    toInt("a", i, 16); assert(i == 0xa);
    toInt("b", i, 16); assert(i == 0xb);
    toInt("c", i, 16); assert(i == 0xc);
    toInt("d", i, 16); assert(i == 0xd);
    toInt("e", i, 16); assert(i == 0xe);
    toInt("f", i, 16); assert(i == 0xf);
    toInt("A", i, 16); assert(i == 0xa);
    toInt("B", i, 16); assert(i == 0xb);
    toInt("C", i, 16); assert(i == 0xc);
    toInt("D", i, 16); assert(i == 0xd);
    toInt("E", i, 16); assert(i == 0xe);
    toInt("F", i, 16); assert(i == 0xf);

    toUlong("FF", ul, 16); assert(ul == ubyte.max);
    toUlong("FFFF", ul, 16); assert(ul == ushort.max);
    toUlong("ffffFFFF", ul, 16); assert(ul == uint.max);
    toUlong("ffffFFFFffffFFFF", ul, 16); assert(ul == ulong.max);

    // oct
    toInt("55", i, 8); assert(i == 055);
    toInt("100", i, 8); assert(i == 0100);

    // bin
    toInt("10000", i, 2); assert(i == 0b10000);

    // trim
    toInt("    \t20", i); assert(i == 20);
    toInt("    \t-20", i); assert(i == -20);
    toInt("-    \t 20", i); assert(i == -20);

    // recognise radix prefix
    toUlong("0xFFFF", ul); assert(ul == ushort.max);
    toUlong("0XffffFFFF", ul); assert(ul == uint.max);
    toUlong("0o55", ul); assert(ul == 055);
    toUlong("0O100", ul); assert(ul == 0100);
    toUlong("0b10000", ul); assert(ul == 0b10000);
    toUlong("0B1010", ul); assert(ul == 0b1010);

    // recognise wrong radix prefix
    assert(toUlong("0x10", ul, 10) == false);
    assert(toUlong("0b10", ul, 10) == false);
    assert(toUlong("0o10", ul, 10) == false);

    // empty string handling (pasring error)
    assert(toInt("", i) == false);
    assert(toUint("", ui) == false);
    assert(toLong("", l) == false);
    assert(toUlong("", ul) == false);
}

