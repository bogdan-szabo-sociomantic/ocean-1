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

		The following public bool properties set useful controls on the process
		(both default to true):

			string_enc.auto_resize_out_buf : automatically resize the output
			buffer if it's too small
			
			string_enc.strip_non_display_chars : replace any non-displayable
			characters with spaces
		
		The conversion function is called as follows:
			char[] input = "A string to be converted";
			char[] output; // The buffer which is written into

			char[] output_written;
			char[] remaining_in;
			char[] remaining_out;
			uint inchars_read;
			uint outchars_written;
	
			ptrdiff_t result = string_enc.convert(input, output, output_written,
				remaining_in, remaining_out, inchars_read, outchars_written);

		If the conversion succeeds, output_written is set to a slice of the
		output buffer.

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

		Public property : should the output buffer be automatically resized if
		it isn't big enough for the conversion?
		
		The constructor sets this to default as true.

	***************************************************************************/

	public bool auto_resize_out_buf;


	/***************************************************************************

		Public property : Should non displayable characters (< ascii 0x20) in
		the output buffer be replaced with spaces?

		The constructor sets this to default as true.

	***************************************************************************/

	public bool strip_non_display_chars;

	
	/***************************************************************************

		Constructor.
		Initialises iconv with the desired character encoding conversion types,
		and sets default values for the public bool properties above.
	
	***************************************************************************/

	public this ( )
	{
		this.cd = iconv_open(tocode.ptr, fromcode.ptr);
		this.auto_resize_out_buf = true;
		this.strip_non_display_chars = true;
	}


	/***************************************************************************

		Converts a string in one encoding type to another (as specified by the 
		class' template parameters).
		
		Optionally will resize the output buffer so it fits (if auto_resize_out_buf
		is true), and replace non-displayable characters with spaces (if
		strip_non_display_chars is true).
		
		Calls the protected method doConvert to do the actual conversion.

		Params:
			inbuf = the array of characters to be converted.
			
			outbuf = reference to an array of characters which will be filled
			with the results of the conversion.
			
			written_out = a slice of outbuf containing just the characters which
			were converted (outbuf will usually be longer than necessary, and so
			has some "junk" at the end).

		Fail params: (these parameters are only relevant in cases where the full
		conversion was not possible, for example if the output buffer was too
		small)
			remaining_in = a slice of the input buffer, from the point where
			conversion finished to the end.
			
			remaining_out = a slice of the output buffer, from the point where
			conversion finished to the end.
			
			inchars_read = the number of characters read from inbuf.
			
			outchars_written = the number of characters written to outbuf.

		Returns:
			passes on the return value of the C inconv function

	***************************************************************************/

	public ptrdiff_t convert ( char[] inbuf, ref char[] outbuf, out char[] written_out,
			out char[] remaining_in, out char[] remaining_out,
			out uint inchars_read, out uint outchars_written )
	{
		ptrdiff_t result;
		if ( this.auto_resize_out_buf )
		{
			bool succeeded = false;
			while ( !succeeded )
			{
				try
				{
					result = this.doConvert(inbuf, outbuf, written_out, remaining_in,
							remaining_out, inchars_read, outchars_written);
					succeeded = true;
				}
				// If the conversion fails because the output buffer was too small,
				// resize the output buffer and try again.
				catch ( IconvException.TooBig )
				{
					outbuf.length = outbuf.length + inbuf.length;
					debug
					{
						Stderr.formatln("Iconv.convert : expanding output buffer to {} chars", outbuf.length);
					}
				}
			}
		}
		else
		{
			result = this.doConvert(inbuf, outbuf, written_out, remaining_in,
					remaining_out, inchars_read, outchars_written);
		}

		// Optionally strip out any non-displayable characters (below 0x20)
		if ( this.strip_non_display_chars )
		{
			this.stripNonDisplayChars(outbuf);
		}

		return result;
	}


	/***************************************************************************

		Internal conversion method which calls the C iconv function.
		
		Params:
			inbuf = the array of characters to be converted.
			
			outbuf = reference to an array of characters which will be filled
			with the results of the conversion.
			
			written_out = a slice of outbuf containing just the characters which
			were converted (outbuf will usually be longer than necessary, and so
			has some "junk" at the end).
	
		Fail params: (these parameters are only relevant in cases where the full
		conversion was not possible, for example if the output buffer was too
		small)
			remaining_in = a slice of the input buffer, from the point where
			conversion finished to the end.
			
			remaining_out = a slice of the output buffer, from the point where
			conversion finished to the end.
			
			inchars_read = the number of characters read from inbuf.
			
			outchars_written = the number of characters written to outbuf.
	
		Returns:
			passes on the return value of the C inconv function
	
	***************************************************************************/

	protected ptrdiff_t doConvert ( char[] inbuf, ref char[] outbuf, out char[] written_out,
			out char[] remaining_in, out char[] remaining_out,
			out uint inchars_read, out uint outchars_written )
	{
		size_t inbytesleft  = inbuf.length;
		size_t outbytesleft = outbuf.length;
		char* inptr  = inbuf.ptr;
		char* outptr = outbuf.ptr;
		
		// Do the conversion
		ptrdiff_t result = iconv(this.cd, &inptr, &inbytesleft, &outptr, &outbytesleft);

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

		// Calculate out values
		inchars_read = inbuf.length - inbytesleft;
		outchars_written = outbuf.length - outbytesleft;
		written_out = outbuf[0..outchars_written];
		remaining_in = inbuf[inbuf.length - inbytesleft..inbuf.length];
		remaining_out = outbuf[outbuf.length - outbytesleft..outbuf.length];

		return result;
	}


	/***************************************************************************

		Processes a char array, replacing any character below ASCII 0x20 with a
		space. The exceptions are 0x09 (tab), 0x0A (line feed) and 0x0D (carriage
		return), which are not modified.

		Params:
			buf = the array of characters to be processed.

		Returns:
			void

	***************************************************************************/

	public void stripNonDisplayChars ( ref char[] buf )
	{
		const uint TAB = 0x09;
		const uint LINEFEED = 0x0A;
		const uint CARRIAGE_RET = 0x0D;

		foreach ( i, c; buf )
		{
			if ( c < 0x20 && !(c == TAB || c == LINEFEED || c == CARRIAGE_RET) )
			{
				buf[i] = 32;
				debug
				{
					Stderr.formatln("Iconv.stripNonDisplayChars : converting non-displayable character ({}) -> 32 (space)", cast(uint)c);
				}
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

