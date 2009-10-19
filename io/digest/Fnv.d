/******************************************************************************

        copyright:      Copyright (c) 2009 sociomantic labs. All rights reserved

        license:        BSD style: $(LICENSE)
        
        version:        May 2009: Initial release
                        
        author:         David Eckardt, Thomas Nicolai, Lars Kirchhoff

*******************************************************************************/

module  ocean.io.digest.Fnv;

private import tango.io.digest.Digest;

private import tango.core.ByteSwap;

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
    
        FNV magic constants and endianness
 
     **************************************************************************/
    
    
    static if (is (T == uint))
    {
        static const T FNV_PRIME = 0x0100_0193; // 32 bit prime
        static const T FNV_INIT  = 0x811C_9DC5; // 32 bit inital digest
        
        private alias ByteSwap.swap32 toBigEnd;
    }
    else static if (is (T == ulong))
    {
        static const T FNV_PRIME = 0x0000_0100_0000_01B3; // 64 bit prime
        static const T FNV_INIT  = 0xCBF2_9CE4_8422_2325; // 64 bit inital digest
        
        private alias ByteSwap.swap64 toBigEnd;
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
    
        unions

     **************************************************************************/

    
    /**
     * Endianness aware integer to byte array converter
     * 
     * Usage:
     * 
     * ---
     * 
     *      Fnv32.BinConvert bc;
     *      
     *      ubyte[] binstr = (bc = 0xAFFE4711);
     *      
     *      // binstr now is [0xAF, 0xFE, 0x47, 0x11]
     *      
     * ---
     * 
     */
     union BinConvert
     {
         typedef ubyte[T.sizeof] BinString;
         
         BinString array;
         
         T value;
         
         ubyte[] opAssign ( T val )
         {
             T old_val = value;
             
             value = val;
             
             version (LittleEndian) toBigEnd(array);
             
             return array.dup;
         }
     };
    
    
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
            This method is endianness-aware: The returned array has always the
            least-order byte at byte [0] (big endian).
            
            If the buffer is not large enough to hold the
            digest, a new buffer is allocated and returned.
            The algorithm state is always reset after a call to
            binaryDigest. Use the digestSize method to find out how
            large the buffer has to be.
            
    *********************************************************************/

    
    public ubyte[] binaryDigest( ubyte[] buffer = null )
    {
        scope(exit) this.reset();
        
        BinConvert bc;
        
        bc = this.digest;
        
        if ( buffer )
        {
            buffer.length = this.digestSize();
            
            foreach (i, d; bc.array) { buffer[i] = d; }
        }
        
        return buffer? buffer: bc.array.dup;
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
    
    
    /**************************************************************************
    
        extenstion class methods (in addition to the Digest standard methods)

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
            hash = fnv1_core(d, hash);
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

**************************************************************************/

private template errmsg ( char[] func )
{
    const errmsg = "unit test failed for " ~ func;
}

unittest
{
    const char[]  test_str     = "Die Katze tritt die Treppe krumm.";
    
    const uint    digest32_val = 0xAF_7C_5F_4B;
    const ubyte[] digest32_arr = [0xAF, 0x7C, 0x5F, 0x4B];
    const char[]  digest32_str = "af7c5f4b";
    
    const ulong   digest64_val = 0xE1_C5_43_7F_EE_A6_C1_6B;
    const ubyte[] digest64_arr = [0xE1, 0xC5, 0x43, 0x7F, 0xEE, 0xA6, 0xC1, 0x6B];
    const char[]  digest64_str = "e1c5437feea6c16b";
    
    /**************************************************************************
     
        Fnv32/Fnv64 class methods test
      
     **************************************************************************/
    
    Fnv32 fnv32 = new Fnv32;
    
    assert(fnv32.update(test_str).binaryDigest() == digest32_arr, errmsg!("Fnv32.binaryDigest()"));
    assert(fnv32.update(test_str).hexDigest()    == digest32_str, errmsg!("Fnv32.hexDigest()"));
    
    
    Fnv64 fnv64 = new Fnv64;
    
    assert(fnv64.update(test_str).binaryDigest() == digest64_arr, errmsg!("Fnv64.binaryDigest()"));
    assert(fnv64.update(test_str).hexDigest()    == digest64_str, errmsg!("Fnv64.hexDigest()"));
    
    
    /**************************************************************************
    
        Fnv32/Fnv64 core methods test
  
     **************************************************************************/
    
    assert(Fnv32.fnv1(test_str) == digest32_val, errmsg!("Fnv32.fnv1()"));
    assert(Fnv64.fnv1(test_str) == digest64_val, errmsg!("Fnv64.fnv1()"));
    
    uint  digest32 = Fnv32.FNV_INIT;
    ulong digest64 = Fnv64.FNV_INIT;
    
    foreach ( d; cast (ubyte[]) test_str )
    {
        digest32 = Fnv32.fnv1_core(d, digest32);
        digest64 = Fnv64.fnv1_core(d, digest64);
    }
    
    assert(Fnv32.fnv1(test_str) == digest32_val, errmsg!("fnv1_core()"));
    assert(Fnv64.fnv1(test_str) == digest64_val, errmsg!("fnv1_core()"));
}
