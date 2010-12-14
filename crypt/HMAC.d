/*******************************************************************************

    Provides a HMAC implementation

    copyright:      Copyright (C) dcrypt contributors 2008. All rights reserved.

    version:        Jan 2010: Initial release
    
    License:   	    MIT

    authors:        Thomas Dixon, Mathias L. Baumann    
    
*******************************************************************************/

module ocean.crypt.HMAC;



/*******************************************************************************

	Imports

*******************************************************************************/

import ocean.core.Exception;

import ocean.crypt.misc.ByteConverter;

import ocean.crypt.misc.Bitwise;

import tango.io.digest.MerkleDamgard;

debug (OceanUnitTest)
{
    import tango.io.digest.Sha1;
    import tango.util.log.Trace;
}

/*******************************************************************************

	Implementation of Keyed-Hash Message Authentication Code (HMAC)
 
	Conforms: RFC 2104 
 	References: http://www.faqs.org/rfcs/rfc2104.html
  
*******************************************************************************/

class HMAC 
{
    private
    {
        ubyte[] ipad, opad, key;
        MerkleDamgard hash;
        bool initialized;
    }
    
    
    /**************************************************************************
    
    	Constructor. Creates a new instance of an HMAC object
    	
    	Params:
    		hash = the hash algorithm to use (i.E. new Sha1(); )
    		key = the key to initialize with
        
     **************************************************************************/

    this (MerkleDamgard hash, void[] key=null)
    {
        this.hash = hash;
        this.hash.reset();
        
        ipad = new ubyte[blockSize];
        opad = new ubyte[blockSize];
        
        if (key)
            init(cast(ubyte[])key); // I'm lazy.
    }
    
    version (D_Version2)
    {
        this (Hash hash, char[] key)
        {
            this(hash, cast(ubyte[])key);
        }
    }
    
    
    /**************************************************************************
    
	    Initializes the HMAC object
	    
	    Params:
	    	k = the key to initialize from
	    
	**************************************************************************/
    
    void init(ubyte[] k)
    {
        hash.reset();
        
        if (k.length > blockSize)
        {
            hash.update(k);
            key = hash.binaryDigest();
        } else
            key = k;
        
        ipad[] = 0x36;
        opad[] = 0x5c;
        
        foreach (uint i, ubyte j; key)
        {
            ipad[i] ^= j;
            opad[i] ^= j;
        }
        
        reset();
        
        initialized = true;
    }
    
    
    /**************************************************************************
    
	    Add more data to process
	    
	    Params:
	    	input_ = the data
	    	
	**************************************************************************/
    
    void update(void[] input_)
    {
        if (!initialized)
            throw new HMACException(name()~": MAC not initialized.");
            
        hash.update(input_);
    }
    
    
    /**************************************************************************
    
	    Returns the name of the algorithm 
	    
	    Returns:
	        Returns the name of the algorithm
	    
	**************************************************************************/

    char[] name()
    {
        return "HMAC-"~hash.toString;
    }

    
    /**************************************************************************
    
	    Resets the state 
	    
	**************************************************************************/

    void reset()
    {    
        hash.reset();
        hash.update(ipad);
    }
    
    
    /**************************************************************************
	    
	    Returns the blocksize 
	    
	**************************************************************************/
    
    uint blockSize()
    {
        return hash.blockSize;
    }

    
    /**************************************************************************
    
	    Returns the size in bytes of the digest 
	    
	**************************************************************************/
    
    uint macSize()
    {
        return hash.digestSize;
    }
    

    /**************************************************************************
    
	    Computes the digest and returns it 
	    
	**************************************************************************/
    
    ubyte[] digest()
    {
        ubyte[] t = hash.binaryDigest();
        hash.update(opad);
        hash.update(t);
        ubyte[] r = hash.binaryDigest();
        
        reset();
        
        return r;
    }
    
    
    /**************************************************************************
    
	    Computes the digest and returns it as hex 
	    
	**************************************************************************/
    
    char[] hexDigest()
    {
        return ByteConverter.hexEncode(digest());
    }    
  
    /*******************************************************************************

    	UnitTest

     *******************************************************************************/
    
    debug (OceanUnitTest)
    {  
    	
        unittest
        {
            static char[][] test_keys = [
                "0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b",
                "4a656665", // Jefe?
                "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
                "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"~
                "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"~
                "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"~
                "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
            ];
            
            static char[][] test_inputs = [
                "4869205468657265",
                "7768617420646f2079612077616e7420666f72206e6f7468696e673f",
                "dd",
                "54657374205573696e67204c6172676572205468616e20426c6f63"~
                "6b2d53697a65204b6579202d2048617368204b6579204669727374"
            ];
            
            static int[] test_repeat = [
                1, 1, 50, 1
            ];
            
            static char[][] test_results = [
                "b617318655057264e28bc0b6fb378c8ef146be00",
                "effcdf6ae5eb2fa2d27416d5f184df9c259a7c79",
                "125d7342b9ac11cd91a39af48aa17b4f63f175d3",
                "aa4ae5e15272d00e95705637ce8a3b55ed402112"
            ];
            
            Trace.format("Running unittest HMAC");
            
            HMAC h = new HMAC(new Sha1());
            foreach (uint i, char[] k; test_keys)
            {
                h.init(ByteConverter.hexDecode(k));
                for (int j = 0; j < test_repeat[i]; j++)
                    h.update(ByteConverter.hexDecode(test_inputs[i]));
                char[] mac = h.hexDigest();
                assert(mac == test_results[i], 
                        h.name~": ("~mac~") != ("~test_results[i]~")");
            }
            
            Trace.format(" .. success\n");
        }
    }
}
