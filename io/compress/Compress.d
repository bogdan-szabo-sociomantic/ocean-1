/******************************************************************************

        Compresses/uncompresses data from stream or buffer to stream or buffer
        
        copyright:      Copyright (c) 2009 sociomantic labs. All rights reserved

        version:        Feb 2009: Initial release

        authors:        Thomas Nicolai, Lars Kirchhoff and David Eckardt

        This module uses the zlib to compress (encodes) and uncompress (decodes)
        content based on a stream, buffer or string, supporting zlib and gzip
        encoding of compressed data as well as non-encoded compressed data. For
        uncompression, encoding auto-detection is provided as an option.
        
        If compressed data are taken from/put to a buffer, the base type of the
        array representing this buffer must be a single byte data type as char,
        byte or ubyte, or void. 
        
        --
        
        Build Instructions:
        Code using this module must be linked against the libz which is 
        contained in 'libz.a' (static library) or 'libz.so' (Linux shared
        library). For DMD and GDC compiler, given that the Linux shared library
        which is located in the /usr/lib/ directory should be used, add
        
        ---
        
        -L/usr/lib/libz.so
        
        ---
        
        to the command line when compiling or linking. When using DSSS, this
        line in the dsss.conf has the same effect:
        
        ---
        
        buildflags = -L/usr/lib/libz.so
       
        ---
        
        --
        
        Usage examples:
        
        Decode (uncompress) content from a buffer and put uncompressed data into
        a char buffer using encoding auto-detection:
        
        ---

            import $(TITLE);
            
            auto comp = new Compress;
            
            ubyte[] compressed;
            
            char[] content;
            
            // fill "compressed" with gzip or zlib encoded compressed data
            
            // if we certainly knew compressed data are zlib or gzip encoded, we
            // could add
            //
            //      comp.setDecoding(Compress.Decoding.Zlib);
            //
            // or, respectively,
            //
            //      comp.setDecoding(Compress.Decoding.Gzip);
            //
            
            comp.decode(compressed, content);
            
            // "content" now contains decoded data
            
        ---
        
        Encode (compress) content from a char buffer and put compressed data to
        a stream which is a file in this example, using gzip encoding with
        fastest compression level.
        
        ---
            
            import $(TITLE);
            import tango.io.device.File;
            
            auto comp = new Compress;
            auto file = new File;
            
            char[] content;
            
            // fill "content" with data to compress
            
            file.open("mycontent.gz", File.WriteCreate);
            
            scope (exit) file.close();
            
            comp.setEncoding(comp.Encoding.Gzip);
            comp.setLevel(comp.Level.Fast);
            
            comp.encode(content, file);
            
        ---
         
        --        
        
        Related:
        
            http://www.zlib.net/
        
            Memory leak bugfix in decode functions:
            http://www.dsource.org/projects/tango/forums/topic/788 
       
            
            
 ******************************************************************************/

module ocean.compress.Compress;



/******************************************************************************

            imports

 ******************************************************************************/

public      import      ocean.core.Exception: CompressException;

private     import      tango.io.compress.ZlibStream: ZlibInput, ZlibOutput;

private     import      tango.io.device.Array;

private     import      tango.io.model.IConduit: InputStream, OutputStream;

private     import      Integer = tango.text.convert.Integer: toInt;

private     import      tango.math.Math: min;


/******************************************************************************

    Compress

 ******************************************************************************/

class Compress
{
    /**************************************************************************

        Compression/uncompression encoding enumeration aliases
        
        Encoding: compression encoding; denominates whether output data should
                  be encoded as Gzip or Zlib or not encoded at all.
        
        Decoding: uncompression encoding; denominates whether input data are
                  expected to be Gzip or Zlib or not encoded at all or encoding
                  should be detected.
        
         
        
     **************************************************************************/
    
    public alias ZlibOutput.Encoding Encoding;
    public alias ZlibInput.Encoding  Decoding;
    public alias ZlibOutput.Level    Level;
    
    /**************************************************************************

        Encoding/Decoding properties
        
     **************************************************************************/

    private     Encoding encoding                       = Encoding.Zlib; // Store the encoding
    private     Decoding decoding                       = Decoding.Guess; // Store the encoding
    private     ZlibOutput.Level     level              = ZlibOutput.Level.Normal;
    
    /**************************************************************************

        Buffer size constants
        
     **************************************************************************/

    static struct BufferSize
    {
        static const                    CHUNK           = 0x1000,      // Chunk size for ZlibStream access
                                        INPUT_INIT      = 0x1_0000,    // Initial input buffer size    
                                        INPUT_GROW      = 0x400,       // Size of which the input buffer will grow
                                        OUTPUT_INIT     = 0x10_0000,   // Initial output buffer size
                                        OUTPUT_GROW     = 0x8000;      // Size of which the output buffer will grow 
    }
    /**************************************************************************

        I/O buffers
        
     **************************************************************************/

    private     ubyte[BufferSize.CHUNK] chunk;                              // Chunk that is used to read the uncompressed data from ZlibStream
    private     Array                   input_buffer;                       // Input stream buffer used in case of a char[] input
    private     Array                   output_buffer;                      // Output stream buffer that is used to store the uncompressed data
    
    /**************************************************************************

        Zlib I/O filters
        
     **************************************************************************/

    private     ZlibInput               decomp;                             // global ZlibStream object
    private     ZlibOutput              comp;                               // global ZlibStream object
    
    /**************************************************************************

        Compression/decompression parameter codes
        
     **************************************************************************/
    
    static const struct Codes
    {
        static const    ENCODING =
                        [
                                     Encoding.Zlib,
                                     Encoding.None,
                                     Encoding.Gzip
                        ],
        
                        DECODING =
                        [
                                   Decoding.Guess,
                                   Decoding.None,
                                   Decoding.Gzip,
                                   Decoding.Zlib
                        ],
        
                        LEVEL =
                        [
                                    Level.Normal,
                                    Level.None,
                                    Level.Fast,
                                    Level.Best
                        ];
    }
    
    /**************************************************************************

        Compression/decompression parameter identifier strings
    
     **************************************************************************/

    static const struct Ids
    {
        static const char[][] FALSE = ["false", "off", "no",  "disabled"];
        static const char[][] TRUE  = ["true",  "on",  "yes", "enabled"];
        
        static const char[][][] ENCODING =
        [
            ["zlib"],
            ["none"] ~ this.FALSE,
            ["gzip"]
        ];
        
        static const char[][][] DECODING =
        [
            ["guess"] ~ this.TRUE,
            ["none"]  ~ this.FALSE,
            ["gzip"],
            ["zlib"]
        ];
            
        static const char[][][] LEVEL =
        [
            ["normal"] ~ this.TRUE,
            ["none"]   ~ this.FALSE,
            ["fast", "min"],
            ["best", "max"]
        ];
    }
    
    /*******************************************************************************

         Public Methods

     *******************************************************************************/
    
    /**************************************************************************
     
          Constructor 
     
     **************************************************************************/
    
    public this () {}
   
    /**************************************************************************
    
        Compresses Stream
         
        Params:
            stream_in    = uncompressed input stream conduit
            stream_out   = compressed output stream conduit
         
        Returns:
            number of input bytes, or 0 if none
    
     **************************************************************************/
    
    //  Template with 'T = void' is to avoid collisions of overloaded method.
    
    public size_t encode ( T = void ) ( InputStream stream_in, OutputStream stream_out )
    {
        try 
        {
            size_t total = 0;
            size_t size  = 0;
            size_t s;
            
            scope (success) this.comp.commit();
            
            this.initZlibStreamOutput(stream_out);
            
            s = stream_in.read(this.chunk);
            
            while (s != stream_in.Eof)
            {
                size = s;
                total += size;
                
                this.comp.write(this.chunk[0 .. size]);
                
                s = stream_in.read(this.chunk);
            }
            
            return total;
        }
        catch (Exception e)
        {
            CompressException("Compress Error: " ~ e.msg);
        }
    }
    
    /**************************************************************************
    
        Compresses Buffered Input Stream.
        
        Params:
            stream_in    = uncompressed input stream conduit
            buffer_out   = return buffer
            
     **************************************************************************/
    
    public size_t encode ( T ) ( InputStream stream_in, out T[] buffer_out )
    {
        cast (void) this.assertByteType!(T, ".encode()", "buffer_out");
        
        scope (success) this.sliceOutputBuffer(buffer_out);
        
        return this.encode(stream_in, this.initOutputBuffer());
    }
    
    
    /**************************************************************************
    
        Compresses Buffered Input Stream.
        
        Params:
            buffer_in  = data to compress
            stream_out = compressed output stream conduit
            
     **************************************************************************/
    
    public size_t encode ( S ) ( S[] buffer_in, OutputStream stream_out )
    {
        cast (void) this.assertByteType!(S, ".encode()", "buffer_out");
        
        return this.encode(this.initInputBuffer().append(buffer_in), stream_out);
    }
    
    
    /**************************************************************************
    
        Compresses content.
        
        Params:
             buffer_in  = data to compress
             buffer_out = return buffer
             
     **************************************************************************/
    
    
    public size_t encode ( S, T ) ( S[] buffer_in, out T[] buffer_out )
    {   
        cast (void) this.assertByteType!(S, ".encode()", "buffer_in");
        
        return this.encode(this.initInputBuffer().append(buffer_in), buffer_out);
    }
    
    /**************************************************************************
    
        Uncompresses Stream
        
        Params:
            stream_in    = compressed input stream conduit
            stream_out   = uncompressed output stream conduit
        
        Returns:
            number of output bytes, or 0 if none
    
     **************************************************************************/
    
    // Template with 'T = void' is to avoid collisions of overloaded method.
    
    public size_t decode ( T = void ) ( InputStream stream_in, OutputStream stream_out )
    {
        try
        {
            bool do_decode = true;
            
            size_t total = 0;
            size_t size  = 0;
            size_t s = this.initZlibStreamInput(stream_in).read(this.chunk);
            
            while (s != stream_in.Eof)
            {
                size = s;
                total += size;
                
                stream_out.write(this.chunk[0 .. size]);
                
                s = this.decomp.read(this.chunk);
            }
            
            return total;
        }
        catch (Exception e)
        {
            CompressException("Uncompress Error: " ~ e.msg);
        }
    }

    /**************************************************************************
    
        Uncompresses Buffered Input Stream.
        
        Params:
            stream_in    = compressed input buffer stream
            buffer_out   = return buffer
            
        Returns:
            number of output bytes, or 0 if none
            
     **************************************************************************/
    
    public size_t decode ( T ) ( InputStream stream_in, out T[] buffer_out )
    {
        cast (void) this.assertByteType!(T, ".decode()", "buffer_out");
        
        scope (success) this.sliceOutputBuffer(buffer_out);
        
        return this.decode(stream_in, this.initOutputBuffer());
    }
    
    
    /**************************************************************************
    
        Uncompresses content.
        
        Params:
            buffer_in  = compressed data
            stream_out = uncompressed output stream conduit

        Returns:
            number of output bytes, or 0 if none
            
    **************************************************************************/
    
    public size_t decode ( S ) ( S[] buffer_in, OutputStream stream_out )
    {
        cast (void) this.assertByteType!(S, ".decode()", "buffer_in");
        
        return this.decode(this.initInputBuffer().append(buffer_in), stream_out);
    }
    
    
    /**************************************************************************
    
        Uncompresses content.
        
        Params:
             buffer_in  = compressed data
             buffer_out = return buffer
             
        Returns:
            number of uncompressed bytes, or 0 if none
             
     **************************************************************************/


    public size_t decode ( S, T ) ( S[] buffer_in, out T[] buffer_out )
    {   
        cast (void) this.assertByteType!(S, ".decode()", "buffer_in");
        
        return this.decode(this.initInputBuffer().append(buffer_in), buffer_out);
    }
    
    /+
    /**************************************************************************
    
        Uncompresses data.
        
        Params:
             buffer_in  = compressed data
             buffer_out = return buffer
             encoding   = encoding [auto, zlib, gzip, none]
             
        Returns:
            number of uncompressed bytes, or 0 if none
             
     **************************************************************************/


    public size_t decode ( S, T ) ( S[] buffer_in, out T[] buffer_out, char[] encoding )
    {
        return this.setEncoding(encoding).decode(buffer_in, buffer_out);
    }
    
    /**************************************************************************
    
        Uncompresses Stream
         
        Params:
            stream_in    = compressed input stream conduit
            stream_out   = uncompressed output stream conduit
            encoding     = encoding [auto, zlib, gzip, deflate]
         
        Returns:
            number of uncompressed bytes, or 0 if none
    
     **************************************************************************/

    // Template with 'T = void' is to avoid collisions of overloaded method.
    
    public size_t decode ( T = void ) ( InputStream stream_in, OutputStream stream_out, char[] encoding )
    {
        return this.setEncoding(encoding).decode(stream_in, stream_out);
    }
    
    /**************************************************************************
    
        Uncompresses Buffered Input Stream. Uncompresses content. Output data
        is duplicated (copy on write).
        
        Params:
            stream_in    = compressed input buffer stream
            output       = return buffer
            encoding     = encoding [auto, zlib, gzip, none]
            
        Returns:
            number of uncompressed bytes, or 0 if none
            
    **************************************************************************/


    
    public size_t decode ( T ) ( InputStream stream_in, out T[] output, char[] encoding )
    {
        return this.setEncoding(encoding).decode(stream_in, output);
    }
    +/
    
    
    /**************************************************************************
     
         Close the buffer
     
     **************************************************************************/
    
    public void close ( )
    {
        this.input_buffer.close();
        this.output_buffer.close();
    }
    
    
    /**************************************************************************
      
          Set compression encoding.
          If an invalid code is supplied, and accept_invalid is
               - true, the encoding is set to the default value as defined in
                       DEFAULT_ENCODING;
               - false, an exception is thrown.
       
          Params:
              code           = encoding identifier string
              accept_invalid = Set to true to set to default encoding on invalid
                               code or to false to throw an exception in this
                               case.
              
          Returns:
              this instance
          
     **************************************************************************/
    
    public typeof (this) setEncoding ( Encoding code, bool accept_invalid = false )
    {
        this.encoding = this.validateCode(code, this.Codes.ENCODING, accept_invalid);
        
        return this;
    }
    
    
    /**************************************************************************
    
        Set compression encoding.  An empty id string corresponds to the default 
        compression encoding.
        
        If an unknown identifier string is supplied, and accept_unknown is
             - true, the encoding is set to the default value;
             - false, an exception is thrown.
     
        Params:
            id             = encoding identifier string
            accept_unknown = Set to true to set to default encoding on unknown
                             identifier string or to false to throw an exception
                             in this case.
            
        Returns:
            this instance
        
    **************************************************************************/
    
    public typeof (this) setEncoding ( char[] id = "", bool accept_unknown = false )
    {
        this.encoding = this.getEncodingFromId(id, accept_unknown);
        
        return this;
    }
    

    /**************************************************************************
    
        Get compression encoding code from identifier string.  An empty id
        string corresponds to the default compression encoding. 
        
        If an unknown identifier string is supplied, and accept_unknown is
             - true, the encoding is set to the default value;
             - false, an exception is thrown.
     
        Params:
            id             = encoding identifier string
            accept_unknown = Set to true to set to default encoding on unknown
                             identifier string or to false to throw an exception
                             in this case.
            
        Returns:
            compression encoding code
        
    **************************************************************************/
    
    public static Encoding getEncodingFromId ( char[] id = "", bool accept_unknown = false )
    {
        return getCodeFromId(id, this.Codes.ENCODING, this.Ids.ENCODING, accept_unknown);
    }

    /**************************************************************************
      
          Set decompression encoding.
          If an invalid code is supplied, and accept_invalid is
               - true, the encoding is set to the default value;
               - false, an exception is thrown.
       
          Params:
              code           = encoding identifier string
              accept_invalid = Set to true to set to default encoding on invalid
                               code or to false to throw an exception in this
                               case.
              
          Returns:
              this instance
          
     **************************************************************************/
    
    public typeof (this) setDecoding ( Decoding code, bool accept_invalid = false )
    {
        this.decoding = this.validateCode(code, this.Codes.DECODING, accept_invalid);
        
        return this;
    }
    
    
    /**************************************************************************
    
        Set decompression encoding. An empty id string corresponds to the
        default decompression encoding.
        
        If an unknown identifier string is supplied, and accept_unknown is
             - true, the encoding is set to the default value;
             - false, an exception is thrown.
     
        Params:
            id             = encoding identifier string
            accept_unknown = Set to true to set to default encoding on unknown
                             identifier string or to false to throw an exception
                             in this case.
            
        Returns:
            this instance
        
     **************************************************************************/
    
    public typeof (this) setDecoding ( char[] id = "", bool accept_unknown = false )
    {
        this.decoding = this.getDecodingFromId(id, accept_unknown);
        
        return this;
    }

    /**************************************************************************
    
        Get decompression encoding code from identifier string. An empty id
        string corresponds to the default decompression encoding. 
        
        If an unknown identifier string is supplied, and accept_unknown is
             - true, the encoding is set to the default value;
             - false, an exception is thrown.
     
        Params:
            id             = encoding identifier string
            accept_unknown = Set to true to set to default encoding on unknown
                             identifier string or to false to throw an exception
                             in this case.
            
        Returns:
            decompression encoding code
        
     **************************************************************************/
    
    
    public static Decoding getDecodingFromId ( char[] id = "", bool accept_unknown = false )
    {
        return getCodeFromId(id, this.Codes.DECODING, this.Ids.DECODING, accept_unknown);
    }

    /**************************************************************************
    
        Set compression level.
        
        The compression level may be an integer value from -1 to 9 where -1
        denotes the default compression level, 0 no, 1 lowest/fastest and 9
        highest/slowest compression.
        
        If an invalid code is supplied, and accept_unknown is
             - true, the compression level is set to the default level;
             - false, an exception is thrown.
        
        Params:
            code           = compression level code
            accept_unknown = Set to true to set to default compression level
                             on unknown identifier string or to false to throw
                             an exception in this case.
            
        Returns:
            this instance
        
    **************************************************************************/
    
    public typeof (this) setLevel ( int code, bool accept_unknown = false )
    {
        this.level = this.validateLevel(code, accept_unknown);
        
        return this;
    }
    
    

    /**************************************************************************
    
        Set compression level. An empty id string
        corresponds to the default level.
        
        The compression level may be an integer value from -1 to 9 where -1
        denotes the default compression level, 0 no, 1 lowest/fastest and 9
        highest/slowest compression.
        
        If an invalid code is supplied, and accept_unknown is
             - true, the compression level is set to the default level;
             - false, an exception is thrown.
        
        Params:
            code           = compression level code
            accept_unknown = Set to true to set to default compression level
                             on unknown identifier string or to false to throw
                             an exception in this case.
            
        Returns:
            this instance
        
    **************************************************************************/
    
    public typeof (this) setLevel ( char[] id = "", bool accept_unknown = false )
    {
        this.level = this.getLevelFromId(id, accept_unknown);
        
        return this;
    }
    
    /**************************************************************************
    
        Get compression level code from identifier string. An empty id string
        corresponds to the default level.
        
        The compression level identifier string may be a string containing the
        decimal representation of an integer value from -1 to 9 where -1 denotes
        the default compression level, 0 no, 1 lowest/fastest and 9
        highest/slowest compression.
        
        If an unknown identifier string is supplied, and accept_unknown is
             - true, the encoding is set to the default value as defined in
                     DEFAULT_ENCODING;
             - false, an exception is thrown.
     
        Params:
            id             = compression level identifier string
            accept_unknown = Set to true to set to default compression level
                             on unknown identifier string or to false to throw
                             an exception in this case.
            
        Returns:
            compression level code
        
    **************************************************************************/
    
    public static Level getLevelFromId ( char[] id = "", bool accept_unknown = false )
    {
        bool is_of_enum = true;
        
        Level code = getCodeFromId(id, this.Codes.LEVEL, this.Ids.LEVEL, is_of_enum); 
        
        if (is_of_enum)
        {
            return code;
        }
        else
        {
            try
            {
                Level n = cast (Level) Integer.toInt(id);
            }
            catch (Exception e)
            {
                if (accept_unknown)
                {
                    return code;
                }
                else
                {
                    e.msg = typeof (this).stringof ~
                            ": invalid encoding identifier '" ~ id ~ "' (" ~ e.msg ~ ')';
                    
                    throw e;
                }
            }
        }
        
        return validateLevel(code, accept_unknown);
    }


    /**************************************************************************
      
      Initialize ZlibStream input to read from a new input stream
      
          Params:
              stream_in    = compressed input buffer stream
              
     **************************************************************************/ 
    
    private ZlibInput initZlibStreamInput ( InputStream stream_in )
    {
        if (this.decomp)
        {   
            this.decomp.reset(stream_in, this.decoding);
        }
        else 
        {         
            this.decomp = new ZlibInput(stream_in, this.decoding);
        }
        
        return this.decomp;
    }
    
    
    /**************************************************************************
    
        Initialize ZlibStream output to write to a new output stream
        
            Params:
                stream_out    = compressed output buffer stream
                
   **************************************************************************/ 
  
    private ZlibOutput initZlibStreamOutput ( OutputStream stream_out )
    {
        if (this.comp)
        {   
            this.comp.reset(stream_out, this.level, this.encoding);
        }
        else 
        {         
            this.comp = new ZlibOutput(stream_out, this.level, this.encoding);
        }
        
        return this.comp;
    }
    
    /**************************************************************************
    
        Initialize input buffer
     
    **************************************************************************/
    
    private typeof (input_buffer) initInputBuffer ( )
    {   
      if (this.input_buffer)
      {
          this.input_buffer.clear(); // Clear input buffer       
      }
      else 
      {
          // Create input buffer for ZlibStream to consume
          this.input_buffer = new Array(this.BufferSize.INPUT_INIT,
                                        this.BufferSize.INPUT_GROW);
      }
      
      return this.input_buffer;
    }
    
    
    
    /**************************************************************************
    
        Initialize output buffer 
    
    **************************************************************************/
    
    private typeof (output_buffer) initOutputBuffer ()
    {   
      if (this.output_buffer)
      {
          this.output_buffer.clear(); // Clear output buffer
      }
      else 
      {
          // Create output buffer for ZlibStream to consume
          this.output_buffer = new Array(this.BufferSize.OUTPUT_INIT,
                                         this.BufferSize.OUTPUT_GROW);            
      }
      
      return this.output_buffer;
    }
    
    /**************************************************************************
    
        Slice output buffer
        
         Params:
             buffer_out = destination output buffer
    
    **************************************************************************/

    private void sliceOutputBuffer ( T ) ( out T[] buffer_out )
    {
        try
        {
            buffer_out = cast (T[]) this.output_buffer.slice();
        }
        catch (Exception e)
        {
            CompressException(e.msg);
        }
    }
    

    
    /**************************************************************************
    
        Verify code_in is equal to an element of codes.
        
        If code is equal to any element of codes, and nevermind is
             - true, the value of the first element of code is returned and
                     nevermind is set to false;
             - false, an exception is thrown.
        
        Params:
            code           = code to validate
            codes          = list of valid codes
            accept_unknown = Set to true to return the value of the first
                             element of code on invalid code or to false to
                             throw an exception in this case.
            
        Returns:
            verified code
        
    **************************************************************************/

    private static T validateCode ( T ) ( T code_in, T[] codes, ref bool nevermind )
    in                                         
    {
        assert (codes.length, typeof (this).stringof ~ ".validateCode(): empty codes list");
    }
    body
    {
        foreach (code; codes)
        {
            if (code == code_in) return code;
        }
        
        assert (nevermind, typeof (this).stringof ~ " invalid " ~
                                T.stringof ~ " code");

        nevermind = false;
        
        return codes[0];    
    }
    
    
    /**************************************************************************
    
        Validate compression level.
        
        The compression level may be an integer value from -1 to 9 where -1
        denotes the default compression level, 0 no, 1 lowest/fastest and 9
        highest/slowest compression.
        
        If an invalid code is supplied, and nevermind is
             - true, the default compression level value is returned and
                     nevermind is set to false;
             - false, an exception is thrown.
        
        Params:
            code           = compression level code to validate
            accept_unknown = Set to true to return default compression level
                             on unknown identifier string or to false to throw
                             an exception in this case.
            
        Returns:
            validated compression level
        
    **************************************************************************/
    
    private static Level validateLevel ( int code, bool nevermind )
    {
        bool in_range = ((code >= Level.min) && (Level.max >= code));
        
        assert (in_range || nevermind, typeof (this).stringof ~ ": compression "
                                       "level parameter out of range");
        
        return in_range? cast (Level) code : Level.Normal;
    }
    

    /**************************************************************************
    
        Looks up id in ids and returns the code corresponding to the id. An
        empty id string corresponds to the first element of code.
        
        If id is not found in ids and not an empty string, and nevermind is
             - true, the value of the first element of code is returned and
                     nevermind is set to false;
             - false, an exception is thrown.
        
        Params:
            id             = code identifier string
            codes          = list of codes
            ids            = list of ids corresponding to codes
            accept_unknown = Set to true to return the value of the first
                             element of code on unknown id or to false to
                             throw an exception in this case.
            
        Returns:
            verified code
        
    **************************************************************************/

    private static T getCodeFromId ( T ) ( char[] id, T[] codes, char[][][] ids,
                                           ref bool nevermind )
    in
    {
        assert (codes.length == ids.length, typeof (this).stringof ~ ".getCodeFromId(): "
                                            "codes/ids length mismatch");
        
        assert (codes.length, typeof (this).stringof ~ ".getCodeFromId(): empty codes list");
    }
    body
    {
        foreach (i, id_aliases; ids)
        {
            foreach (id_alias; id_aliases)
            {
                if (id ==  id_alias) return codes[i];
            }
        }
        
        assert (!id.length || nevermind, typeof (this).stringof ~ ": unknown " ~
                                         T.stringof ~ " identifier '" ~ id ~ '\'');
        
        nevermind = false;
        
        return codes[0];
    }
    
    /**************************************************************************
    
        Assert T is a single byte type or void 
    
    **************************************************************************/

    template assertByteType ( T, char[] context, char[] item )
    {
        const assertByteType = ((T.sizeof == 1) || is (T == void));
        
        static assert (assertByteType,
                       typeof (this).stringof ~ context ~ ": '" ~ item ~
                       "' must be array of single byte type or void, not '" ~
                       T.stringof ~ '\'');
    }
}

