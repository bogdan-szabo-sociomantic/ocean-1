/******************************************************************************

        copyright:      Copyright (c) 2009 sociomantic labs. All rights reserved

        license:        BSD style: $(LICENSE)
        
        version:        May 2009: Initial release
                        
        author:         Thomas Nicolai, Lars Kirchhoff

*******************************************************************************/

module  ocean.io.digest.Fnv;

private import tango.text.convert.Integer : format;

/*******************************************************************************

        Fowler / Noll / Vo (FNV) Hash Module

        Very fast hashing algorithm implementation with support for 32/64 bit 
        hashes.

        32bit ~ 3704333.44 hash/sec
        64bit ~ 1728119.76 hash/sec
        
        ---
        
        import ocean.io.digest.Fnv;
        
        char[] string = "tohash";
        
        auto fnv = new Fnv;
        
        fnv.update(string);
        
        char[] hash = fnv.hexDigest;
        
        ---
        
        We should use this hash algorithm in combination with this consistent 
        hash algorithm in order to build a distributed hash table (DTH)
        
        http://www.audioscrobbler.net/development/ketama/
        svn://svn.audioscrobbler.net/misc/ketama/
        http://pdos.csail.mit.edu/chord/
        
        ---
        
        References
        
        http://www.isthe.com/chongo/tech/comp/fnv/
        http://www.azillionmonkeys.com/qed/hash.html
        http://www.azillionmonkeys.com/qed/hash.c
        http://www.digitalmars.com/d/2.0/htomodule.html

        http://www.team5150.com/~andrew/blog/2007/03/breaking_superfasthash.html
        http://www.team5150.com/~andrew/blog/2007/03/when_bad_hashing_means_good_caching.html
        http://www.azillionmonkeys.com/qed/hash.html
        
*******************************************************************************/

class Fnv
{
 
    /**************************************************************************
    
            32/64 Bit Definitions

     **************************************************************************/ 
    
    
    private         int             size;
    
    alias           uint            Fnv32;
    alias           ulong           Fnv64;

    private         const Fnv32     FNV_32_PRIME = cast(Fnv32)0x01000193;
    private         const Fnv64     FNV_64_PRIME = cast(Fnv64)0x100000001b3;
    
    private         void[]          data;
    
    
    /**************************************************************************
    
            Constructor

            size = number of bytes of hash (8 or 16)
            
     **************************************************************************/
    
    
    public this ( int size = 8 ) 
    { 
        assert ( size == 8 || 16 );
        this.size = size;
    }
    
    
    /**************************************************************************

            The digest size is 8/16 bytes

    **************************************************************************/
    
    
    public uint digestSize () { return size; }
    

    /**************************************************************************

            The digest size is 8/16 bytes

     **************************************************************************/
    
    
    public Fnv update ( void[] input )
    {
            data = input;
            
            return this;
    }
    
    
    /**************************************************************************
    
            32 Bit hash function

     **************************************************************************/
    
    
    public Fnv32 fnv_32_str ( void[] str, Fnv32 hval = 0 )
    {
            ubyte* ptr = cast(ubyte*) &str[0];
    
            for ( int i = 0; i < str.length; i++ )
            {
                hval += (hval<<1) + (hval<<4) + (hval<<7) + (hval<<8) + (hval<<24);
                hval ^= cast(ubyte)*ptr++;
            }
    
            return hval;
    }

    
    
    /**************************************************************************
    
            64 Bit hash function

     **************************************************************************/
    
    
    public Fnv64 fnv_64_str ( void[] str, Fnv64 hval = 0 )
    {
            ubyte* ptr = cast(ubyte*) &str[0];
    
            for ( int i = 0; i < str.length; i++ )
            {
                hval += (hval << 1) + (hval << 4) + (hval << 5) + (hval << 7) + (hval << 8) + (hval << 40);
                hval ^= cast(Fnv64)*ptr++;
            }
    
            return hval;
    }
    
    
    
    /**************************************************************************
    
            hexDigest

     **************************************************************************/
    
    
    public char[] hexDigest ( char[] buffer = null ) 
    {
            char[] hash;
            
            uint ds = digestSize();
            auto buf = new char[ds];
            
            if ( size == 8 )
            {
                Fnv32 hx = fnv_32_str(data);
                hash = format(buf, hx, "X8");
            }
            else
            {
                Fnv64 hx = fnv_64_str(data);
                hash = format(buf, hx, "X16");
            }

            return hash;
    }
    
}

/******************************************************************************

    UnitTest

******************************************************************************/

version ( Fnv )
{
    
        import tango.time.StopWatch;
        import tango.util.log.Trace;
        
        void main () 
        {
            StopWatch x;
            char[] string = "norm";
            
            auto fvn = new Fnv(8);
            
            fvn.update(string);
            
            x.start;
            
            for ( int i = 0; i < 10_000_000; i++ )
            {
                fvn.hexDigest;
            }
            
            Trace.formatln("{} hash/sec", 10_000_000/x.stop);
            Trace.formatln("string = {} hash = {}", string, fvn.hexDigest);
        }
        
        
}
