/*******************************************************************************

        Uncompresses Content
        
        copyright:      Copyright (c) 2009 sociomantic labs. All rights reserved

        version:        Feb 2009: Initial release

        authors:        Thomas Nicolai, Lars Kirchhoff

        This module uncompresses content based on an input stream, buffer or 
        string. This module uses automatic detection of encoding type within
        the zlib library and returns a char[].
        
        --
        
        Compile Instructions:
        
        Please add buildflags=-L/usr/lib/libpcre.so to your dsss.conf
                
        --
        
        Usage:
        
        Simple usage:
        
        ---

            auto comp = new Uncompress();

            try 
            {
                auto content = comp.decode(gzip_content);
                Stdout(content).newline;
            }
            catch (Exception e)
            {
                Stdout("Error on Encoding");
            }
                
        ---
        
        If lots of data needs to be decompressed, please instantiate this class as 
        class property and call decode within the appropriate method. Additionally
        you can add the prefered encoding type if it is known. Otherwise ZlibStream 
        will try guess to guess the encoding. 
        
        ---
            
            auto    comp        = new Uncompress();
            char[]  encoding    = "gzip";
            
            try 
            {
                auto content = comp.decode(gzip_content, encoding);
                Stdout(content).newline;
            }
            catch (Exception e)
            {
                Stdout("Error on Encoding");
            }
            
        ---
         
        --        
        
        Related:
        
            http://www.zlib.net/
        
            Memory leak bugfix in decode functions:
            http://www.dsource.org/projects/tango/forums/topic/788 
       
            
            
********************************************************************************/

module ocean.compress.Uncompress;



/*******************************************************************************

            imports

********************************************************************************/

private     import      tango.io.device.Array;

private     import      tango.io.compress.ZlibStream;

private     import      tango.io.stream.Buffered;

private     import      tango.util.log.Trace;


/*******************************************************************************

    Uncompress

********************************************************************************/

class Uncompress
{
    const       uint                UNCOMPRESS_BUF_SIZE = 1024*1024;    // Initial Buffer size for uncompressed content
    const       uint                GROW_UB_SIZE        = 32*1024;      // Size that is used to allocate new memory in case of buffer grow
    const       uint                CHUNK_SIZE          = 4*1024;       // Chunk size for reading from ZlibStream  
    const       uint                INPUT_BUF_SIZE      = 64 * 1024;    // Initial input buffer size    
    const       uint                GROW_IB_SIZE        = 1024;         // Size of which the input buffer will grow 
    
    const       char[]              DEFAULT_ENCODING    = "auto";
    
    private     char[CHUNK_SIZE]    read_chunk;                         // Chunk that is used to read the uncompressed data from ZlibStream
    private     Array               input_buffer;                       // Input stream buffer used in case of a char[] input
    private     Array               output_buffer;                      // Output stream buffer that is used to store the uncompressed data
    
    private     ZlibInput           decomp;                             // global ZlibStream object
    private     ZlibInput.Encoding  encoding;                           // Store the encoding
    
        
    
    /*******************************************************************************

         Public Methods

     *******************************************************************************/
    
    /**
     * 
     * 
     */
    public this () {}
   
    
    /**
     * Returns uncompressed content. Output data is duplicated (copy on write).
     * 
     * Params:
     *      compressed  = compressed string
     *      output      = return buffer
     *      encoding    = encoding [zlib, gzip, deflate]
     */
    public void decodeUni ( T = char ) ( char[] compressed, out T[] output, char[] encoding = DEFAULT_ENCODING )
    {   
        int size = 0;        
        uint total = 0;
        
        output.length = 0;
        
        if (compressed.length > 0)
        {
            this.initInputBuffer;
            this.initOutputBuffer;
            
            this.input_buffer.append(compressed);
                        
            try 
            {
                this.setEncoding(encoding);                 
                this.initZlibStreamInput(this.input_buffer);
                
                while ((size = this.decomp.read(this.read_chunk)) > 0)
                {   
                    this.output_buffer.append(this.read_chunk);
                    total += size;
                }
                
                output = cast(T[]) this.output_buffer.slice(total).dup;
            }
            catch (Exception e)
            {
                UncompressException("Uncompress Error: " ~ e.msg);
            }
        }
    }
    
    
    
    /**
     * Uncompresses content. Output data is duplicated (copy on write).
     * 
     * Params:
     *      compressed  = compressed string
     *      output      = return buffer
     *      encoding    = encoding [zlib, gzip, deflate]
     */
    public void decode ( char[] compressed, out char[] output, char[] encoding = DEFAULT_ENCODING )
    {
        this.decodeUni(compressed, output, encoding);
    }
    
    
    
    /**
     * Uncompresses Stream
     *
     * Params:
     *     stream_in    = compressed input stream conduit
     *     stream_out   = uncompressed output stream conduit
     *     encoding     = encoding [zlib, gzip, deflate]
     *
     * Returns:
     *     number of uncompressed bytes, or 0 if none
     */
    public long decode ( InputStream stream_in, OutputStream stream_out, char[] encoding = DEFAULT_ENCODING )
    { 
        int size = 0;
        long written = 0;

        try 
        {
            this.setEncoding(encoding);
            this.initZlibStreamInput(stream_in);
            
            while ((size = this.decomp.read(this.read_chunk)) > 0)
            {
                written += size;
                stream_out.write(this.read_chunk[0 .. size]);
            }            
        }
        catch (Exception e)
        {
            UncompressException("Uncompress Error: " ~ e.msg);
        }
        
        return written;
    }
    
    
    
    /**
     * Uncompresses Buffered Input Stream. Uncompresses content. Output data is
     * duplicated (copy on write).
     * 
     * Params:
     *     stream_in    = compressed input buffer stream
     *     output       = return buffer
     *     encoding     = encoding [zlib, gzip, deflate]
     */    
    public void decodeUni ( T ) ( InputStream stream_in, out T[] output, char[] encoding = DEFAULT_ENCODING )
    {   
        int size = 0;
        uint total = 0;
        
        output.length = 0;
        
        try 
        {
            this.initOutputBuffer();
            
            this.setEncoding(encoding);
            this.initZlibStreamInput(stream_in);
            
            uint i = 0;
            
            while ((size = this.decomp.read(this.read_chunk)) > 0)
            {
                this.output_buffer.append(this.read_chunk);
                
                total += size;
            }           
            
            output.length = total;
            
            output = cast(T[]) this.output_buffer.slice(total).dup;
        }
        catch (Exception e)
        {
            UncompressException("Uncompress Error: " ~ e.msg);
        }
    }
    
    
    
    /**
     * Returns uncompressed content
     * 
     * Params:
     *      compressed  = compressed string
     *      output      = return buffer
     *      encoding    = encoding [zlib, gzip, deflate]
     */
    public void decode ( InputStream stream_in, out char[] output, char[] encoding = DEFAULT_ENCODING )
    {
        this.decodeUni(stream_in, output, encoding);
    }
    
    
    /**
     * Close the buffer
     *
     */
    public void close()
    {
        this.input_buffer.close();
        this.output_buffer.close();
    }
    
    
    
    /**
     * Initialize input buffer 
     *
     */
    private void initInputBuffer ()
    {   
        if (!this.input_buffer)
        {
            // Create input buffer for ZlibStream to consume
            this.input_buffer = new Array(INPUT_BUF_SIZE, GROW_IB_SIZE);
        }
        else 
        {
            this.input_buffer.clear(); // Clear input buffer       
        }
    }
    
    
    
    /**
     * Initialize output buffer 
     *
     */
    private void initOutputBuffer ()
    {   
        if (!this.output_buffer)
        {
            // Create input buffer for ZlibStream to consume
            this.output_buffer = new Array(UNCOMPRESS_BUF_SIZE, GROW_UB_SIZE);            
        }
        else 
        {
            this.output_buffer.clear(); // Clear input buffer
        }
    }
    
    
    
    /** 
     * Set decompression encoding  
     *  
     * Params:
     *     encoding = encoding string
     */
    private void setEncoding ( char[] encoding )
    {
        switch (encoding)
        {
            case "zlib":   
                this.encoding = ZlibInput.Encoding.Zlib;
                break;
            
            case "gzip":   
                this.encoding = ZlibInput.Encoding.Gzip;
                break;                
                
            case "deflate":                
                this.encoding = ZlibInput.Encoding.None;
                break;
                
            case this.DEFAULT_ENCODING: default:                 
                this.encoding = ZlibInput.Encoding.Guess;
        }
    }
    
    
    
    /**
     * Initialize ZlibStream input to read from a new input stream
     * 
     * Params:
     *     stream_in    = compressed input buffer stream
     */    
    private void initZlibStreamInput ( InputStream stream_in )
    {
        if (this.decomp)
        {   
            this.decomp.reset(stream_in, this.encoding);
        }
        else 
        {         
            this.decomp = new ZlibInput(stream_in, this.encoding);
        }
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