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
	private import tango.io.Stdout;
}



/*******************************************************************************

	StringEncode class
	The template parameters are the character encoding types for the input
	and output of the converter.

*******************************************************************************/

public class StringEncode ( char[] fromcode, char[] tocode )
{
	/***************************************************************************

		Protected property : the conversion descriptor which iconv uses
		internally
	
	***************************************************************************/

	protected ConversionDescriptor cd;


	/***************************************************************************

		Constructor.
		Initialises iconv with the desired character encoding conversion types,
		and sets default values for the public bool properties above.
	
	***************************************************************************/

	public this ( )
	{
		this.cd = iconv_open(tocode.ptr, fromcode.ptr);
	}


	/***************************************************************************

		Converts a string in one encoding type to another (as specified by the 
		class' template parameters).

		Repeatedly trys converting the input and resizing the output buffer
		until the conversion succeeds.

		Params:
			input = the array of characters to be converted.
			
			output = array of characters which will be filled with the results
			of the conversion. The output array is resized to fit the results.

		Returns:
			void

	***************************************************************************/


	public void convert ( char[] input, out char[] output )
	{
		bool succeeded = false;
		while ( !succeeded )
		{
			try
			{
				this.convert_(input, output);
				succeeded = true;
			}
			// If the conversion fails because the output buffer was too small,
			// resize the output buffer and try again.
			catch ( IconvException.TooBig )
			{
				output.length = output.length + input.length;
				debug
				{
					Stderr.formatln("StringEncode.convert : expanding output buffer to {} chars", output.length);
				}
			}
		}
	}


	/***************************************************************************

		Internal conversion method which calls the C iconv function.
		The error return values from iconv are thrown as exceptions.
	
		Params:
			input = the array of characters to be converted.
			
			output = array of characters which will be filled with the results
			of the conversion. The output array is resized to fit the results.
	
		Returns:
			void
	
	***************************************************************************/

	protected void convert_ ( char[] input, out char[] output )
	{
		output.length = input.length;
		
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
					throw new IconvException.InvalidMbSeq;
					
				case EINVAL:
					throw new IconvException.IncompleteMbSeq;
					
				case E2BIG:
					throw new IconvException.TooBig;
					
				default:
					throw new IconvException;
			}
		}
	}


	/***************************************************************************

		Destructor.
		Simply closes down the C iconv library.
	
	***************************************************************************/

	private ~this ( )
	{
		iconv_close(this.cd);
	}
}

