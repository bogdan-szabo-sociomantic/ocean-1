module ocean.db.tokyocabinet.c.tcutil;

extern (C):

/*************************************************************************************************
 * Basic utilities (for experts)
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




enum TCERRCODE : int                            /* enumeration for error codes */
{
    TCESUCCESS,                                 /* success */
    TCETHREAD,                                  /* threading error */
    TCEINVALID,                                 /* invalid operation */
    TCENOFILE,                                  /* file not found */
    TCENOPERM,                                  /* no permission */
    TCEMETA,                                    /* invalid meta data */
    TCERHEAD,                                   /* invalid record header */
    TCEOPEN,                                    /* open error */
    TCECLOSE,                                   /* close error */
    TCETRUNC,                                   /* trunc error */
    TCESYNC,                                    /* sync error */
    TCESTAT,                                    /* stat error */
    TCESEEK,                                    /* seek error */
    TCEREAD,                                    /* read error */
    TCEWRITE,                                   /* write error */
    TCEMMAP,                                    /* mmap error */
    TCELOCK,                                    /* lock error */
    TCEUNLINK,                                  /* unlink error */
    TCERENAME,                                  /* rename error */
    TCEMKDIR,                                   /* mkdir error */
    TCERMDIR,                                   /* rmdir error */
    TCEKEEP,                                    /* existing record */
    TCENOREC,                                   /* no record found */
    TCEMISC = 9999                              /* miscellaneous error */
};

enum TCKWGEN                             /* enumeration for KWIC generator */
{
  TCKWMUTAB = 1 << 0,                    /* mark up by tabs */
  TCKWMUCTRL = 1 << 1,                   /* mark up by control characters */
  TCKWMUBRCT = 1 << 2,                   /* mark up by brackets */
  TCKWNOOVER = 1 << 24,                  /* no overlap */
  TCKWPULEAD = 1 << 25                   /* pick up the lead string */
};


/+
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
+/
