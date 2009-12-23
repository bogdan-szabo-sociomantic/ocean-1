/*******************************************************************************

        Uncompresses gzip compressed content
        
        copyright:      Copyright (c) 2009 sociomantic labs. All rights reserved

        version:        Dec 2009: Initial release

        authors:        David Eckardt

        This module detects whether data in a buffer is gzip compressed and
        uncompresses it using the Uncompress class in this package.
        The Gzip class can handle uncompressed data as well as compressed.
        Uncompression can explicitely be enabled (forced) or disabled; in this
        case the compression auto-detection is disabled.
        
        
        --
        
        Compile Instructions:
        
        Please add buildflags=-L/usr/lib/libpcre.so to your dsss.conf
                
        --
        
        Usage:
        
        ---

            char[] input, output;
            
            auto gzip = new Gzip;
            
            // ... fill input with potentially compressed data ...
            
            gzip.unzip(input, output);                     // uncompress with auto detection
            
            bool z = gzip.wasGzip();                       // b == true => input was compressed
                                                           // and has been uncompressed
            gzip.unzip(input, output, gzip.Mode.Enabled);  // simply uncompress
            gzip.unzip(input, output, gzip.Mode.Disabled); // copy input to output
            
        ---
        
            
********************************************************************************/

module ocean.compress.Gzip;

private import ocean.compress.Uncompress;

private import tango.math.Math: min;

/******************************************************************************

    Gzip class

 *******************************************************************************/

class Gzip: Uncompress
{
    
    /************************************************************************
       
        Constants
        
     ************************************************************************/
    
    public enum Mode {Disabled = 0, Enabled, Auto, Default};
    
    public static const ubyte[] GZIP_SIGNATURE = [0x1F, 0x8B];
    
    
    /************************************************************************
    
        Properties

     ************************************************************************/
    
    
    public  Mode mode = Mode.Auto;
    
    private bool was_gzip = false;
    
    
    /************************************************************************
    
        Methods
    
     ************************************************************************/
    
    
    /**
     * Constructor.
     * 
     * Params:
     *     mode = mode class property value
     */
    this ( Mode mode = Mode.Auto )
    {
        this.mode = mode;
    }

    
    /**
     * Decodes content in-place according mode option.
     * 
     * Params:
     *      content = data to decode
     *      mode = enable/disable/auto-detect decoding
     *      
     * Returns:
     *      true if content was decoded or false if content is unchanged
     */
    public T[] unzip ( T = char ) ( char[] content_in, out T[] content_out,
                                    Mode mode = Mode.Default )
    {
        if (mode == Mode.Default)
        {
            mode = this.mode;
        }
        
        this.was_gzip = this.isGzip(content_in, mode);
        
        if (this.was_gzip)
        {
            super.decodeUni!(T)(content_in, content_out);
        }
        else
        {
            content_out = content_in.dup;
        }
        
        return content_out;
    }
    
    
    public alias unzip opCall;
    
    
    /**
     * Tells whether the content was gzip decoded at the last call of unzip().
     * 
     * Returns:
     *      true if content was decoded or false if content remained unchanged
     */
    public bool wasGzip ( )
    {
        return this.was_gzip;
    }
    
    
    /**
     * Determines if "content" (most likely) contains gzipped data by
     * comparing the first two bytes against the gzip signature.
     * 
     * Params:
     *      content = content to examine
     *      
     * Returns:
     *      true if content data appear to be gzipped
     */
    public static bool detectGzip ( void[] content )
    {
        ubyte[] sign = (cast (ubyte[]) content)[0 .. min(2, content.length)];
        
        return (sign == this.GZIP_SIGNATURE);
    }
    
    
    
    /**
     * If "mode" is Auto, checks whether the content of "input" is gzip
     * compressed by comparing the first two bytes against the gzip signature.
     * If "mode" is Enabled or Disabled, no checking is done.
     * 
     * Params:
     *      input   = data to check
     *      mode = Auto: check, Enabled: assume compressed, Disabled: assume
     *                not compressed
     * 
     * Returns:
     *      the result of detection if <mode> is Auto, true if <mode> is
     *      Enabled and false if <mode> is Disabled
     */
    public static bool isGzip ( void[] input, Mode mode )
    {
        switch (mode)
        {
            case Mode.Disabled:
                return false;
            
            case Mode.Enabled:
                return true;
                
            case Mode.Auto: default:
                return detectGzip(input);
        }
    }
    
    
    
    /**
     * If the mode property is Auto, checks whether the content of
     * "input" is gzip compressed by comparing the first two bytes against the
     * gzip signature.
     * If the mode property  is Enabled or Disabled, no checking is
     * done.
     * 
     * Params:
     *      input   = data to check
     * 
     * Returns:
     *      the result of detection if the mode property is Auto,
     *      true if mode is Enabled and false if mode is Disabled
     */
    public bool isGzip ( void[] input )
    {
        return this.isGzip(input, this.mode);
    }
}


/******************************************************************************

    UncompressException

*******************************************************************************/

class UncompressException : Exception
{
    this ( char[] msg )
    {
        super(msg);
    }
    
    private static void opCall ( char[] msg ) 
    { 
        throw new UncompressException(msg); 
    }
}