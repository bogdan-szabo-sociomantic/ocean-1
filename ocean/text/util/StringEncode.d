/*******************************************************************************

	Character encoding conversion.

	copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved

	version:        Apr 2010: Initial release

	authors:        David Eckardt
					Gavin Norman

	Character encoding conversion using the C iconv library
	(ocean.text.util.c.Iconv).

	Usage:
		This module can be used by creating an instance of the StringEncode
		class with the template parameters of the desired character encoding
		conversion:

			auto string_enc = new StringEncode!("ISO-8859-1", "UTF-8");

		The conversion function is called as follows:
		
			char[] input = "A string to be converted";
			char[] output; // The buffer which is written into

			string_enc.convert(input, output);

*******************************************************************************/

module ocean.text.util.StringEncode;



/*******************************************************************************

	Imports

*******************************************************************************/

private import ocean.text.util.c.iconv;

private import tango.stdc.errno;

private import ocean.core.Exception : IconvException;

debug
{
	private import tango.util.log.Trace;
}



/*******************************************************************************

    Encoder interface.

*******************************************************************************/

interface StringEncoder
{
    /***************************************************************************

        Converts a string from one encoding to another.
        
        Params:
            input = string to convert
            output = converted string
    
    ***************************************************************************/

    public void convert ( char[] input, ref char[] output );
}



/*******************************************************************************

	StringEncode class
	The template parameters are the character encoding types for the input
	and output of the converter.

*******************************************************************************/

public class StringEncode ( char[] fromcode, char[] tocode ) : StringEncoder
{
	/***************************************************************************

		The conversion descriptor which iconv uses internally

	***************************************************************************/

	private ConversionDescriptor cd;


    /***************************************************************************

        Exceptions which could be thrown by this class. (These are created as
        class members so that there is no risk of convert() being called over
        and over, and newing exceptions each time, leading to an accumulation of
        memory over time.)

    ***************************************************************************/

    private IconvException.InvalidMbSeq exception_InvalidMbSeq;

    private IconvException.IncompleteMbSeq exception_IncompleteMbSeq;

    private IconvException.TooBig exception_TooBig;

    private IconvException exception_Generic;


    /***************************************************************************

		Constructor.
		Initialises iconv with the desired character encoding conversion types,
		and sets default values for the public bool properties above.
	
	***************************************************************************/

	public this ( )
	{
		this.cd = iconv_open(tocode.ptr, fromcode.ptr);

        this.exception_InvalidMbSeq = new IconvException.InvalidMbSeq;

        this.exception_IncompleteMbSeq = new IconvException.IncompleteMbSeq;

        this.exception_TooBig = new IconvException.TooBig;

        this.exception_Generic = new IconvException;
    }


    /***************************************************************************

        Destructor.
        Simply closes down the C iconv library.
    
    ***************************************************************************/

    private ~this ( )
    {
        iconv_close(this.cd);
    }

    /***************************************************************************

        Dispose.
        Deletes unneeded objects
    
    ***************************************************************************/

    public void dispose ( )
    {
        delete this.exception_InvalidMbSeq;

        delete this.exception_IncompleteMbSeq;

        delete this.exception_TooBig;

        delete this.exception_Generic; 
    }

    /***************************************************************************

		Converts a string in one encoding type to another (as specified by the 
		class' template parameters).

		Makes a guess at the required size of output buffer, simply setting it
		to the same size as the input buffer. Then repeatedly trys converting
		the input and increasing the size of the output buffer until the
		conversion succeeds.

		To avoid repeated memory allocation, if you need to call this function
		many times, it's best to always pass the same output buffer.

		Params:
			input = the array of characters to be converted.
			output = array of characters which will be filled with the results
			         of the conversion. The output array is resized to fit the
                     results.

	***************************************************************************/

    public void convert ( char[] input, ref char[] output )
    {
        output.length = input.length;

        bool succeeded = false;

        for(;;)
        {
            size_t inbytesleft  = input.length;
            size_t outbytesleft = output.length;
            char* inptr  = input.ptr;
            char* outptr = output.ptr;

            // Do the conversion
            ptrdiff_t result = iconv(this.cd, &inptr, &inbytesleft, &outptr, &outbytesleft);

            // If the conversion fails because the output buffer was too small,
            // resize the output buffer and try again.
            if (result < 0 && errno() == E2BIG)
            {
                // TODO: performance could be improved here by passing the
                // number of bytes already processed to iconv
                output.length = output.length + input.length;
                continue;
            }

            output.length = output.length - outbytesleft;
            // Check for any errors from iconv and throw them as exceptions
            if (result < 0)
            {
                switch (errno())
                {
                    case EILSEQ:
                        throw this.exception_InvalidMbSeq;

                    case EINVAL:
                        throw this.exception_IncompleteMbSeq;

                    case E2BIG:
                        throw this.exception_TooBig;

                    default:
                        throw this.exception_Generic;
                }
            }
            break;
        }
    }

	/***************************************************************************

		Internal conversion method which calls the C iconv function.
		The error return values from iconv are thrown as exceptions.
	
		Params:
			input = the array of characters to be converted.
			output = array of characters which will be filled with the results
			         of the conversion. The output array is resized to fit the
                     results.
	
	***************************************************************************/

	protected void convert_ ( char[] input, ref char[] output )
	{
		size_t inbytesleft  = input.length;
		size_t outbytesleft = output.length;
		char* inptr  = input.ptr;
		char* outptr = output.ptr;

		// Do the conversion
		ptrdiff_t result = iconv(this.cd, &inptr, &inbytesleft, &outptr, &outbytesleft);
		output.length = output.length - outbytesleft;

		// Check for any errors from iconv and throw them as exceptions
		if (result < 0)
		{
			switch (errno())
			{
				case EILSEQ:
                    throw this.exception_InvalidMbSeq;
					
				case EINVAL:
                    throw this.exception_IncompleteMbSeq;
					
				case E2BIG:
                    throw this.exception_TooBig;
					
				default:
                    throw this.exception_Generic;
			}
		}
	}
}



/*******************************************************************************

    String encoder sequence. Runs a sequence of encoders over a string until one
    achieves a successful encoding.

    Template params:
        Encoders = tuple of types of encoders

*******************************************************************************/

public class StringEncoderSequence ( Encoders... )
{
    /***************************************************************************

        Static constructor - ensures that all template types implement the
        Encoder interface.
    
    ***************************************************************************/

    static this ( )
    {
        foreach ( E; Encoders )
        {
            static assert(is(E : StringEncoder));
        }
    }


    /***************************************************************************

        Array of encoders.
    
    ***************************************************************************/
    
    private StringEncoder[] encoders;


    /***************************************************************************

        Constructor. News an instance of each of the template types.
    
    ***************************************************************************/

    public this ( )
    {
        foreach ( E; Encoders )
        {
            this.encoders ~= new E;
        }
    }


    /***************************************************************************

        Disposer. Deletes encoders.

    ***************************************************************************/

    void dispose ( )
    {
        foreach ( e; this.encoders )
        {
            delete e;
        }
    }


    /***************************************************************************

        Runs the encoders in sequence until one succeeds.

        This method is aliased with opCall.
        
        Params:
            input = text to convert
            output = converted text

        Returns:
            converted text, or "" if all encoders failed.
    
    ***************************************************************************/

    public char[] convert ( char[] input, ref char[] output )
    {
        output.length = 0;

        foreach ( e; this.encoders )
        {
            try
            {
                if ( convert(e, input, output) )
                {
                    return output;
                }
            }
            // Exceptions thrown by an encoder are ignored.
            catch ( IconvException.InvalidMbSeq e )
            {
            }
            catch ( IconvException.IncompleteMbSeq e )
            {
            }
            catch ( IconvException e )
            {
            }
        }

        output.length = 0;
        return output;
    }

    public alias convert opCall;


    /***************************************************************************

        Attempts to convert the given text with the given encoder.
        
        Params:
            encoder = encoder to use
            input = text to convert
            output = converted text
    
        Returns:
            true if the text was converted successfully
    
    ***************************************************************************/

    private bool convert ( StringEncoder encoder, char[] input, ref char[] output )
    {
        try
        {
            encoder.convert(input, output);
            return true;
        }
        catch ( IconvException.InvalidMbSeq )
        {
            return false;
        }
    }
}

