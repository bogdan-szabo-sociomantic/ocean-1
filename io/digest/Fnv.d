/******************************************************************************

        copyright:      Copyright (c) 2009 sociomantic labs. All rights reserved

        license:        BSD style: $(LICENSE)
        
        version:        May 2009: Initial release
                        
        author:         David Eckardt, Thomas Nicolai, Lars Kirchhoff

*******************************************************************************/

module  ocean.io.digest.Fnv;

private import tango.io.digest.Digest;

private import tango.text.convert.Format;

/*******************************************************************************

        Fowler / Noll / Vo (FNV) Hash Module

        Very fast hashing algorithm implementation with support for 32/64 bit 
        hashes.

        32bit ~ 3704333.44 hash/sec
        64bit ~ 1728119.76 hash/sec
        
        --
        
        Usage
        
        Example 1: Using a Fnv32 object
        
        ---
        
            import ocean.io.digest.Fnv;
            
            auto fnv32 = new Fnv32;
            auto fnv64 = new Fnv64;
            
            char[] string = "tohash";
            
            fnv32.update(string);
            fnv64.update(string);
            
            char[] hash32 = fnv32.hexDigest;
            char[] hash64 = fnv64.hexDigest;
        
        ---
        
        Example 2: Using the static fnv1() hash method
        
        ---
        
            import ocean.io.digest.Fnv;
        
            char[] string = "tohash";
            
            uint  hash32 = Fnv32.fnv1(string);
            ulong hash64 = Fnv64.fnv1(string);
        
        ---
        
        --
        
        We should use this hash algorithm in combination with this consistent 
        hash algorithm in order to build a distributed hash table (DTH)
        
        http://www.audioscrobbler.net/development/ketama/
        svn://svn.audioscrobbler.net/misc/ketama/
        http://pdos.csail.mit.edu/chord/
        
        --
        
        References
        
        http://www.isthe.com/chongo/tech/comp/fnv/
        http://www.azillionmonkeys.com/qed/hash.html
        http://www.azillionmonkeys.com/qed/hash.c
        http://www.digitalmars.com/d/2.0/htomodule.html

        http://www.team5150.com/~andrew/blog/2007/03/breaking_superfasthash.html
        http://www.team5150.com/~andrew/blog/2007/03/when_bad_hashing_means_good_caching.html
        http://www.azillionmonkeys.com/qed/hash.html
        
        --
        
        NOTE: Fnv32 and Fnv64 are defined as aliases. Since The D language does
              not allow forward referencing, these are defined AFTER the class
              definition near the end of this document:
        
        ---
        
        alias Fnv!(uint ) Fnv32;
        alias Fnv!(ulong) Fnv64;
        
        ---
        
*******************************************************************************/


class Fnv ( T ) : Digest
{
    /**************************************************************************
    
        FNV magic constants
 
     **************************************************************************/
    
    
    static if (is (T == uint))
    {
        static const T FNV_PRIME = 0x0100_0193; // 32 bit prime
        static const T FNV_INIT  = 0x811C_9DC5; // 32 bit inital digest
    }
    else static if (is (T == ulong))
    {
        static const T FNV_PRIME = 0x0000_0100_0000_01B3; // 64 bit prime
        static const T FNV_INIT  = 0xCBF2_9CE4_8422_2325; // 64 bit inital digest
    }
    /*
    // be prepared for the day when Walter introduces cent...
    else static if (is (T == ucent))
    {
        static const T FNV_PRIME = 0x0000_0000_0100_0000_0000_0000_0000_013B; // 128 bit prime
        static const T FNV_PRIME = 0x6C62_272E_07BB_0142_62B8_2175_6295_C58D; // 128 bit inital digest
    }
    */
    else static assert (false, "type '" ~ T.stringof ~
                               "' is not supported, only uint and ulong");
    
    
    /**************************************************************************
    
        class properties

     **************************************************************************/
    
    
    private T digest = this.FNV_INIT;
    
    
    /**************************************************************************
    
        Tango Digest class methods

     **************************************************************************/
    
    
    /*********************************************************************
    
        Processes data
        
        Remarks:
              Updates the hash algorithm state with new data
      
     *********************************************************************/
    
    
    public Digest update ( void[] data )
    {
        this.digest = this.fnv1(data, this.digest);
        
        return this;
    }
    
    
    /********************************************************************
    
        Computes the digest and resets the state
    
        Params:
            buffer = a buffer can be supplied for the digest to be
                     written to
    
        Remarks:
            If the buffer is not large enough to hold the
            digest, a new buffer is allocated and returned.
            The algorithm state is always reset after a call to
            binaryDigest. Use the digestSize method to find out how
            large the buffer has to be.
            
    *********************************************************************/

    
    public ubyte[] binaryDigest( ubyte[] buffer = null )
    {
        scope(exit) this.reset();
        
        buffer.length = this.digestSize();
        
        * cast (typeof(this.digest) *) & buffer = this.digest;
        
        return buffer;
    }
    
    
    /********************************************************************
    
        Returns the size in bytes of the digest
        
        Returns:
          the size of the digest in bytes
    
        Remarks:
          Returns the size of the digest.
          
    *********************************************************************/

    
    public uint digestSize ( )
    {
        return T.sizeof;
    }
    
    
    /*********************************************************************
        
        Computes the digest as a hex string and resets the state
        
        Params:
            S      = buffer element data type
            
            upcase = true: use upper case digits 'A' -- 'F'; false: use lower
                     case (default: false)
            
            buffer = a buffer can be supplied in which the digest
                     will be written. It needs to be able to hold
                     2 * digestSize chars
     
        Remarks:
             If the buffer is not large enough to hold the hex digest,
             a new buffer is allocated and returned. The algorithm
             state is always reset after a call to hexDigestUni.
             
    *********************************************************************/
    
    
    public S[] hexDigestUni ( S, bool upcase = false ) ( S[] buffer = null )
    {
        scope(exit) this.reset();
        
        buffer = Format!(S)(this.HexFormatter!(upcase).xfm, this.digest);
        
        return buffer;
    }
    
    
    /*********************************************************************
    
        Computes the digest as a hex string and resets the state
        
        Params:
            buffer = a buffer can be supplied in which the digest
                     will be written. It needs to be able to hold
                     2 * digestSize chars
     
        Remarks:
             The letter digits 'a' -- 'f' are lower case.
             If the buffer is not large enough to hold the hex digest,
             a new buffer is allocated and returned. The algorithm
             state is always reset after a call to hexDigest.
             
     *********************************************************************/
    
    
    public alias hexDigestUni!(char) hexDigest;
    
    
    /*********************************************************************
    
        Computes the digest as a hex string and resets the state
        
        Params:
            buffer = a buffer can be supplied in which the digest
                     will be written. It needs to be able to hold
                     2 * digestSize chars
     
        Remarks:
             The letter digits 'A' -- 'F' are upper case.
             If the buffer is not large enough to hold the hex digest,
             a new buffer is allocated and returned. The algorithm
             state is always reset after a call to hexDigest.
         
     *********************************************************************/
    
    
    public alias hexDigestUni!(char, true) hexDigestUp;
    
    
    
    /**************************************************************************
    
        utility class methods (in addition to the Tango Digest standard methods)

     **************************************************************************/

    
    /**
     * resets the state
     * 
     * Returns:
     *      this instance
     */
    public Digest reset ( )
    {
        this.digest = this.FNV_INIT;
        
        return this;
    }
    
    
    
    /**
     * simply returns the digest
     * 
     * Returns:
     *      digest
     */
    public T getDigest ( )
    {
        return this.digest;
    }
    
    
    /**************************************************************************
    
        core methods
    
     **************************************************************************/
    
    
    
    /**
     * Computes a FNV1 digest from data.
     * 
     * Usage:
     * 
     * ---
     *      
     *      import ocean.io.digest.Fnv;
     *      
     *      char[] data;
     * 
     *      uint  digest32 = Fnv32.fnv1(data);
     *      ulong digest64 = Fnv64.fnv1(data);
     * 
     * ---
     *
     * 
     * Params:
     *      data = data to digest
     *      hash = initial digest; defaults to the magic 32 bit or 64 bit
     *             initial value, according to T
     *      
     * Returns:
     *      resulting digest
     */
    public static T fnv1 ( void[] data, T hash = FNV_INIT )
    {
        foreach (d; cast (ubyte[]) data)
        {
            hash = fnv1_core!(T)(d, hash);
        }
        
        return hash;
    }
    
    
    
    /**
     * FNV1 core; digests one octet "d" to "hash"
     * 
     * Params:
     *      d    = data to digest
     *      hash = initial digest
     *  
     * Returns:
     *      resulting digest
     */
    public static T fnv1_core ( ubyte d, T hash )
    {
        return (hash * FNV_PRIME) ^ d;
    }
    
    
    /**************************************************************************
    
        helper templates

     **************************************************************************/
    
    
    /**
    * Compile-time hexadecimal format string generator
    */
    private template HexFormatter ( bool upcase = false )
    {
        static if (upcase)
        {
            const x = 'X';
        }
        else
        {
            const x = 'x';
        }
        
        const HexLen = T.sizeof * 2;
        
        const char[] xfm = "{:" ~ x ~ HexLen.stringof ~ "}";
    }
} // Fnv


/**************************************************************************

    aliases

**************************************************************************/


/**
 * Convenience aliases for 32-bit and 64-bit Fnv class template instances. The D
 * language requires these aliases to occur _after_ the definition of the class
 * they refer to.
 * Usage as explained on the top of this module.
 */

alias Fnv!(uint ) Fnv32;
alias Fnv!(ulong) Fnv64;


/**************************************************************************

    unit test
    
    TODO: 64 bit testing

**************************************************************************/

unittest
{
    const char[] TEST_STR = "Die Katze tritt die Treppe krumm.";
    
    const uint digest32 = 0xAF7C5F4B;
    
    assert(Fnv!(uint).fnv1(TEST_STR) == digest32, __FILE__ ~ " : fnv1: unit test failed");
    assert(Fnv32.fnv1(TEST_STR)      == digest32, __FILE__ ~ " : fnv1: unit test failed");
}

