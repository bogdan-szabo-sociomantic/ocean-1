module ocean.db.tokyocabinet.c.tcutil;


/*************************************************************************************************
 * basic utilities (for experts)
 *************************************************************************************************/

extern (C)
{
/* type of the pointer to a comparison function.
   `aptr' specifies the pointer to the region of one key.
   `asiz' specifies the size of the region of one key.
   `bptr' specifies the pointer to the region of the other key.
   `bsiz' specifies the size of the region of the other key.
   `op' specifies the pointer to the optional opaque object.
   The return value is positive if the former is big, negative if the latter is big, 0 if both
   are equivalent. */
//    int (*TCCMP)(char* aptr, int asiz, char* bptr, int bsiz, void* op);
alias int function (char* aptr, int asiz, char* bptr, int bsiz, void* op) TCCMP;

/* type of the pointer to a encoding or decoding function.
   `ptr' specifies the pointer to the region.
   `size' specifies the size of the region.
   `sp' specifies the pointer to the variable into which the size of the region of the return
   value is assigned.
   `op' specifies the pointer to the optional opaque object.
   If successful, the return value is the pointer to the result object allocated with `malloc'
   call, else, it is `NULL'. */
//    void* (*TCCODEC)(void* ptr, int size, int*sp, void* op);
alias void* function (void* ptr, int size, int*sp, void* op) TCCODEC;

/* type of the pointer to a callback function to process record duplication.
   `vbuf' specifies the pointer to the region of the value.
   `vsiz' specifies the size of the region of the value.
   `sp' specifies the pointer to the variable into which the size of the region of the return
   value is assigned.
   `op' specifies the pointer to the optional opaque object.
   The return value is the pointer to the result object allocated with `malloc'.  It is
   released by the caller.  If it is `NULL', the record is not modified. */
//    void* (*TCPDPROC)(void* vbuf, int vsiz, int* sp, void* op);
alias void* function (void* vbuf, int vsiz, int* sp, void* op) TCPDPROC;

/* type of the pointer to a iterator function.
   `kbuf' specifies the pointer to the region of the key.
   `ksiz' specifies the size of the region of the key.
   `vbuf' specifies the pointer to the region of the value.
   `vsiz' specifies the size of the region of the value.
   `op' specifies the pointer to the optional opaque object.
   The return value is true to continue iteration or false to stop iteration. */
//    bool (*TCITER)(void* kbuf, int ksiz, void* vbuf, int vsiz, void* op);
alias bool function (void* kbuf, int ksiz, void* vbuf, int vsiz, void* op) TCITER;  


// List item comparison callback function used in tclistsortex
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


} // extern (C)


/* type of structure for a hash database */
struct TCHDB 
{                         
    void* mmtx;                                	/* mutex for method */
    void* rmtxs;                               	/* mutexes for records */
    void* dmtx;                                	/* mutex for the while database */
    void* tmtx;                                	/* mutex for transaction */
    void* wmtx;                                	/* mutex for write ahead logging */
    void* eckey;                               	/* key for thread specific error code */
    char* rpath;                               	/* real path for locking */
    ubyte type;                                	/* database type */
    ubyte flags;                               	/* additional flags */
    ulong bnum;                                	/* number of the bucket array */
    ubyte apow;                                	/* power of record alignment */
    ubyte fpow;                                	/* power of free block pool number */
    ubyte opts;                                	/* options */
    char* path;                                	/* path of the database file */
    int fd;                                    	/* file descriptor of the database file */
    uint omode;                                	/* open mode */
    ulong rnum;                                	/* number of the records */
    ulong fsiz;                                	/* size of the database file */
    ulong frec;                                	/* offset of the first record */
    ulong dfcur;                               	/* offset of the cursor for defragmentation */
    ulong iter;                                	/* offset of the iterator */
    char* map;                                 	/* pointer to the mapped memory */
    ulong msiz;                                	/* size of the mapped memory */
    ulong xmsiz;                               	/* size of the extra mapped memory */
    ulong xfsiz;                               	/* extra size of the file for mapped memory */
    uint* ba32;                                	/* 32-bit bucket array */
    ulong* ba64;                               	/* 64-bit bucket array */
    uint _align;                                /* record alignment */
    uint runit;                                	/* record reading unit */
    bool zmode;                                	/* whether compression is used */
    int fbpmax;                                	/* maximum number of the free block pool */
    void* fbpool;                              	/* free block pool */
    int fbpnum;                                	/* number of the free block pool */
    int fbpmis;                                	/* number of missing retrieval of the free block pool */
    bool async;                                	/* whether asynchronous storing is called */
    TCXSTR* drpool;                            	/* delayed record pool */
    TCXSTR* drpdef;                            	/* deferred records of the delayed record pool */
    ulong drpoff;                              	/* offset of the delayed record pool */
    TCMDB *recc;                               	/* cache for records */
    uint rcnum;                                	/* maximum number of cached records */
    TCCODEC enc;                               	/* pointer to the encoding function */
    void* encop;                               	/* opaque object for the encoding functions */
    TCCODEC dec;                               	/* pointer to the decoding function */
    void* decop;                               	/* opaque object for the decoding functions */
    int ecode;                                 	/* last happened error code */
    bool fatal;                                	/* whether a fatal error occured */
    ulong inode;                               	/* inode number */
    ulong mtime;                               	/* modification time */
    uint dfunit;                               	/* unit step number of auto defragmentation */
    uint dfcnt;                                	/* counter of auto defragmentation */
    bool tran;                                 	/* whether in the transaction */
    int walfd;                                 	/* file descriptor of write ahead logging */
    ulong walend;                              	/* end offset of write ahead logging */
    int dbgfd;                                 	/* file descriptor for debugging */
    ulong cnt_writerec;                        	/* tesing counter for record write times */
    ulong cnt_reuserec;                        	/* tesing counter for record reuse times */
    ulong cnt_moverec;                         	/* tesing counter for record move times */
    ulong cnt_readrec;                         	/* tesing counter for record read times */
    ulong cnt_searchfbp;                       	/* tesing counter for FBP search times */
    ulong cnt_insertfbp;                       	/* tesing counter for FBP insert times */
    ulong cnt_splicefbp;                       	/* tesing counter for FBP splice times */
    ulong cnt_dividefbp;                       	/* tesing counter for FBP divide times */
    ulong cnt_mergefbp;                        	/* tesing counter for FBP merge times */
    ulong cnt_reducefbp;                       	/* tesing counter for FBP reduce times */
    ulong cnt_appenddrp;                       	/* tesing counter for DRP append times */
    ulong cnt_deferdrp;                        	/* tesing counter for DRP defer times */
    ulong cnt_flushdrp;                        	/* tesing counter for DRP flush times */
    ulong cnt_adjrecc;                         	/* tesing counter for record cache adjust times */
    ulong cnt_defrag;                          	/* tesing counter for defragmentation times */
    ulong cnt_shiftrec;                        	/* tesing counter for record shift times */
    ulong cnt_trunc;                           	/* tesing counter for truncation times */
  } ;
  

enum HDBFLAGS                                   /* enumeration for additional flags */
{                                   			
	HDBFOPEN  = 1 << 0,                   		/* whether opened */
	HDBFFATAL = 1 << 1                     		/* whetehr with fatal error */
};

enum HDBOPT : ubyte								/* enumeration for tuning options */
{                                   			
    HDBTLARGE   = 1 << 0,                 		/* use 64-bit bucket array */
    HDBTDEFLATE = 1 << 1,                 		/* compress each record with Deflate */
    HDBTBZIP    = 1 << 2,                 		/* compress each record with BZIP2 */
    HDBTTCBS    = 1 << 3,                 		/* compress each record with TCBS */
    HDBTEXCODEC = 1 << 4                  		/* compress each record with custom functions */
};

enum HDBOMODE : int						       /* enumeration for open modes */
{                                   		
    HDBOREADER = 1 << 0,                  		/* open as a reader */
    HDBOWRITER = 1 << 1,                  		/* open as a writer */
    HDBOCREAT  = 1 << 2,                  		/* writer creating */
    HDBOTRUNC  = 1 << 3,                  		/* writer truncating */
    HDBONOLCK  = 1 << 4,                  		/* open without locking */
    HDBOLCKNB  = 1 << 5,                  		/* lock without blocking */
    HDBOTSYNC  = 1 << 6                   		/* synchronize every transaction */
};
  

alias _TCMAPREC TCMAPREC;


struct _TCMAPREC								/* type of structure for an element of a map */
{               
    int ksiz;                                  	/* size of the region of the key */
    int vsiz;                                  	/* size of the region of the value */
    _TCMAPREC* left;                           	/* pointer to the left child */
    _TCMAPREC* right;                          	/* pointer to the right child */
    _TCMAPREC* prev;                           	/* pointer to the previous element */
    _TCMAPREC* next;                           	/* pointer to the next element */
};



struct TCMAP									/* type of structure for a map */
{                         
    TCMAPREC **buckets;                        	/* bucket array */
    TCMAPREC *first;                           	/* pointer to the first element */
    TCMAPREC *last;                            	/* pointer to the last element */
    TCMAPREC *cur;                             	/* pointer to the current element */
    uint  bnum;                                	/* number of buckets */
    ulong rnum;                                	/* number of records */
    ulong msiz;                                	/* total size of records */
};
  

struct TCMDB
{                                              	/* type of structure for a on-memory hash database */
    void**  mmtxs;                             	/* mutexes for method */
    void*   imtx;                              	/* mutex for iterator */
    TCMAP** maps;                              	/* internal map objects */
    int iter;                                  	/* index of maps for the iterator */
};


alias _TCTREEREC TCTREEREC;

struct _TCTREEREC 								/* type of structure for an element of a tree */
{              
    int ksiz;                                  	/* size of the region of the key */
    int vsiz;                                  	/* size of the region of the value */
    _TCTREEREC *left;                          	/* pointer to the left child */
    _TCTREEREC *right;                         	/* pointer to the right child */
};

struct TCTREE 									/* type of structure for a tree */
{                         
    TCTREEREC *root;                           	/* pointer to the root element */
    TCTREEREC *cur;                            	/* pointer to the current element */
    ulong rnum;                                	/* number of records */
    ulong msiz;                                	/* total size of records */
    TCCMP cmp;                                 	/* pointer to the comparison function */
    void* cmpop;                               	/* opaque object for the comparison function */
};



struct TCNDB									/* type of structure for a on-memory tree database */
{                         
    void* mmtx;                                	/* mutex for method */
    TCTREE *tree;                              	/* internal tree object */
};


struct TCXSTR									/* type of structure for an extensible string object */
{                         
    char* ptr;                                 	/* pointer to the region */
    int size;                                  	/* size of the region */
    int asize;                                 	/* size of the allocated region */
};


struct TCLISTDATUM								/* type of structure for an element of a list */ 
{                  
    char*   ptr;                               	/* pointer to the region */
    int     size;                              	/* size of the effective region */
};



struct TCLIST 									/* type of structure for an array list */
{                         
    TCLISTDATUM* array;                        	/* array of data */
    int          anum;                         	/* number of the elements of the array */
    int          start;                        	/* start index of used elements */
    int          num;                          	/* number of used elements */
};


enum TCERRCODE : int							/* enumeration for error codes */
{                                       
    TCESUCCESS,                            		/* success */
    TCETHREAD,                             		/* threading error */
    TCEINVALID,                            		/* invalid operation */
    TCENOFILE,                             		/* file not found */
    TCENOPERM,                             		/* no permission */
    TCEMETA,                               		/* invalid meta data */
    TCERHEAD,                              		/* invalid record header */
    TCEOPEN,                               		/* open error */
    TCECLOSE,                              		/* close error */
    TCETRUNC,                              		/* trunc error */
    TCESYNC,                               		/* sync error */
    TCESTAT,                               		/* stat error */
    TCESEEK,                               		/* seek error */
    TCEREAD,                               		/* read error */
    TCEWRITE,                              		/* write error */
    TCEMMAP,                               		/* mmap error */
    TCELOCK,                               		/* lock error */
    TCEUNLINK,                             		/* unlink error */
    TCERENAME,                             		/* rename error */
    TCEMKDIR,                              		/* mkdir error */
    TCERMDIR,                              		/* rmdir error */
    TCEKEEP,                               		/* existing record */
    TCENOREC,                              		/* no record found */
    TCEMISC = 9999                         		/* miscellaneous error */
};

