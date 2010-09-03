/******************************************************************************

    Converts values into a metric representation with a scaled mantissa and a
    decimal exponent unit prefix character.
    
    copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved
    
    version:        August 2010: Initial release
    
    authors:        David Eckardt
    
 ******************************************************************************/

module ocean.text.util.MetricPrefix;

/******************************************************************************

    Returns x * 2 ^ e.
    
    Params:
        x = value to scale by binary power of e
        e = binary exponent
        
    Returns:
        x * 2 ^ e

 ******************************************************************************/

extern (C) float ldexpf(float x, int e);
extern (C) float frexpf(float x, int* e);

/******************************************************************************/

struct MetricPrefix
{
    /**************************************************************************

        Scaled mantissa; set by bin()/dec()
    
    **************************************************************************/

    float scaled = 0.;
    
    /**************************************************************************

        Metric decimal power unit prefix; set by bin()/dec()
    
    **************************************************************************/

    dchar prefix = ' ';
    
    /**************************************************************************

        Converts n into a metric-like prefixed representation, using powers of
        1024.
        Example: For n == 12345678 this.scaled about 11.78 and this.prefix is
        'M'.
        
        Params:
            n = number to convert
            
        Returns:
            this instance

    **************************************************************************/

    typeof (this) bin ( T : float ) ( T n )
    {
        const P = [' ', 'k', 'M', 'G', 'T'];
        
        this.scaled = n;
        
        int i;
        
        static if (is (T : long))
        {
            pragma (msg, typeof (*this).stringof ~ ": " ~ T.stringof ~ " : long");
            
            for (i = 0; (n > 0x400) && (i < P.length); i++)
            {
                n >>= 10;
            }
        }
        else
        {
            pragma (msg, typeof (*this).stringof ~ ": " ~ T.stringof ~ " !: long");
            
            frexpf(n, &i);
            i /= 10;
        }
        
        this.scaled = ldexpf(this.scaled, i * -10);
        
        this.prefix = P[i];
        
        return this;
    }

    /**************************************************************************

        Converts n into a metric prefixed representation.
        Example: For n == 12345678 this.scaled is about 12.35 and this.prefix is
                 'M'.
        
        Params:
            n = number to convert
            p = prefix output
            e = input prefix: 0 = None, 1 = 'k', -1 = 'm', 2 = 'M', -2 = 'µ' etc.,
                              up to +/- 4
            
        Returns:
            number scaled to prefix

    **************************************************************************/

    typeof (this) dec ( T : float ) ( T n, int e = 0 )
    in
    {
        assert (-5 < e && e < 5);
    }
    body
    {
        const P = ['p', 'n', 'µ', 'm', ' ', 'k', 'M', 'G', 'T'];
        
        this.scaled = n;
        
        int i;
        
        for (i = e + 4; (n > 1000) && (i < P.length); i++)
        {
            n           /= 1000;
            this.scaled /= 1000.;
        }
        
        this.prefix = P[i];
        
        return this;
    }
}