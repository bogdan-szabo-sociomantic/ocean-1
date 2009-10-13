/******************************************************************************

        copyright:      Copyright (c) 2009 sociomantic labs. All rights reserved

        license:        BSD style: $(LICENSE)
        
        version:        May 2009: Initial release
                        
        author:         David Eckardt, Thomas Nicolai, Lars Kirchhoff

*******************************************************************************/

module  ocean.io.digest.Fnv;

import tango.text.convert.Format;

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

struct Fnv
{
    /**************************************************************************
    
        FNV constants templates
 
     **************************************************************************/
    
    public static const uint  FNV_32_PRIME  = 0x0100_0193;
    public static const uint  FNV_32_INIT   = 0x811C_9DC5;
    
    public static const ulong FNV_64_PRIME  = 0x0000_0100_0000_01B3;
    public static const ulong FNV_64_INIT   = 0xCBF2_9CE4_8422_2325;
    
    /*
    // be prepared for the day when Walter introduces cent...
    public static const ucent FNV_128_INIT  = 0x0000_0000_0100_0000_0000_0000_0000_013B;
    public static const ucent FNV_128_PRIME = 0x6C62_272E_07BB_0142_62B8_2175_6295_C58D;
    */
    
    
    /**
     *  Reflects the length of the hexadecimal string representing a number of
     *  type T.
     */
    public static template HEXLEN ( T )
    {
        const int HEXLEN = T.sizeof * 2;
    }

    /**************************************************************************
    
         FNV magic constants templates
      
     **************************************************************************/
    
    
    /**
     *  FNV prime number template. T may either be uint (32 bit) or ulong (64
     *  bit).
     *  Usage: uint p = FNV_PRIME!(uint);
     */
    public static template FNV_PRIME ( T )
    {
        static if (is (T == uint))
        {
            static const T FNV_PRIME = FNV_32_PRIME;
        }
        else static if (is (T == ulong))
        {
            static const T FNV_PRIME = FNV_64_PRIME;
        }
        else static assert (false, TypeErr!(T));
    }
    
    
    
    /**
     *  FNV initial digest template. T may either be uint (32 bit) or ulong (64
     *  bit).
     *  Usage: ulong i = FNV_INIT!(ulong);
     */
    public static template FNV_INIT ( T )
    {
        static if (is (T == uint))
        {
            static const T FNV_INIT = FNV_32_INIT;
        }
        else static if (is (T == ulong))
        {
            static const T FNV_INIT = FNV_64_INIT;
        }
        else static assert (false, TypeErr!(T));
    }
    
    
    /**************************************************************************
     
         helper templates
     
     **************************************************************************/
    
    
    /**
     * Compile error for unsupported types
     */
    private static template TypeErr ( T )
    {
        const TypeErr =  __FILE__ ~ " : fnv_uni: type " ~ T.stringof ~
                         " is not supported, only uint and ulong";
    }
    
    
    /**
     * Compile-time hexadecimal format string generator
     */
    private static template HexFormatter ( T )
    {
        const char[] HexFormatter = "{:X" ~ HEXLEN!(T).stringof ~ '}';
    }
    
    

    
    /**************************************************************************
    
        digest functions
    
     **************************************************************************/
    
    
    
    /**
     * Hexadecimal FNV1 digest string generator
     * 
     * Params:
     *      S    = output string element type (usually char)
     *      T    = hash data type (uint for 32 or ulong for 64 bits width)
     *      data = data to digest
     *      
     * Returns:
     *      string reflecting hexadecimal representation of FNV1 digest
     *      
     * Usage example:
     * ---
     *      // compute an uint (32 bit) FNV digest from data and return its
     *      // hexadecimal representation as a char[] string
     *      
     *      ubyte[] data;
     *      // fill data
     *      char[] hash = Fnv.fnv1Hex!(char, uint)(data);
     * --- 
     */
    public static char[] fnv1Hex ( S, T ) ( void[] data, T hash = FNV_INIT!(T) )
    {
        return Format!(S)(HexFormatter!(T), fnv1!(T)(data, hash));
    }
    
    /**
     * FNV1 digest template for supported types (currently uint for 32 and ulong
     * for 64 bits width); digests a sequence of octets "data" using the initial
     * value "hash" which is set to the magic initializer by default but is also
     * suitable to use for chaining or iterating:
     * 
     * Example 1 -- chaining digests ("!(T)" template instantiation parameters
     * omitted for better readability):
     * ---
     * 
     * fnv1(str_b, fnv1(str_a));
     * 
     * // is equivalent to
     * 
     * fnv1(str_a ~ str_b);
     * 
     * ---
     * Example 2 -- generate one digest over an array of strings:
     * ---
     * 
     * char[][] strings;
     * 
     * uint hash = FNV_INIT!(uint);
     * 
     * foreach (string; strings)
     * {
     *      hash = fnv1!(uint)(string);
     * }
     * 
     * ---
     */
    public static T fnv1 ( T ) ( void[] data, T hash = FNV_INIT!(T) )
    {
        foreach (d; cast (ubyte[]) data)
        {
            hash = fnv1_core!(T)(d, hash);
        }
        
        return hash;
    }
    
    
    
    /**
     * FNV1 core; digests one octet "d" to "hash"
     */
    public static T fnv1_core ( T ) ( ubyte d, T hash )
    {
        return (hash * FNV_PRIME!(T)) ^ d;
    }
    
    
    /**************************************************************************
    
        unit test

    **************************************************************************/
    
    unittest
    {
        const char[] TEST_STR = "Die Katze tritt die Treppe krumm.";
                   
        assert(fnv1!(uint)(TEST_STR) == 0xAF7C5F4B, __FILE__ ~ " : fnv1: unit test failed");
        
        assert(fnv1Hex!(char, uint)(TEST_STR) == "AF7C5F4B", __FILE__ ~ " : fnv1Hex: unit test failed");
    }
}
