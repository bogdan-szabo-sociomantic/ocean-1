/*******************************************************************************

	D binding for the C iconv library.

	copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved

	version:        Apr 2010: Initial release

	authors:        David Eckardt
					Gavin Norman

	The C iconv library is used to convert from one character encoding to another.
	See http://www.gnu.org/software/libiconv/

*******************************************************************************/

module ocean.text.util.c.iconv;

import tango.transition;

extern (C)
{
	mixin(Typedef!(void*, "ConversionDescriptor"));

	/* Allocate descriptor for code conversion from codeset FROMCODE to
	codeset TOCODE.

	This function is a possible cancellation points and therefore not
	marked with __THROW.  */
	ConversionDescriptor iconv_open ( in char* tocode, in char* fromcode );

	/* Convert at most *INBYTESLEFT bytes from *INBUF according to the
	code conversion algorithm specified by CD and place up to
	*OUTBYTESLEFT bytes in buffer at *OUTBUF.  */
	ptrdiff_t iconv ( ConversionDescriptor cd, Const!(char)** inbuf, size_t* inbytesleft, char** outbuf, size_t* outbytesleft );

	/* Free resources allocated for descriptor CD for code conversion.

	This function is a possible cancellation points and therefore not
	marked with __THROW.  */
	int iconv_close (ConversionDescriptor cd);
}
