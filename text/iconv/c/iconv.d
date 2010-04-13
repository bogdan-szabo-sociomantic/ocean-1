module text.iconv.c.iconv;

extern (C)
{
	typedef void* ConversionDescriptor;
		
	/* Allocate descriptor for code conversion from codeset FROMCODE to
	codeset TOCODE.
	
	This function is a possible cancellation points and therefore not
	marked with __THROW.  */
	ConversionDescriptor iconv_open ( char* tocode, char* fromcode );
	
	/* Convert at most *INBYTESLEFT bytes from *INBUF according to the
	code conversion algorithm specified by CD and place up to
	*OUTBYTESLEFT bytes in buffer at *OUTBUF.  */
	ptrdiff_t iconv ( ConversionDescriptor cd, char** inbuf, size_t* inbytesleft, char** outbuf, size_t* outbytesleft );
	
	/* Free resources allocated for descriptor CD for code conversion.
	
	This function is a possible cancellation points and therefore not
	marked with __THROW.  */
	int iconv_close (ConversionDescriptor cd);
}
