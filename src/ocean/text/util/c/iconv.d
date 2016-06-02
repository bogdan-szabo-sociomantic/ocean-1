/*******************************************************************************

       D binding for the C iconv library.

       The C iconv library is used to convert from one character encoding to another.

       See_Also: http://www.gnu.org/software/libiconv/

       Copyright:
           Copyright (c) 2009-2016 Sociomantic Labs GmbH.
           All rights reserved.

       License:
           Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
           Alternatively, this file may be distributed under the terms of the Tango
           3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.text.util.c.iconv;

import ocean.transition;

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
