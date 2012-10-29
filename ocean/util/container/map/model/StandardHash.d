/*******************************************************************************

    copyright:      Copyright (c) 2012 sociomantic labs. All rights reserved

    version:        11/04/2012: Initial release

    authors:        David Eckardt, Gavin Norman
    
    Hash calculator used in Map and Set, uses FNV1a to hash primitive values and
    dynamic or static arrays of such.

*******************************************************************************/

module ocean.util.container.map.model.StandardHash;

struct StandardHash
{
    static:
    
    /**************************************************************************
        
        Evaluates to true if T is a primitive value type; that is, a numeric
        (integer, floating point, complex) or character type.
        
     **************************************************************************/
        
    template IsPrimitiveValueType ( T )
    {
        const IsPrimitiveValueType = is (T : real) || is (T : creal) || is (T : dchar);
    }
    
    /**************************************************************************
    
        Calculates the hash value from key.
        
        - If K is a primitive type (integer, floating point, character), the
          hash value is calculated from the raw key data using the FNV1a hash
          function.
        - If K is a dynamic or static array of a  primitive type, the hash value
          is calculated from the raw data of the key array content using the
          FNV1a hash function.
        - If K is a class, struct or union, it is expected to implement toHash(),
          which will be used.
        - Other key types (arrays of non-primitive types, classes/structs/unions
          which do not implement toHash(), pointers, function references,
          delegates, associative arrays) are not supported.
        
        Params:
            key = key to hash
            
        Returns:
            the hash value that corresponds to key.
    
     **************************************************************************/
    
    hash_t toHash ( K ) ( K key )
    {
        static if (StandardHash.IsPrimitiveValueType!(K))
        {
            return StandardHash.fnv1aT(key);
        }
        else static if (is (K E : E[]))
        {
            static assert (StandardHash.IsPrimitiveValueType!(E),
                           "only arrays of primitive value types supported, "
                           "not '" ~ K.stringof ~ '\'');
            
            return StandardHash.fnv1a(key);
        }
        else
        {
            static assert (is (K == class) || is (K == struct) || is (K == union),
                           "only primitive value types, arrays of such and "
                           "classes/structs/unions implementing toHash() "
                           "supported, not '" ~ K.stringof ~ '\'');
            
            return key.toHash();
        }
    }
    
    
    /**************************************************************************
        
        FNV1 magic constants.
        
     **************************************************************************/
    
    static if (is (hash_t == uint))
    {
        const hash_t fnv1a_prime = 0x0100_0193, // 32 bit fnv1a_prime
                     fnv1a_init  = 0x811C_9DC5; // 32 bit inital digest
    }
    else 
    {
        static assert (is (hash_t == ulong));
        
        const hash_t fnv1a_prime = 0x0000_0100_0000_01B3, // 32 bit fnv1a_prime
                     fnv1a_init  = 0xCBF2_9CE4_8422_2325; // 32 bit inital digest
    }
    
    /**************************************************************************
        
        Calculates the FNV1a hash value from data.
        
        Params:
            data = input data
            
        Returns:
            the FNV1a hash value calculated from data.
            
     **************************************************************************/
    
    hash_t fnv1a ( void[] data )
    {
        hash_t hash = this.fnv1a_init;
        
        foreach (d; cast (ubyte[]) data)
        {
            hash = (hash ^ d) * this.fnv1a_prime;
        }
        
        return hash; 
    }
    
    /**************************************************************************
        
        Calculates the FNV1a hash value from the raw data of x using an unrolled
        loop to improve efficiency.
        
        Note that, if T is a reference type, the hash value will be calculated
        from the reference, not the referenced value.
        
        Params:
            x = input value
            
        Returns:
            the FNV1a hash value calculated from the raw data of x.
            
     **************************************************************************/
    
    hash_t fnv1aT ( T ) ( T x )
    {
        mixin (fnv1aCode!("hash", x.stringof, T.sizeof));
        
        return hash;
    }
    
    /**************************************************************************
        
        Evaluates to D code that implements the calculation of FNV1a of a
        variable named var with n bytes of size, storing the result in a
        variable named hashvar.
        
        Example: Let x be an int variable to calculate the hash value from and
            result be the result variable:
            ---
                int x;
            ---
            
            Then
            
            ---
                fnv1aCode!("result", x.stringof, x.sizeof)
            ---
            
            , where x.sizeof is 4, evaluates to
            
            ---
                auto result = 14695981039346656037LU,
                     __x    = cast(ubyte*)&x;
                
                result = (result ^ __x[0LU]) * 1099511628211LU;
                result = (result ^ __x[1LU]) * 1099511628211LU;
                result = (result ^ __x[2LU]) * 1099511628211LU;
                result = (result ^ __x[3LU]) * 1099511628211LU;
            ---
            
     **************************************************************************/
    
    template fnv1aCode ( char[] hashvar, char[] var, size_t n )
    {
        static if (n)
        {
            const fnv1aCode = fnv1aCode!(hashvar, var, n - 1) ~ hashvar ~ "=(" ~
                              hashvar ~ "^__" ~ var ~ "[" ~
                              minus1!(n).stringof ~ "])*" ~
                              fnv1a_prime.stringof ~ ";\n";
        }
        else
        {
            const char[] fnv1aCode = "auto " ~ hashvar ~ "=" ~
                                     fnv1a_init.stringof ~ ",__" ~ var ~
                                     "=cast(" ~ ubyte.stringof ~ "*)&" ~ var ~
                                     ";\n";
        }
    }
    
    
    /**************************************************************************
        
        Evaluates to n - 1.
            
     **************************************************************************/
    
    template minus1 ( size_t n )
    {
        const size_t minus1 = n - 1;
    }
}