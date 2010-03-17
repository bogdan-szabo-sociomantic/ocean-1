module ocean.db.tokyocabinet.c.tcutil;


/*************************************************************************************************
 * basic utilities (for experts)
 *************************************************************************************************/

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



/* type of structure for a hash database */
struct TCHDB 
{                         
    void *mmtx;                                	/* mutex for method */
    void *rmtxs;                               	/* mutexes for records */
    void *dmtx;                                	/* mutex for the while database */
    void *tmtx;                                	/* mutex for transaction */
    void *wmtx;                                	/* mutex for write ahead logging */
    void *eckey;                               	/* key for thread specific error code */
    char *rpath;                               	/* real path for locking */
    ubyte type;                                	/* database type */
    ubyte flags;                               	/* additional flags */
    ulong bnum;                                	/* number of the bucket array */
    ubyte apow;                                	/* power of record alignment */
    ubyte fpow;                                	/* power of free block pool number */
    ubyte opts;                                	/* options */
    char *path;                                	/* path of the database file */
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
    void *fbpool;                              	/* free block pool */
    int fbpnum;                                	/* number of the free block pool */
    int fbpmis;                                	/* number of missing retrieval of the free block pool */
    bool async;                                	/* whether asynchronous storing is called */
    TCXSTR* drpool;                            	/* delayed record pool */
    TCXSTR* drpdef;                            	/* deferred records of the delayed record pool */
    ulong drpoff;                              	/* offset of the delayed record pool */
    TCMDB *recc;                               	/* cache for records */
    uint rcnum;                                	/* maximum number of cached records */
    TCCODEC enc;                               	/* pointer to the encoding function */
    void *encop;                               	/* opaque object for the encoding functions */
    TCCODEC dec;                               	/* pointer to the decoding function */
    void *decop;                               	/* opaque object for the decoding functions */
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
  
  												
enum
{                                   			/* enumeration for additional flags */
	HDBFOPEN = 1 << 0,                     		/* whether opened */
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

enum HDBOMODE : int								/* enumeration for open modes */
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
    void *cmpop;                               	/* opaque object for the comparison function */
};



struct TCNDB									/* type of structure for a on-memory tree database */
{                         
    void *mmtx;                                	/* mutex for method */
    TCTREE *tree;                              	/* internal tree object */
};


struct TCXSTR									/* type of structure for an extensible string object */
{                         
    char *ptr;                                 	/* pointer to the region */
    int size;                                  	/* size of the region */
    int asize;                                 	/* size of the allocated region */
};


struct TCLISTDATUM								/* type of structure for an element of a list */ 
{                  
    char*   ptr;                               	/* pointer to the region */
    int     size;                              	/* size of the effective region */
} ;



struct TCLIST 									/* type of structure for an array list */
{                         
    TCLISTDATUM* array;                        	/* array of data */
    int          anum;                         	/* number of the elements of the array */
    int          start;                        	/* start index of used elements */
    int          num;                          	/* number of used elements */
};


enum TCHERRCODE : int							/* enumeration for error codes */
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

