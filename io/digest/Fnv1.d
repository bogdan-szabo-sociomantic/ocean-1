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
         
         - Fnv1 for FNV1 digests of the machine's native width
         - Fnv1a for FNV1a digests of the machine's native width
         
         - Fnv132 for 32-bit FNV1 digests
         - Fnv1a32 for 32-bit FNV1a digests
         
         - Fnv164 for 64-bit FNV1 digests
         - Fnv1a64 for 64-bit FNV1a digests
        
        Example 1: Generating FNV1 digests using class instances
        
        ---
        
            import ocean.io.digest.Fnv1;
            
            auto fnv1   = new Fnv1;
            auto fnv132 = new Fnv132;
            auto fnv164 = new Fnv164;
            
            char[] hello = "Hello World!";
            
            fnv1.update(hello);
            fnv132.update(hello);
            fnv164.update(hello);
            
            char[] hash   = fnv1.hexDigest();
            char[] hash32 = fnv132.hexDigest();
            char[] hash64 = fnv164.hexDigest();
        
        ---
        
        Example 2: Generating FNV1a digests using the static fnv1() method
        
        ---
        
            import ocean.io.digest.Fnv;
        
            char[] hello = "Hello World!";
            
            size_t hash   = Fnv1a(hello);
            uint   hash32 = Fnv1a32(hello);
            ulong  hash64 = Fnv1a64(hello);
        
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


class Fnv1Generic ( bool FNV1A = false, T = size_t ) : Digest
{
    public static const DIGEST_LENGTH = T.sizeof;
    
    /**************************************************************************
    
        FNV magic constants and endianness
 
     **************************************************************************/
    
    
    static if (is (T == uint))
    {
        public static const T FNV_PRIME = 0x0100_0193; // 32 bit prime
        public static const T FNV_INIT  = 0x811C_9DC5; // 32 bit inital digest
        
        private alias ByteSwap.swap32 toBigEnd;
    }
    else static if (is (T == ulong))
    {
        public static const T FNV_PRIME = 0x0000_0100_0000_01B3; // 64 bit prime
        public static const T FNV_INIT  = 0xCBF2_9CE4_8422_2325; // 64 bit inital digest
        
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
         typedef ubyte[DIGEST_LENGTH] BinString;
         
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
        return this.DIGEST_LENGTH;
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
    //public static T fnv1 ( U ) ( ubyte[] data, T hash = FNV_INIT )
    public static T fnv1 ( U ) ( U data, T hash = FNV_INIT )
    {
        ubyte[] data_;
        
        static if (is (U: void[]))
        {
            data_ = cast (ubyte[]) data;
        }
        else
        {
            data_ = cast (ubyte[]) [data];
        }
        
        foreach (d; data_)
        {
            hash = fnv1_core(d, hash);
        }
        
        return hash;
    }
    /*
    public static T fnv1 ( ubyte[] data, T hash = FNV_INIT )
    {
        return fnv1(cast (ubyte[]) data, hash);
    }
    */
    public alias fnv1 opCall;
    
    
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

alias Fnv1Generic!(false)         Fnv1;
alias Fnv1Generic!(false, uint)   Fnv132;
alias Fnv1Generic!(false, ulong)  Fnv164;
alias Fnv1Generic!(true)          Fnv1a;
alias Fnv1Generic!(true,  uint)   Fnv1a32;
alias Fnv1Generic!(true,  ulong)  Fnv1a64;


/**************************************************************************

    unit test


    Test data for FNV1/FNV1a hash algorithm
    
    Data taken from Landon Curt Noll's FNV test program source code:
        
        http://www.isthe.com/chongo/src/fnv/test_fnv.c
    
    found at his FNV web page:
    
        http://www.isthe.com/chongo/tech/comp/fnv/
    
   
    C to D port by David Eckardt, sociomantic labs, October 2009
    
    david_eckardt@sociomantic.com

**************************************************************************/

private char[] errmsg ( char[] func, char[] str, bool is_text )
{
    char[] errmsg = "unit test failed for " ~ func;
    
    if (is_text)
    {
        errmsg ~= ": \"" ~ str ~ "\"";
    }
    
    return errmsg;
}

unittest
{
    struct TestData
    {
        /*
         * 32-bit FNV1 digests of "string" below as integer, binary data string
         * and hexadecimal text string
         */ 
        uint    fnv1_32;
        ubyte[] fnv1_32_bin;
        char[]  fnv1_32_hex;
        
        /*
         * 32-bit FNV1a digests of "string" below as integer, binary data string
         * and hexadecimal text string
         */ 
        uint    fnv1a_32;
        ubyte[] fnv1a_32_bin;
        char[]  fnv1a_32_hex;
        
        /*
         * 64-bit FNV1 digests of "string" below as integer, binary data string
         * and hexadecimal text string
         */ 
        ulong   fnv1_64;
        ubyte[] fnv1_64_bin;
        char[]  fnv1_64_hex;

        /*
         * 64-bit FNV1a digests of "string" below as integer, binary data string
         * and hexadecimal text string
         */ 
        ulong   fnv1a_64;
        ubyte[] fnv1a_64_bin;
        char[]  fnv1a_64_hex;
        
        /*
         * is_text == true indicates that the content of "string" is safe to
         * write to a text output (text file, console...).
         */
        bool   is_text;
        
        // string of which the digests above are computed from
        char[] string;
    };
    
    const TestData[] testdata =
    [
        {0xc5f1d7e9, [0xc5, 0xf1, 0xd7, 0xe9], "c5f1d7e9", 0x512b2851, [0x51, 0x2b, 0x28, 0x51], "512b2851", 0x43c94e2c8b277509, [0x43, 0xc9, 0x4e, 0x2c, 0x8b, 0x27, 0x75, 0x09], "43c94e2c8b277509", 0x33b96c3cd65b5f71, [0x33, 0xb9, 0x6c, 0x3c, 0xd6, 0x5b, 0x5f, 0x71], "33b96c3cd65b5f71",  true, "391581216093391581216093391581216093391581216093391581216093391581216093391581216093391581216093391581216093391581216093"},
        {0x32c1f439, [0x32, 0xc1, 0xf4, 0x39], "32c1f439", 0x76823999, [0x76, 0x82, 0x39, 0x99], "76823999", 0x3cbfd4e4ea670359, [0x3c, 0xbf, 0xd4, 0xe4, 0xea, 0x67, 0x03, 0x59], "3cbfd4e4ea670359", 0xd845097780602bb9, [0xd8, 0x45, 0x09, 0x77, 0x80, 0x60, 0x2b, 0xb9], "d845097780602bb9",  true, "391581*2^216093-1391581*2^216093-1391581*2^216093-1391581*2^216093-1391581*2^216093-1391581*2^216093-1391581*2^216093-1391581*2^216093-1391581*2^216093-1391581*2^216093-1"},
        {0x7fd3eb7d, [0x7f, 0xd3, 0xeb, 0x7d], "7fd3eb7d", 0xc0586935, [0xc0, 0x58, 0x69, 0x35], "c0586935", 0xc05887810f4d019d, [0xc0, 0x58, 0x87, 0x81, 0x0f, 0x4d, 0x01, 0x9d], "c05887810f4d019d", 0x84d47645d02da3d5, [0x84, 0xd4, 0x76, 0x45, 0xd0, 0x2d, 0xa3, 0xd5], "84d47645d02da3d5", false, "\x05\xf9\x9d\x03\x4c\x81\x05\xf9\x9d\x03\x4c\x81\x05\xf9\x9d\x03\x4c\x81\x05\xf9\x9d\x03\x4c\x81\x05\xf9\x9d\x03\x4c\x81\x05\xf9\x9d\x03\x4c\x81\x05\xf9\x9d\x03\x4c\x81\x05\xf9\x9d\x03\x4c\x81\x05\xf9\x9d\x03\x4c\x81\x05\xf9\x9d\x03\x4c\x81"},
        {0x81597da5, [0x81, 0x59, 0x7d, 0xa5], "81597da5", 0xf3415c85, [0xf3, 0x41, 0x5c, 0x85], "f3415c85", 0x14468ff93ac22dc5, [0x14, 0x46, 0x8f, 0xf9, 0x3a, 0xc2, 0x2d, 0xc5], "14468ff93ac22dc5", 0x83544f33b58773a5, [0x83, 0x54, 0x4f, 0x33, 0xb5, 0x87, 0x73, 0xa5], "83544f33b58773a5", false, "FEDCBA9876543210FEDCBA9876543210FEDCBA9876543210FEDCBA9876543210FEDCBA9876543210FEDCBA9876543210FEDCBA9876543210FEDCBA9876543210FEDCBA9876543210FEDCBA9876543210"},
        {0x05eb7a25, [0x05, 0xeb, 0x7a, 0x25], "05eb7a25", 0x0ae4ff65, [0x0a, 0xe4, 0xff, 0x65], "0ae4ff65", 0xebed699589d99c05, [0xeb, 0xed, 0x69, 0x95, 0x89, 0xd9, 0x9c, 0x05], "ebed699589d99c05", 0x9175cbb2160836c5, [0x91, 0x75, 0xcb, 0xb2, 0x16, 0x08, 0x36, 0xc5], "9175cbb2160836c5", false, "\xfe\xdc\xba\x98\x76\x54\x32\x10\xfe\xdc\xba\x98\x76\x54\x32\x10\xfe\xdc\xba\x98\x76\x54\x32\x10\xfe\xdc\xba\x98\x76\x54\x32\x10\xfe\xdc\xba\x98\x76\x54\x32\x10\xfe\xdc\xba\x98\x76\x54\x32\x10\xfe\xdc\xba\x98\x76\x54\x32\x10\xfe\xdc\xba\x98\x76\x54\x32\x10\xfe\xdc\xba\x98\x76\x54\x32\x10\xfe\xdc\xba\x98\x76\x54\x32\x10"},
        {0x9c0fa1b5, [0x9c, 0x0f, 0xa1, 0xb5], "9c0fa1b5", 0x58b79725, [0x58, 0xb7, 0x97, 0x25], "58b79725", 0x6d99f6df321ca5d5, [0x6d, 0x99, 0xf6, 0xdf, 0x32, 0x1c, 0xa5, 0xd5], "6d99f6df321ca5d5", 0xc71b3bc175e72bc5, [0xc7, 0x1b, 0x3b, 0xc1, 0x75, 0xe7, 0x2b, 0xc5], "c71b3bc175e72bc5",  true, "EFCDAB8967452301EFCDAB8967452301EFCDAB8967452301EFCDAB8967452301EFCDAB8967452301EFCDAB8967452301EFCDAB8967452301EFCDAB8967452301EFCDAB8967452301EFCDAB8967452301"},
        {0x53ccb1c5, [0x53, 0xcc, 0xb1, 0xc5], "53ccb1c5", 0xdea43aa5, [0xde, 0xa4, 0x3a, 0xa5], "dea43aa5", 0x0cd410d08c36d625, [0x0c, 0xd4, 0x10, 0xd0, 0x8c, 0x36, 0xd6, 0x25], "0cd410d08c36d625", 0x636806ac222ec985, [0x63, 0x68, 0x06, 0xac, 0x22, 0x2e, 0xc9, 0x85], "636806ac222ec985", false, "\xef\xcd\xab\x89\x67\x45\x23\x01\xef\xcd\xab\x89\x67\x45\x23\x01\xef\xcd\xab\x89\x67\x45\x23\x01\xef\xcd\xab\x89\x67\x45\x23\x01\xef\xcd\xab\x89\x67\x45\x23\x01\xef\xcd\xab\x89\x67\x45\x23\x01\xef\xcd\xab\x89\x67\x45\x23\x01\xef\xcd\xab\x89\x67\x45\x23\x01\xef\xcd\xab\x89\x67\x45\x23\x01\xef\xcd\xab\x89\x67\x45\x23\x01"},
        {0xfabece15, [0xfa, 0xbe, 0xce, 0x15], "fabece15", 0x2bb3be35, [0x2b, 0xb3, 0xbe, 0x35], "2bb3be35", 0xef1b2a2c86831d35, [0xef, 0x1b, 0x2a, 0x2c, 0x86, 0x83, 0x1d, 0x35], "ef1b2a2c86831d35", 0xb6ef0e6950f52ed5, [0xb6, 0xef, 0x0e, 0x69, 0x50, 0xf5, 0x2e, 0xd5], "b6ef0e6950f52ed5",  true, "0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF"},
        {0x4ad745a5, [0x4a, 0xd7, 0x45, 0xa5], "4ad745a5", 0xea777a45, [0xea, 0x77, 0x7a, 0x45], "ea777a45", 0x3b349c4d69ee5f05, [0x3b, 0x34, 0x9c, 0x4d, 0x69, 0xee, 0x5f, 0x05], "3b349c4d69ee5f05", 0xead3d8a0f3dfdaa5, [0xea, 0xd3, 0xd8, 0xa0, 0xf3, 0xdf, 0xda, 0xa5], "ead3d8a0f3dfdaa5", false, "\x01\x23\x45\x67\x89\xab\xcd\xef\x01\x23\x45\x67\x89\xab\xcd\xef\x01\x23\x45\x67\x89\xab\xcd\xef\x01\x23\x45\x67\x89\xab\xcd\xef\x01\x23\x45\x67\x89\xab\xcd\xef\x01\x23\x45\x67\x89\xab\xcd\xef\x01\x23\x45\x67\x89\xab\xcd\xef\x01\x23\x45\x67\x89\xab\xcd\xef\x01\x23\x45\x67\x89\xab\xcd\xef\x01\x23\x45\x67\x89\xab\xcd\xef"},
        {0xe5bdc495, [0xe5, 0xbd, 0xc4, 0x95], "e5bdc495", 0x8f21c305, [0x8f, 0x21, 0xc3, 0x05], "8f21c305", 0x55248ce88f45f035, [0x55, 0x24, 0x8c, 0xe8, 0x8f, 0x45, 0xf0, 0x35], "55248ce88f45f035", 0x922908fe9a861ba5, [0x92, 0x29, 0x08, 0xfe, 0x9a, 0x86, 0x1b, 0xa5], "922908fe9a861ba5",  true, "1032547698BADCFE1032547698BADCFE1032547698BADCFE1032547698BADCFE1032547698BADCFE1032547698BADCFE1032547698BADCFE1032547698BADCFE1032547698BADCFE1032547698BADCFE"},
        {0x23b3c0a5, [0x23, 0xb3, 0xc0, 0xa5], "23b3c0a5", 0x5c9d0865, [0x5c, 0x9d, 0x08, 0x65], "5c9d0865", 0xaa69ca6a18a4c885, [0xaa, 0x69, 0xca, 0x6a, 0x18, 0xa4, 0xc8, 0x85], "aa69ca6a18a4c885", 0x6d4821de275fd5c5, [0x6d, 0x48, 0x21, 0xde, 0x27, 0x5f, 0xd5, 0xc5], "6d4821de275fd5c5", false, "\x10\x32\x54\x76\x98\xba\xdc\xfe\x10\x32\x54\x76\x98\xba\xdc\xfe\x10\x32\x54\x76\x98\xba\xdc\xfe\x10\x32\x54\x76\x98\xba\xdc\xfe\x10\x32\x54\x76\x98\xba\xdc\xfe\x10\x32\x54\x76\x98\xba\xdc\xfe\x10\x32\x54\x76\x98\xba\xdc\xfe\x10\x32\x54\x76\x98\xba\xdc\xfe\x10\x32\x54\x76\x98\xba\xdc\xfe\x10\x32\x54\x76\x98\xba\xdc\xfe"},
        {0xfa823dd5, [0xfa, 0x82, 0x3d, 0xd5], "fa823dd5", 0xfa823dd5, [0xfa, 0x82, 0x3d, 0xd5], "fa823dd5", 0x1fe3fce62bd816b5, [0x1f, 0xe3, 0xfc, 0xe6, 0x2b, 0xd8, 0x16, 0xb5], "1fe3fce62bd816b5", 0x1fe3fce62bd816b5, [0x1f, 0xe3, 0xfc, 0xe6, 0x2b, 0xd8, 0x16, 0xb5], "1fe3fce62bd816b5", false, "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"},
        {0x0c6c58b9, [0x0c, 0x6c, 0x58, 0xb9], "0c6c58b9", 0x21a27271, [0x21, 0xa2, 0x72, 0x71], "21a27271", 0x0289a488a8df69d9, [0x02, 0x89, 0xa4, 0x88, 0xa8, 0xdf, 0x69, 0xd9], "0289a488a8df69d9", 0xc23e9fccd6f70591, [0xc2, 0x3e, 0x9f, 0xcc, 0xd6, 0xf7, 0x05, 0x91], "c23e9fccd6f70591", false, "\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07\x07"},
        {0xe2dbccd5, [0xe2, 0xdb, 0xcc, 0xd5], "e2dbccd5", 0x83c5c6d5, [0x83, 0xc5, 0xc6, 0xd5], "83c5c6d5", 0x15e96e1613df98b5, [0x15, 0xe9, 0x6e, 0x16, 0x13, 0xdf, 0x98, 0xb5], "15e96e1613df98b5", 0xc1af12bdfe16b5b5, [0xc1, 0xaf, 0x12, 0xbd, 0xfe, 0x16, 0xb5, 0xb5], "c1af12bdfe16b5b5",  true, "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"},
        {0xdb7f50f9, [0xdb, 0x7f, 0x50, 0xf9], "db7f50f9", 0x813b0881, [0x81, 0x3b, 0x08, 0x81], "813b0881", 0xe6be57375ad89b99, [0xe6, 0xbe, 0x57, 0x37, 0x5a, 0xd8, 0x9b, 0x99], "e6be57375ad89b99", 0x39e9f18f2f85e221, [0x39, 0xe9, 0xf1, 0x8f, 0x2f, 0x85, 0xe2, 0x21], "39e9f18f2f85e221", false, "\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f"}
     ];
    
    scope Fnv132 fnv132 = new Fnv132;
    scope Fnv164 fnv164 = new Fnv164;
    
    scope Fnv1a32 fnv1a32 = new Fnv1a32;
    scope Fnv1a64 fnv1a64 = new Fnv1a64;
    
    foreach (tdat; testdata)
    {
        /**********************************************************************
         
             core methods test
         
         **********************************************************************/
        
        assert (Fnv132.fnv1(tdat.string) == tdat.fnv1_32, errmsg("Fnv132.fnv1", tdat.string, tdat.is_text));
        assert (Fnv164.fnv1(tdat.string) == tdat.fnv1_64, errmsg("Fnv164.fnv1", tdat.string, tdat.is_text));
        
        assert (Fnv1a32.fnv1(tdat.string) == tdat.fnv1a_32, errmsg("Fnv1a32.fnv1", tdat.string, tdat.is_text));
        assert (Fnv1a64.fnv1(tdat.string) == tdat.fnv1a_64, errmsg("Fnv1a64.fnv1", tdat.string, tdat.is_text));
        
        /**********************************************************************
        
            class methods test
    
         **********************************************************************/
       
        assert (fnv132.update(tdat.string).binaryDigest == tdat.fnv1_32_bin, errmsg("Fnv132.binaryDigest", tdat.string, tdat.is_text));
        assert (fnv164.update(tdat.string).binaryDigest == tdat.fnv1_64_bin, errmsg("Fnv164.binaryDigest", tdat.string, tdat.is_text));
        
        assert (fnv1a32.update(tdat.string).hexDigest == tdat.fnv1a_32_hex, errmsg("Fnv1a32.hexDigest", tdat.string, tdat.is_text));
        assert (fnv1a64.update(tdat.string).hexDigest == tdat.fnv1a_64_hex, errmsg("Fnv1a64.hexDigest", tdat.string, tdat.is_text));
    }
}
