/*******************************************************************************

    Math Utility functions

    copyright:      Copyright (c) 2009-2011 sociomantic labs. 
                    All rights reserved

    version:        Oktober 2011: initial release
                    January 2012: added integer pow function

    authors:        Mathias L. Baumann

*******************************************************************************/

module ocean.math.Math;
       
/***************************************************************************

    Integer pow function. Returns the power'th power of base 
    
    Ported from tango, changed to only use integers
    
    Params:
        base  = base number
        power = power
        
    Returns:
        the power'th power of base

***************************************************************************/

public ulong pow ( ulong base, ulong power )
{   
    ulong res = void;
    
    switch (power)
    {
        case 0:
            res = 1;
            break;
        case 1:
            res = base;
            break;
        case 2:
            res = base * base;
            break;
            
        default:
            res = 1;
        
            while (1)
            {
                if (power & 1) res *= base;
                power >>= 1;
                if (!power) break;
                base *= base;                                       
            }
            break;
    }
    
    return res;
}

unittest
{
    ulong x = 46;

    assert(pow(x,0) == 1);
    assert(pow(x,1) == x);
    assert(pow(x,2) == x * x);
    assert(pow(x,3) == x * x * x);
    assert(pow(x,8) == (x * x) * (x * x) * (x * x) * (x * x));    
}

/*******************************************************************************

    Does an integer division, rounding towards the nearest integer.
    Rounds to the even one if both integers are equal near. 

    Params:
        a = number to divide
        b = number to divide by

    Returns:
        number divided according to given description 

*******************************************************************************/

T divRoundEven(T)(T a, T b)
{       
    // both integers equal near?
    if (b % 2 == 0 && (a % b == b / 2 || a % b == -b / 2))
    {
        auto div_rounded_down = a / b;

        auto add = div_rounded_down < 0 ? -1 : 1;

        return div_rounded_down % 2 == 0 ? 
            div_rounded_down : div_rounded_down + add;
    }
    
    if ( (a >= 0) != (b >= 0) )
    {
        return (a - b / 2) / b; 
    }
    else
    {
        return (a + b / 2) / b; 
    }
}

debug private import tango.math.Math : rndlong;
debug private import ocean.util.log.Trace;

unittest
{    
    long roundDivCheat ( long a, long b )
    {       
        real x = cast(real)a / cast(real)b;
        return rndlong(x);
    } 
    
    assert(divRoundEven(-3, 2)  == -2);  
    assert(divRoundEven(3, 2)   == 2);  
    assert(divRoundEven(-3, -2) == 2);  
    assert(divRoundEven(3, -2)  == -2);

    assert(divRoundEven(7, 11) == 1);
    assert(divRoundEven(11, 11) == 1);
    assert(divRoundEven(16, 11) == 1);
    assert(divRoundEven(-17, 11) == -2);    
    assert(divRoundEven(-17, 11) == -2);
    assert(divRoundEven(-16, 11) == -1);
 
    assert(divRoundEven(17, -11) == -2);
    assert(divRoundEven(16, -11) == -1);
    assert(divRoundEven(-17, -11) == 2);
    assert(divRoundEven(-16, -11) == 1);    
 
    for (int i = -100; i <= 100; ++i) for (int j = -100; j <= 100; ++j)
    { 
        if (j != 0)
        {                               
            assert (divRoundEven(i,j) == roundDivCheat(i,j));
        }
    }
}