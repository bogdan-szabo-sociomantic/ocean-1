module ocean.db.tokyocabinet.c.util.tcxstr;

extern (C):

/*************************************************************************************************
 * Extensible string utility
 *************************************************************************************************/

struct TCXSTR                                   /* type of structure for an extensible string object */
{                         
    char* ptr;                                  /* pointer to the region */
    int size;                                   /* size of the region */
    int asize;                                  /* size of the allocated region */
};

    
/* Create an extensible string object.
   The return value is the new extensible string object. */
TCXSTR* tcxstrnew();


/* Create an extensible string object from a character string.
   `str' specifies the string of the initial content.
   The return value is the new extensible string object containing the specified string. */
TCXSTR* tcxstrnew2(char* str);


/* Create an extensible string object with the initial allocation size.
   `asiz' specifies the initial allocation size.
   The return value is the new extensible string object. */
TCXSTR* tcxstrnew3(int asiz);


/* Copy an extensible string object.
   `xstr' specifies the extensible string object.
   The return value is the new extensible string object equivalent to the specified object. */
TCXSTR* tcxstrdup(TCXSTR* xstr);


/* Delete an extensible string object.
   `xstr' specifies the extensible string object.
   Note that the deleted object and its derivatives can not be used anymore. */
void tcxstrdel(TCXSTR* xstr);


/* Concatenate a region to the end of an extensible string object.
   `xstr' specifies the extensible string object.
   `ptr' specifies the pointer to the region to be appended.
   `size' specifies the size of the region. */
void tcxstrcat(TCXSTR* xstr, void* ptr, int size);


/* Concatenate a character string to the end of an extensible string object.
   `xstr' specifies the extensible string object.
   `str' specifies the string to be appended. */
void tcxstrcat2(TCXSTR* xstr, char* str);


/* Get the pointer of the region of an extensible string object.
   `xstr' specifies the extensible string object.
   The return value is the pointer of the region of the object.
   Because an additional zero code is appended at the end of the region of the return value,
   the return value can be treated as a character string. */
void* tcxstrptr(TCXSTR* xstr);


/* Get the size of the region of an extensible string object.
   `xstr' specifies the extensible string object.
   The return value is the size of the region of the object. */
int tcxstrsize(TCXSTR* xstr);


/* Clear an extensible string object.
   `xstr' specifies the extensible string object.
   The internal buffer of the object is cleared and the size is set zero. */
void tcxstrclear(TCXSTR* xstr);


/* Perform formatted output into an extensible string object.
   `xstr' specifies the extensible string object.
   `format' specifies the printf-like format string.  The conversion character `%' can be used
   with such flag characters as `s', `d', `o', `u', `x', `X', `c', `e', `E', `f', `g', `G', `@',
   `?', `b', and `%'.  `@' works as with `s' but escapes meta characters of XML.  `?' works as
   with `s' but escapes meta characters of URL.  `b' converts an integer to the string as binary
   numbers.  The other conversion character work as with each original.
   The other arguments are used according to the format string. */
void tcxstrprintf(TCXSTR* xstr, char* format, ...);


/* Allocate a formatted string on memory.
   `format' specifies the printf-like format string.  The conversion character `%' can be used
   with such flag characters as `s', `d', `o', `u', `x', `X', `c', `e', `E', `f', `g', `G', `@',
   `?', `b', and `%'.  `@' works as with `s' but escapes meta characters of XML.  `?' works as
   with `s' but escapes meta characters of URL.  `b' converts an integer to the string as binary
   numbers.  The other conversion character work as with each original.
   The other arguments are used according to the format string.
   The return value is the pointer to the region of the result string.
   Because the region of the return value is allocated with the `malloc' call, it should be
   released with the `free' call when it is no longer in use. */
char* tcsprintf(char* format, ...);



/*************************************************************************************************
 * extensible string (for experts)
 *************************************************************************************************/


/* Convert an extensible string object into a usual allocated region.
   `xstr' specifies the extensible string object.
   The return value is the pointer to the allocated region of the object.
   Because an additional zero code is appended at the end of the region of the return value,
   the return value can be treated as a character string.  Because the region of the return
   value is allocated with the `malloc' call, it should be released with the `free' call when it
   is no longer in use.  Because the region of the original object is deleted, it should not be
   deleted again. */
void* tcxstrtomalloc(TCXSTR* xstr);


/* Create an extensible string object from an allocated region.
   `ptr' specifies the pointer to the region allocated with `malloc' call.
   `size' specifies the size of the region.
   The return value is the new extensible string object wrapping the specified region.
   Note that the specified region is released when the object is deleted. */
TCXSTR* tcxstrfrommalloc(void* ptr, int size);
