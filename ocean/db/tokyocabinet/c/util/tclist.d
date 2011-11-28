module ocean.db.tokyocabinet.c.util.tclist;

extern (C):

/*************************************************************************************************
 * List utility
 *************************************************************************************************/

struct TCLISTDATUM                              /* type of structure for an element of a list */ 
{                  
    char*   ptr;                                /* pointer to the region */
    int     size;                               /* size of the effective region */
};

struct TCLIST                                   /* type of structure for an array list */
{                         
    TCLISTDATUM* array;                         /* array of data */
    int          anum;                          /* number of the elements of the array */
    int          start;                         /* start index of used elements */
    int          num;                           /* number of used elements */
};

//  List item comparison callback function used in tclistsortex
 alias int function (TCLISTDATUM*, TCLISTDATUM*) ListCmp;
    
    /* Create a list object.
    The return value is the new list object. */
 TCLIST* tclistnew();


 /* Create a list object with expecting the number of elements.
    `anum' specifies the number of elements expected to be stored in the list.
    The return value is the new list object. */
 TCLIST* tclistnew2(int anum);


 /* Create a list object with initial string elements.
    `str' specifies the string of the first element.
    The other arguments are other elements.  They should be trailed by a `NULL' argument.
    The return value is the new list object. */
 TCLIST* tclistnew3(char* str, ...);


 /* Copy a list object.
    `list' specifies the list object.
    The return value is the new list object equivalent to the specified object. */
 TCLIST* tclistdup(TCLIST* list);


 /* Delete a list object.
    `list' specifies the list object.
    Note that the deleted object and its derivatives can not be used anymore. */
 void tclistdel(TCLIST* list);


 /* Get the number of elements of a list object.
    `list' specifies the list object.
    The return value is the number of elements of the list. */
 int tclistnum(TCLIST* list);


 /* Get the pointer to the region of an element of a list object.
    `list' specifies the list object.
    `index' specifies the index of the element.
    `sp' specifies the pointer to the variable into which the size of the region of the return
    value is assigned.
    The return value is the pointer to the region of the value.
    Because an additional zero code is appended at the end of the region of the return value,
    the return value can be treated as a character string.  If `index' is equal to or more than
    the number of elements, the return value is `NULL'. */
 void* tclistval(TCLIST* list, int index, int* sp);


 /* Get the string of an element of a list object.
    `list' specifies the list object.
    `index' specifies the index of the element.
    The return value is the string of the value.
    If `index' is equal to or more than the number of elements, the return value is `NULL'. */
 char* tclistval2(TCLIST* list, int index);


 /* Add an element at the end of a list object.
    `list' specifies the list object.
    `ptr' specifies the pointer to the region of the new element.
    `size' specifies the size of the region. */
 void tclistpush(TCLIST* list, void* ptr, int size);


 /* Add a string element at the end of a list object.
    `list' specifies the list object.
    `str' specifies the string of the new element. */
 void tclistpush2(TCLIST* list, char* str);


 /* Remove an element of the end of a list object.
    `list' specifies the list object.
    `sp' specifies the pointer to the variable into which the size of the region of the return
    value is assigned.
    The return value is the pointer to the region of the removed element.
    Because an additional zero code is appended at the end of the region of the return value,
    the return value can be treated as a character string.  Because the region of the return
    value is allocated with the `malloc' call, it should be released with the `free' call when it
    is no longer in use.  If the list is empty, the return value is `NULL'. */
 void* tclistpop(TCLIST* list, int* sp);


 /* Remove a string element of the end of a list object.
    `list' specifies the list object.
    The return value is the string of the removed element.
    Because the region of the return value is allocated with the `malloc' call, it should be
    released with the `free' call when it is no longer in use.  If the list is empty, the return
    value is `NULL'. */
 char* tclistpop2(TCLIST* list);


 /* Add an element at the top of a list object.
    `list' specifies the list object.
    `ptr' specifies the pointer to the region of the new element.
    `size' specifies the size of the region. */
 void tclistunshift(TCLIST* list, void* ptr, int size);


 /* Add a string element at the top of a list object.
    `list' specifies the list object.
    `str' specifies the string of the new element. */
 void tclistunshift2(TCLIST* list, char* str);


 /* Remove an element of the top of a list object.
    `list' specifies the list object.
    `sp' specifies the pointer to the variable into which the size of the region of the return
    value is assigned.
    The return value is the pointer to the region of the removed element.
    Because an additional zero code is appended at the end of the region of the return value,
    the return value can be treated as a character string.  Because the region of the return
    value is allocated with the `malloc' call, it should be released with the `free' call when it
    is no longer in use.  If the list is empty, the return value is `NULL'. */
 void* tclistshift(TCLIST* list, int* sp);


 /* Remove a string element of the top of a list object.
    `list' specifies the list object.
    The return value is the string of the removed element.
    Because the region of the return value is allocated with the `malloc' call, it should be
    released with the `free' call when it is no longer in use.  If the list is empty, the return
    value is `NULL'. */
 char* tclistshift2(TCLIST* list);


 /* Add an element at the specified location of a list object.
    `list' specifies the list object.
    `index' specifies the index of the new element.
    `ptr' specifies the pointer to the region of the new element.
    `size' specifies the size of the region.
    If `index' is equal to or more than the number of elements, this function has no effect. */
 void tclistinsert(TCLIST* list, int index, void* ptr, int size);


 /* Add a string element at the specified location of a list object.
    `list' specifies the list object.
    `index' specifies the index of the new element.
    `str' specifies the string of the new element.
    If `index' is equal to or more than the number of elements, this function has no effect. */
 void tclistinsert2(TCLIST* list, int index, char* str);


 /* Remove an element at the specified location of a list object.
    `list' specifies the list object.
    `index' specifies the index of the element to be removed.
    `sp' specifies the pointer to the variable into which the size of the region of the return
    value is assigned.
    The return value is the pointer to the region of the removed element.
    Because an additional zero code is appended at the end of the region of the return value,
    the return value can be treated as a character string.  Because the region of the return
    value is allocated with the `malloc' call, it should be released with the `free' call when it
    is no longer in use.  If `index' is equal to or more than the number of elements, no element
    is removed and the return value is `NULL'. */
 void* tclistremove(TCLIST* list, int index, int* sp);


 /* Remove a string element at the specified location of a list object.
    `list' specifies the list object.
    `index' specifies the index of the element to be removed.
    The return value is the string of the removed element.
    Because the region of the return value is allocated with the `malloc' call, it should be
    released with the `free' call when it is no longer in use.  If `index' is equal to or more
    than the number of elements, no element is removed and the return value is `NULL'. */
 char* tclistremove2(TCLIST* list, int index);


 /* Overwrite an element at the specified location of a list object.
    `list' specifies the list object.
    `index' specifies the index of the element to be overwritten.
    `ptr' specifies the pointer to the region of the new content.
    `size' specifies the size of the new content.
    If `index' is equal to or more than the number of elements, this function has no effect. */
 void tclistover(TCLIST* list, int index, void* ptr, int size);


 /* Overwrite a string element at the specified location of a list object.
    `list' specifies the list object.
    `index' specifies the index of the element to be overwritten.
    `str' specifies the string of the new content.
    If `index' is equal to or more than the number of elements, this function has no effect. */
 void tclistover2(TCLIST* list, int index, char* str);


 /* Sort elements of a list object in lexical order.
    `list' specifies the list object. */
 void tclistsort(TCLIST* list);


 /* Search a list object for an element using liner search.
    `list' specifies the list object.
    `ptr' specifies the pointer to the region of the key.
    `size' specifies the size of the region.
    The return value is the index of a corresponding element or -1 if there is no corresponding
    element.
    If two or more elements correspond, the former returns. */
 int tclistlsearch(TCLIST* list, void* ptr, int size);


 /* Search a list object for an element using binary search.
    `list' specifies the list object.  It should be sorted in lexical order.
    `ptr' specifies the pointer to the region of the key.
    `size' specifies the size of the region.
    The return value is the index of a corresponding element or -1 if there is no corresponding
    element.
    If two or more elements correspond, which returns is not defined. */
 int tclistbsearch(TCLIST* list, void* ptr, int size);


 /* Clear a list object.
    `list' specifies the list object.
    All elements are removed. */
 void tclistclear(TCLIST* list);


 /* Serialize a list object into a byte array.
    `list' specifies the list object.
    `sp' specifies the pointer to the variable into which the size of the region of the return
    value is assigned.
    The return value is the pointer to the region of the result serial region.
    Because the region of the return value is allocated with the `malloc' call, it should be
    released with the `free' call when it is no longer in use. */
 void* tclistdump(TCLIST* list, int* sp);


 /* Create a list object from a serialized byte array.
    `ptr' specifies the pointer to the region of serialized byte array.
    `size' specifies the size of the region.
    The return value is a new list object.
    Because the object of the return value is created with the function `tclistnew', it should
    be deleted with the function `tclistdel' when it is no longer in use. */
 TCLIST* tclistload(void* ptr, int size);



 /*************************************************************************************************
  * array list (for experts)
  *************************************************************************************************/


 /* Add an allocated element at the end of a list object.
    `list' specifies the list object.
    `ptr' specifies the pointer to the region allocated with `malloc' call.
    `size' specifies the size of the region.
    Note that the specified region is released when the object is deleted. */
 void tclistpushmalloc(TCLIST* list, void* ptr, int size);


 /* Sort elements of a list object in case-insensitive lexical order.
    `list' specifies the list object. */
 void tclistsortci(TCLIST* list);

 /* Sort elements of a list object by an arbitrary comparison function.
    `list' specifies the list object.
    `cmp' specifies the pointer to the comparison function.  The structure TCLISTDATUM has the
    member "ptr" which is the pointer to the region of the element, and the member "size" which is
    the size of the region. */
 void tclistsortex(TCLIST* list, ListCmp cmp);


 /* Invert elements of a list object.
    `list' specifies the list object. */
 void tclistinvert(TCLIST* list);


 /* Perform formatted output into a list object.
    `list' specifies the list object.
    `format' specifies the printf-like format string.  The conversion character `%' can be used
    with such flag characters as `s', `d', `o', `u', `x', `X', `c', `e', `E', `f', `g', `G', `@',
    `?', `b', and `%'.  `@' works as with `s' but escapes meta characters of XML.  `?' works as
    with `s' but escapes meta characters of URL.  `b' converts an integer to the string as binary
    numbers.  The other conversion character work as with each original.
    The other arguments are used according to the format string. */
 void tclistprintf(TCLIST* list, char* format, ...);
