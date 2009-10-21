/******************************************************************************

        copyright:      Copyright (c) 2009 sociomantic labs. All rights reserved

        license:        BSD style: $(LICENSE)
        
        version:        May 2009: Initial release
                        
        author:         David Eckardt, Thomas Nicolai, Lars Kirchhoff

*******************************************************************************/

module  ocean.io.digest.Fnv1;

private import tango.io.digest.Digest;

private import tango.core.ByteSwap;

/*******************************************************************************

        Fowler / Noll / Vo (FNV) 1/1a Hash Module

        Very fast hashing algorithm implementation with support for 32/64 bit 
        hashes.
        This modules implements two versions of FNV1: FNV1 and FNV1a. The
        difference is extremely slight and Noll himself says:
        
            "Some people use FNV1a instead of FNV1 because they see slightly 
            better dispersion for tiny (<4 octets) chunks of memory. Either
            FNV-1 or FNV-1a make a fine hash."
        
            (cited from http://www.isthe.com/chongo/tech/comp/fnv/)
        
        FNV1a is said to have a wider
        distribution for short messages than FNV1. For details see
        http://www.isthe.com/chongo/tech/comp/fnv/.
        
        The FNV1A template parameter selects FNV1a if set to true on
        instantiation or FNV1 otherwise. It is recommended to use the 
        Fnv1XX/Fnv1aXX aliases.
        
        32bit ~ 3704333.44 hash/sec
        64bit ~ 1728119.76 hash/sec
        
        --
        
        Usage
        
        It is recommended to use these Fnv1 class convenience aliases:
        
         - Fnv132 for 32-bit FNV1 digests
         - Fnv164 for 64-bit FNV1 digests
         - Fnv1a32 for 32-bit FNV1a digests
         - Fnv1a64 for 64-bit FNV1a digests
        
        Example 1: Generating FNV1 digests using class instances
        
        ---
        
            import ocean.io.digest.Fnv1;
            
            auto fnv132 = new Fnv132;
            auto fnv164 = new Fnv164;
            
            char[] string = "tohash";
            
            fnv132.update(string);
            fnv164.update(string);
            
            char[] hash32 = fnv132.hexDigest;
            char[] hash64 = fnv164.hexDigest;
        
        ---
        
        Example 2: Generating FNV1a digests using the static fnv1() method
        
        ---
        
            import ocean.io.digest.Fnv;
        
            char[] string = "tohash";
            
            uint  hash32 = Fnv1a32.fnv1(string);
            ulong hash64 = Fnv1a64.fnv1(string);
        
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
        
        NOTE: Fnv132, Fnv164, Fnv1a32 and Fnv1a64 are defined as aliases. Since
              The D language does not allow forward referencing, these are
              defined AFTER the class definition near the end of this document:
        
        ---
        
        alias Fnv1!(uint,  false) Fnv132;
        alias Fnv1!(ulong, false) Fnv164;
        
        alias Fnv1!(uint,  true ) Fnv1a32;
        alias Fnv1!(ulong, true ) Fnv1a64;
        
        ---
        
*******************************************************************************/


class Fnv1 ( T, bool FNV1A ) : Digest
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
     *      ubyte[] binstr = bc(0xAFFE4711);
     *      
     *      // binstr now is [0xAF, 0xFE, 0x47, 0x11]
     *      
     * ---
     * 
     */
     union BinConvert
     {
         typedef ubyte[T.sizeof] BinString;
         
         /* members */
         
         BinString array;
         
         T         value;
         
         /* cast "value" from integer type "T" to binary string type "BinString"
            considering machine byte order (endianness) */
         
         ubyte[] opCall ( T value )
         {
             this.value = value;
             
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
        
        bc(this.digest);
        
        if ( buffer )
        {
            buffer.length = this.digestSize();
            
            foreach (i, d; bc.array)
            {
                buffer[i] = d;
            }
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
     * Computes a FNV1/FNV1a digest from data.
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
     * FNV1/FNV1a core; digests one octet "d" to "hash"
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
        static if (FNV1A)
        {
            return (hash ^ d) * FNV_PRIME;
        }
        else
        {
            return (hash * FNV_PRIME) ^ d;
        }
    }
} // Fnv


/**************************************************************************

    aliases

**************************************************************************/


/**
 * Convenience aliases for 32-bit and 64-bit Fnv1 class template instances.
 * The D language requires these aliases to occur _after_ the definition of the
 * class they refer to.
 * Usage as explained on the top of this module.
 */

alias Fnv1!(uint,  false) Fnv132;
alias Fnv1!(ulong, false) Fnv164;
alias Fnv1!(uint,  true ) Fnv1a32;
alias Fnv1!(ulong, true ) Fnv1a64;


/**************************************************************************

    unit test

**************************************************************************/

private import ocean.io.digest.Fnv1Test;

private char[] errmsg ( char[] func, Fnv1Test.Data testdata )
{
    char[] errmsg = "unit test failed for " ~ func;
    
    if (testdata.is_text)
    {
        errmsg ~= ": \"" ~ testdata.string ~ "\"";
    }
    
    return errmsg;
}

unittest
{
    scope Fnv132 fnv132 = new Fnv132;
    scope Fnv164 fnv164 = new Fnv164;
    
    scope Fnv1a32 fnv1a32 = new Fnv1a32;
    scope Fnv1a64 fnv1a64 = new Fnv1a64;
    
    foreach (testdata; Fnv1Test.data)
    {
        /**********************************************************************
         
             core methods test
         
         **********************************************************************/
        
        assert(Fnv132.fnv1(testdata.string) == testdata.fnv1_32, errmsg("Fnv132.fnv1", testdata));
        assert(Fnv164.fnv1(testdata.string) == testdata.fnv1_64, errmsg("Fnv164.fnv1", testdata));
        
        assert(Fnv1a32.fnv1(testdata.string) == testdata.fnv1a_32, errmsg("Fnv1a32.fnv1", testdata));
        assert(Fnv1a64.fnv1(testdata.string) == testdata.fnv1a_64, errmsg("Fnv1a64.fnv1", testdata));
        
        /**********************************************************************
        
            class methods test
    
         **********************************************************************/
       
        assert(fnv132.update(testdata.string).binaryDigest == testdata.fnv1_32_bin, errmsg("Fnv132.binaryDigest", testdata));
        assert(fnv164.update(testdata.string).binaryDigest == testdata.fnv1_64_bin, errmsg("Fnv164.binaryDigest", testdata));
        
        assert(fnv1a32.update(testdata.string).hexDigest == testdata.fnv1a_32_hex, errmsg("Fnv1a32.hexDigest", testdata));
        assert(fnv1a64.update(testdata.string).hexDigest == testdata.fnv1a_64_hex, errmsg("Fnv1a64.hexDigest", testdata));
        
    }
}
