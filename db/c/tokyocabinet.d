module c.tokyocabinet;

/**
 * Pure C tokio cabinet API library
 * Tokio Cabinet, http://tokyocabinet.sourceforge.net/
 *
 * API notes
 * ------------
 * 
 */


extern (C):

    
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
//int (*TCCMP)(char* aptr, int asiz, char* bptr, int bsiz, void* op);
alias int function (char* aptr, int asiz, char* bptr, int bsiz, void* op) TCCMP;

/* type of the pointer to a encoding or decoding function.
   `ptr' specifies the pointer to the region.
   `size' specifies the size of the region.
   `sp' specifies the pointer to the variable into which the size of the region of the return
   value is assigned.
   `op' specifies the pointer to the optional opaque object.
   If successful, the return value is the pointer to the result object allocated with `malloc'
   call, else, it is `NULL'. */
//void* (*TCCODEC)(void* ptr, int size, int*sp, void* op);
alias void* function (void* ptr, int size, int*sp, void* op) TCCODEC;

/* type of the pointer to a callback function to process record duplication.
   `vbuf' specifies the pointer to the region of the value.
   `vsiz' specifies the size of the region of the value.
   `sp' specifies the pointer to the variable into which the size of the region of the return
   value is assigned.
   `op' specifies the pointer to the optional opaque object.
   The return value is the pointer to the result object allocated with `malloc'.  It is
   released by the caller.  If it is `NULL', the record is not modified. */
//void* (*TCPDPROC)(void* vbuf, int vsiz, int* sp, void* op);
alias void* function (void* vbuf, int vsiz, int* sp, void* op) TCPDPROC;

/* type of the pointer to a iterator function.
   `kbuf' specifies the pointer to the region of the key.
   `ksiz' specifies the size of the region of the key.
   `vbuf' specifies the pointer to the region of the value.
   `vsiz' specifies the size of the region of the value.
   `op' specifies the pointer to the optional opaque object.
   The return value is true to continue iteration or false to stop iteration. */
//bool (*TCITER)(void* kbuf, int ksiz, void* vbuf, int vsiz, void* op);
alias bool function (void* kbuf, int ksiz, void* vbuf, int vsiz, void* op) TCITER;  
    
alias _TCMAPREC TCMAPREC;

/* type of structure for an element of a map */
struct _TCMAPREC {               
    int ksiz;                                  /* size of the region of the key */
    int vsiz;                                  /* size of the region of the value */
    _TCMAPREC* left;                           /* pointer to the left child */
    _TCMAPREC* right;                          /* pointer to the right child */
    _TCMAPREC* prev;                           /* pointer to the previous element */
    _TCMAPREC* next;                           /* pointer to the next element */
};
  
  
/* type of structure for a map */
struct TCMAP
{                         
    TCMAPREC **buckets;                        /* bucket array */
    TCMAPREC *first;                           /* pointer to the first element */
    TCMAPREC *last;                            /* pointer to the last element */
    TCMAPREC *cur;                             /* pointer to the current element */
    uint  bnum;                                /* number of buckets */
    ulong rnum;                                /* number of records */
    ulong msiz;                                /* total size of records */
};
  
    
struct TCMDB
{                                              /* type of structure for a on-memory hash database */
    void**  mmtxs;                             /* mutexes for method */
    void*   imtx;                              /* mutex for iterator */
    TCMAP** maps;                              /* internal map objects */
    int iter;                                  /* index of maps for the iterator */
};


alias _TCTREEREC TCTREEREC;


/* type of structure for an element of a tree */
struct _TCTREEREC 
{              
    int ksiz;                                  /* size of the region of the key */
    int vsiz;                                  /* size of the region of the value */
    _TCTREEREC *left;                          /* pointer to the left child */
    _TCTREEREC *right;                         /* pointer to the right child */
};


/* type of structure for a tree */
struct TCTREE 
{                         
    TCTREEREC *root;                           /* pointer to the root element */
    TCTREEREC *cur;                            /* pointer to the current element */
    ulong rnum;                                /* number of records */
    ulong msiz;                                /* total size of records */
    TCCMP cmp;                                 /* pointer to the comparison function */
    void *cmpop;                               /* opaque object for the comparison function */
} ;

  
/* type of structure for a on-memory tree database */
struct TCNDB
{                         
    void *mmtx;                                /* mutex for method */
    TCTREE *tree;                              /* internal tree object */
};


/* type of structure for an extensible string object */
struct TCXSTR
{                         
    char *ptr;                                 /* pointer to the region */
    int size;                                  /* size of the region */
    int asize;                                 /* size of the allocated region */
};


/* type of structure for a hash database */
struct TCHDB 
{                         
    void *mmtx;                                /* mutex for method */
    void *rmtxs;                               /* mutexes for records */
    void *dmtx;                                /* mutex for the while database */
    void *tmtx;                                /* mutex for transaction */
    void *wmtx;                                /* mutex for write ahead logging */
    void *eckey;                               /* key for thread specific error code */
    char *rpath;                               /* real path for locking */
    ubyte type;                                /* database type */
    ubyte flags;                               /* additional flags */
    ulong bnum;                                /* number of the bucket array */
    ubyte apow;                                /* power of record alignment */
    ubyte fpow;                                /* power of free block pool number */
    ubyte opts;                                /* options */
    char *path;                                /* path of the database file */
    int fd;                                    /* file descriptor of the database file */
    uint omode;                                /* open mode */
    ulong rnum;                                /* number of the records */
    ulong fsiz;                                /* size of the database file */
    ulong frec;                                /* offset of the first record */
    ulong dfcur;                               /* offset of the cursor for defragmentation */
    ulong iter;                                /* offset of the iterator */
    char* map;                                 /* pointer to the mapped memory */
    ulong msiz;                                /* size of the mapped memory */
    ulong xmsiz;                               /* size of the extra mapped memory */
    ulong xfsiz;                               /* extra size of the file for mapped memory */
    uint* ba32;                                /* 32-bit bucket array */
    ulong* ba64;                               /* 64-bit bucket array */
    uint _align;                                /* record alignment */
    uint runit;                                /* record reading unit */
    bool zmode;                                /* whether compression is used */
    int fbpmax;                                /* maximum number of the free block pool */
    void *fbpool;                              /* free block pool */
    int fbpnum;                                /* number of the free block pool */
    int fbpmis;                                /* number of missing retrieval of the free block pool */
    bool async;                                /* whether asynchronous storing is called */
    TCXSTR* drpool;                            /* delayed record pool */
    TCXSTR* drpdef;                            /* deferred records of the delayed record pool */
    ulong drpoff;                              /* offset of the delayed record pool */
    TCMDB *recc;                               /* cache for records */
    uint rcnum;                                /* maximum number of cached records */
    TCCODEC enc;                               /* pointer to the encoding function */
    void *encop;                               /* opaque object for the encoding functions */
    TCCODEC dec;                               /* pointer to the decoding function */
    void *decop;                               /* opaque object for the decoding functions */
    int ecode;                                 /* last happened error code */
    bool fatal;                                /* whether a fatal error occured */
    ulong inode;                               /* inode number */
    ulong mtime;                               /* modification time */
    uint dfunit;                               /* unit step number of auto defragmentation */
    uint dfcnt;                                /* counter of auto defragmentation */
    bool tran;                                 /* whether in the transaction */
    int walfd;                                 /* file descriptor of write ahead logging */
    ulong walend;                              /* end offset of write ahead logging */
    int dbgfd;                                 /* file descriptor for debugging */
    ulong cnt_writerec;                        /* tesing counter for record write times */
    ulong cnt_reuserec;                        /* tesing counter for record reuse times */
    ulong cnt_moverec;                         /* tesing counter for record move times */
    ulong cnt_readrec;                         /* tesing counter for record read times */
    ulong cnt_searchfbp;                       /* tesing counter for FBP search times */
    ulong cnt_insertfbp;                       /* tesing counter for FBP insert times */
    ulong cnt_splicefbp;                       /* tesing counter for FBP splice times */
    ulong cnt_dividefbp;                       /* tesing counter for FBP divide times */
    ulong cnt_mergefbp;                        /* tesing counter for FBP merge times */
    ulong cnt_reducefbp;                       /* tesing counter for FBP reduce times */
    ulong cnt_appenddrp;                       /* tesing counter for DRP append times */
    ulong cnt_deferdrp;                        /* tesing counter for DRP defer times */
    ulong cnt_flushdrp;                        /* tesing counter for DRP flush times */
    ulong cnt_adjrecc;                         /* tesing counter for record cache adjust times */
    ulong cnt_defrag;                          /* tesing counter for defragmentation times */
    ulong cnt_shiftrec;                        /* tesing counter for record shift times */
    ulong cnt_trunc;                           /* tesing counter for truncation times */
  } ;


/* type of structure for a B+ tree database */
struct TCBDB 
{                         
      void *mmtx;                              /* mutex for method */
      void *cmtx;                              /* mutex for cache */
      TCHDB *hdb;                              /* internal database object */
      char *opaque;                            /* opaque buffer */
      bool open;                               /* whether the internal database is opened */
      bool wmode;                              /* whether to be writable */
      uint lmemb;                              /* number of members in each leaf */
      uint nmemb;                              /* number of members in each node */
      ubyte opts;                              /* options */
      ulong root;                              /* ID number of the root page */
      ulong first;                             /* ID number of the first leaf */
      ulong last;                              /* ID number of the last leaf */
      ulong lnum;                              /* number of leaves */
      ulong nnum;                              /* number of nodes */
      ulong rnum;                              /* number of records */
      TCMAP* leafc;                            /* cache for leaves */
      TCMAP* nodec;                            /* cache for nodes */
      TCCMP cmp;                               /* pointer to the comparison function */
      void *cmpop;                             /* opaque object for the comparison function */
      uint lcnum;                              /* maximum number of cached leaves */
      uint ncnum;                              /* maximum number of cached nodes */
      uint lsmax;                              /* maximum size of each leaf */
      uint lschk;                              /* counter for leaf size checking */
      ulong capnum;                            /* capacity number of records */
      ulong *hist;                             /* history array of visited nodes */
      int hnum;                                /* number of element of the history array */
      ulong hleaf;                             /* ID number of the leaf referred by the history */
      ulong lleaf;                             /* ID number of the last visited leaf */
      bool tran;                               /* whether in the transaction */
      char *rbopaque;                          /* opaque for rollback */
      ulong clock;                             /* logical clock */
      ulong cnt_saveleaf;                      /* tesing counter for leaf save times */
      ulong cnt_loadleaf;                      /* tesing counter for leaf load times */
      ulong cnt_killleaf;                      /* tesing counter for leaf kill times */
      ulong cnt_adjleafc;                      /* tesing counter for node cache adjust times */
      ulong cnt_savenode;                      /* tesing counter for node save times */
      ulong cnt_loadnode;                      /* tesing counter for node load times */
      ulong cnt_adjnodec;                      /* tesing counter for node cache adjust times */
};


/* type of structure for a fixed-length database */
struct TCFDB 
{                             
    void *mmtx;                                /* mutex for method */
    void *amtx;                                /* mutex for attribute */
    void *rmtxs;                               /* mutexes for records */
    void *tmtx;                                /* mutex for transaction */
    void *wmtx;                                /* mutex for write ahead logging */
    void *eckey;                               /* key for thread specific error code */
    char *rpath;                               /* real path for locking */
    ubyte type;                                /* database type */
    ubyte flags;                               /* additional flags */
    uint width;                                /* width of the value of each record */
    ulong limsiz;                              /* limit size of the file */
    int wsiz;                                  /* size of the width region */
    int rsiz;                                  /* size of each record */
    ulong limid;                               /* limit ID number */
    char *path;                                /* path of the database file */
    int fd;                                    /* file descriptor of the database file */
    uint omode;                                /* open mode */
    ulong rnum;                                /* number of the records */
    ulong fsiz;                                /* size of the database file */
    ulong min;                                 /* minimum ID number */
    ulong max;                                 /* maximum ID number */
    ulong iter;                                /* ID number of the iterator */
    char *map;                                 /* pointer to the mapped memory */
    ubyte* array;                              /* pointer to the array region */
    int ecode;                                 /* last happened error code */
    bool fatal;                                /* whether a fatal error occured */
    ulong inode;                               /* inode number */
    long mtime;                                /* modification time */
    bool tran;                                 /* whether in the transaction */
    int walfd;                                 /* file descriptor of write ahead logging */
    ulong walend;                              /* end offset of write ahead logging */
    int dbgfd;                                 /* file descriptor for debugging */
    long cnt_writerec;                         /* tesing counter for record write times */
    long cnt_readrec;                          /* tesing counter for record read times */
    long cnt_truncfile;                        /* tesing counter for file truncate times */
};


/* type of structure for a column index */
struct TDBIDX
{                         
    char *name;                                /* column name */
    int type;                                  /* data type */
    void *db;                                  /* internal database object */
    void *cc;                                  /* internal cache object */
};
 

/* type of structure for a table database */
struct TCTDB 
{                         
    void *mmtx;                                /* mutex for method */
    TCHDB *hdb;                                /* internal database object */
    bool open;                                 /* whether the internal database is opened */
    bool wmode;                                /* whether to be writable */
    ubyte opts;                                /* options */
    int lcnum;                                 /* max number of cached leaves */
    int ncnum;                                 /* max number of cached nodes */
    long iccmax;                               /* maximum size of the inverted cache */
    double iccsync;                            /* synchronization ratio of the inverted cache */
    TDBIDX* idxs;                              /* column indices */
    int inum;                                  /* number of column indices */
    bool tran;                                 /* whether in the transaction */
};


/* type of structure for an abstract database */
struct TCADB 
{                         
    int     omode;                             /* open mode */
    TCMDB*  mdb;                               /* on-memory hash database object */
    TCNDB*  ndb;                               /* on-memory tree database object */
    TCHDB*  hdb;                               /* hash database object */
    TCBDB*  bdb;                               /* B+ tree database object */
    TCFDB*  fdb;                               /* fixed-length databae object */
    TCTDB*  tdb;                               /* table database object */
    long    capnum;                            /* capacity number of records */
    long    capsiz;                            /* capacity size of using memory */
    uint    capcnt;                            /* count for capacity check */
    BDBCUR* cur;                               /* cursor of B+ tree */
    void*   skel;                              /* skeleton database */
} ;


/* type of structure for a B+ tree cursor */
struct BDBCUR
{                         
    TCBDB* bdb;                               /* database object */
    ulong clock;                              /* logical clock */
    ulong id;                                 /* ID number of the leaf */
    int kidx;                                 /* number of the key */
    int vidx;                                 /* number of the value */
};


/* type of structure for an element of a list */
struct TCLISTDATUM 
{                  
    char*   ptr;                               /* pointer to the region */
    int     size;                              /* size of the effective region */
} ;


/* type of structure for an array list */
struct TCLIST 
{                         
    TCLISTDATUM* array;                        /* array of data */
    int          anum;                         /* number of the elements of the array */
    int          start;                        /* start index of used elements */
    int          num;                          /* number of used elements */
};
  

/* enumeration for open modes */
enum 
{
    ADBOVOID,                                  /* not opened */
    ADBOMDB,                                   /* on-memory hash database */
    ADBONDB,                                   /* on-memory tree database */
    ADBOHDB,                                   /* hash database */
    ADBOBDB,                                   /* B+ tree database */
    ADBOFDB,                                   /* fixed-length database */
    ADBOTDB,                                   /* table database */
    ADBOSKEL                                   /* skeleton database */
};


/* Create an abstract database object.
   The return value is the new abstract database object. */
//TCADB* tcadbnew(void);
TCADB* tcadbnew();

/* Delete an abstract database object.
   `adb' specifies the abstract database object. */
void tcadbdel(TCADB* adb);


/* Open an abstract database.
   `adb' specifies the abstract database object.
   `name' specifies the name of the database.  If it is "*", the database will be an on-memory
   hash database.  If it is "+", the database will be an on-memory tree database.  If its suffix
   is ".tch", the database will be a hash database.  If its suffix is ".tcb", the database will
   be a B+ tree database.  If its suffix is ".tcf", the database will be a fixed-length database.
   If its suffix is ".tct", the database will be a table database.  Otherwise, this function
   fails.  Tuning parameters can trail the name, separated by "#".  Each parameter is composed of
   the name and the value, separated by "=".  On-memory hash database supports "bnum", "capnum",
   and "capsiz".  On-memory tree database supports "capnum" and "capsiz".  Hash database supports
   "mode", "bnum", "apow", "fpow", "opts", "rcnum", "xmsiz", and "dfunit".  B+ tree database
   supports "mode", "lmemb", "nmemb", "bnum", "apow", "fpow", "opts", "lcnum", "ncnum", "xmsiz",
   and "dfunit".  Fixed-length database supports "mode", "width", and "limsiz".  Table database
   supports "mode", "bnum", "apow", "fpow", "opts", "rcnum", "lcnum", "ncnum", "xmsiz", "dfunit",
   and "idx".
   If successful, the return value is true, else, it is false.
   The tuning parameter "capnum" specifies the capacity number of records.  "capsiz" specifies
   the capacity size of using memory.  Records spilled the capacity are removed by the storing
   order.  "mode" can contain "w" of writer, "r" of reader, "c" of creating, "t" of truncating,
   "e" of no locking, and "f" of non-blocking lock.  The default mode is relevant to "wc".
   "opts" can contains "l" of large option, "d" of Deflate option, "b" of BZIP2 option, and "t"
   of TCBS option.  "idx" specifies the column name of an index and its type separated by ":".
   For example, "casket.tch#bnum=1000000#opts=ld" means that the name of the database file is
   "casket.tch", and the bucket number is 1000000, and the options are large and Deflate. */
bool tcadbopen(TCADB *adb, char* name);


/* Close an abstract database object.
   `adb' specifies the abstract database object.
   If successful, the return value is true, else, it is false.
   Update of a database is assured to be written when the database is closed.  If a writer opens
   a database but does not close it appropriately, the database will be broken. */
bool tcadbclose(TCADB* adb);


/* Store a record into an abstract database object.
   `adb' specifies the abstract database object.
   `kbuf' specifies the pointer to the region of the key.
   `ksiz' specifies the size of the region of the key.
   `vbuf' specifies the pointer to the region of the value.
   `vsiz' specifies the size of the region of the value.
   If successful, the return value is true, else, it is false.
   If a record with the same key exists in the database, it is overwritten. */
bool tcadbput(TCADB* adb, void* kbuf, int ksiz, void* vbuf, int vsiz);


/* Store a string record into an abstract object.
   `adb' specifies the abstract database object.
   `kstr' specifies the string of the key.
   `vstr' specifies the string of the value.
   If successful, the return value is true, else, it is false.
   If a record with the same key exists in the database, it is overwritten. */
bool tcadbput2(TCADB* adb, char* kstr, char* vstr);


/* Store a new record into an abstract database object.
   `adb' specifies the abstract database object.
   `kbuf' specifies the pointer to the region of the key.
   `ksiz' specifies the size of the region of the key.
   `vbuf' specifies the pointer to the region of the value.
   `vsiz' specifies the size of the region of the value.
   If successful, the return value is true, else, it is false.
   If a record with the same key exists in the database, this function has no effect. */
bool tcadbputkeep(TCADB* adb, void* kbuf, int ksiz, void* vbuf, int vsiz);


/* Store a new string record into an abstract database object.
   `adb' specifies the abstract database object.
   `kstr' specifies the string of the key.
   `vstr' specifies the string of the value.
   If successful, the return value is true, else, it is false.
   If a record with the same key exists in the database, this function has no effect. */
bool tcadbputkeep2(TCADB* adb, char* kstr, char* vstr);


/* Concatenate a value at the end of the existing record in an abstract database object.
   `adb' specifies the abstract database object.
   `kbuf' specifies the pointer to the region of the key.
   `ksiz' specifies the size of the region of the key.
   `vbuf' specifies the pointer to the region of the value.
   `vsiz' specifies the size of the region of the value.
   If successful, the return value is true, else, it is false.
   If there is no corresponding record, a new record is created. */
bool tcadbputcat(TCADB* adb, void* kbuf, int ksiz, void* vbuf, int vsiz);


/* Concatenate a string value at the end of the existing record in an abstract database object.
   `adb' specifies the abstract database object.
   `kstr' specifies the string of the key.
   `vstr' specifies the string of the value.
   If successful, the return value is true, else, it is false.
   If there is no corresponding record, a new record is created. */
bool tcadbputcat2(TCADB* adb, char* kstr, char* vstr);


/* Remove a record of an abstract database object.
   `adb' specifies the abstract database object.
   `kbuf' specifies the pointer to the region of the key.
   `ksiz' specifies the size of the region of the key.
   If successful, the return value is true, else, it is false. */
bool tcadbout(TCADB* adb, void* kbuf, int ksiz);


/* Remove a string record of an abstract database object.
   `adb' specifies the abstract database object.
   `kstr' specifies the string of the key.
   If successful, the return value is true, else, it is false. */
bool tcadbout2(TCADB* adb, char* kstr);


/* Retrieve a record in an abstract database object.
   `adb' specifies the abstract database object.
   `kbuf' specifies the pointer to the region of the key.
   `ksiz' specifies the size of the region of the key.
   `sp' specifies the pointer to the variable into which the size of the region of the return
   value is assigned.
   If successful, the return value is the pointer to the region of the value of the corresponding
   record.  `NULL' is returned if no record corresponds.
   Because an additional zero code is appended at the end of the region of the return value,
   the return value can be treated as a character string.  Because the region of the return
   value is allocated with the `malloc' call, it should be released with the `free' call when
   it is no longer in use. */
void *tcadbget(TCADB* adb, void* kbuf, int ksiz, int* sp);


/* Retrieve a string record in an abstract database object.
   `adb' specifies the abstract database object.
   `kstr' specifies the string of the key.
   If successful, the return value is the string of the value of the corresponding record.
   `NULL' is returned if no record corresponds.
   Because the region of the return value is allocated with the `malloc' call, it should be
   released with the `free' call when it is no longer in use. */
char *tcadbget2(TCADB* adb, char* kstr);


/* Get the size of the value of a record in an abstract database object.
   `adb' specifies the abstract database object.
   `kbuf' specifies the pointer to the region of the key.
   `ksiz' specifies the size of the region of the key.
   If successful, the return value is the size of the value of the corresponding record, else,
   it is -1. */
int tcadbvsiz(TCADB* adb, void* kbuf, int ksiz);


/* Get the size of the value of a string record in an abstract database object.
   `adb' specifies the abstract database object.
   `kstr' specifies the string of the key.
   If successful, the return value is the size of the value of the corresponding record, else,
   it is -1. */
int tcadbvsiz2(TCADB* adb, char* kstr);


/* Initialize the iterator of an abstract database object.
   `adb' specifies the abstract database object.
   If successful, the return value is true, else, it is false.
   The iterator is used in order to access the key of every record stored in a database. */
bool tcadbiterinit(TCADB* adb);


/* Get the next key of the iterator of an abstract database object.
   `adb' specifies the abstract database object.
   `sp' specifies the pointer to the variable into which the size of the region of the return
   value is assigned.
   If successful, the return value is the pointer to the region of the next key, else, it is
   `NULL'.  `NULL' is returned when no record is to be get out of the iterator.
   Because an additional zero code is appended at the end of the region of the return value, the
   return value can be treated as a character string.  Because the region of the return value is
   allocated with the `malloc' call, it should be released with the `free' call when it is no
   longer in use.  It is possible to access every record by iteration of calling this function.
   It is allowed to update or remove records whose keys are fetched while the iteration.
   However, it is not assured if updating the database is occurred while the iteration.  Besides,
   the order of this traversal access method is arbitrary, so it is not assured that the order of
   storing matches the one of the traversal access. */
void *tcadbiternext(TCADB* adb, int *sp);


/* Get the next key string of the iterator of an abstract database object.
   `adb' specifies the abstract database object.
   If successful, the return value is the string of the next key, else, it is `NULL'.  `NULL' is
   returned when no record is to be get out of the iterator.
   Because the region of the return value is allocated with the `malloc' call, it should be
   released with the `free' call when it is no longer in use.  It is possible to access every
   record by iteration of calling this function.  However, it is not assured if updating the
   database is occurred while the iteration.  Besides, the order of this traversal access method
   is arbitrary, so it is not assured that the order of storing matches the one of the traversal
   access. */
char *tcadbiternext2(TCADB* adb);


/* Get forward matching keys in an abstract database object.
   `adb' specifies the abstract database object.
   `pbuf' specifies the pointer to the region of the prefix.
   `psiz' specifies the size of the region of the prefix.
   `max' specifies the maximum number of keys to be fetched.  If it is negative, no limit is
   specified.
   The return value is a list object of the corresponding keys.  This function does never fail.
   It returns an empty list even if no key corresponds.
   Because the object of the return value is created with the function `tclistnew', it should be
   deleted with the function `tclistdel' when it is no longer in use.  Note that this function
   may be very slow because every key in the database is scanned. */
TCLIST* tcadbfwmkeys(TCADB* adb, void* pbuf, int psiz, int max);


/* Get forward matching string keys in an abstract database object.
   `adb' specifies the abstract database object.
   `pstr' specifies the string of the prefix.
   `max' specifies the maximum number of keys to be fetched.  If it is negative, no limit is
   specified.
   The return value is a list object of the corresponding keys.  This function does never fail.
   It returns an empty list even if no key corresponds.
   Because the object of the return value is created with the function `tclistnew', it should be
   deleted with the function `tclistdel' when it is no longer in use.  Note that this function
   may be very slow because every key in the database is scanned. */
TCLIST* tcadbfwmkeys2(TCADB* adb, char* pstr, int max);


/* Add an integer to a record in an abstract database object.
   `adb' specifies the abstract database object.
   `kbuf' specifies the pointer to the region of the key.
   `ksiz' specifies the size of the region of the key.
   `num' specifies the additional value.
   If successful, the return value is the summation value, else, it is `INT_MIN'.
   If the corresponding record exists, the value is treated as an integer and is added to.  If no
   record corresponds, a new record of the additional value is stored. */
int tcadbaddint(TCADB* adb, void* kbuf, int ksiz, int num);


/* Add a real number to a record in an abstract database object.
   `adb' specifies the abstract database object.
   `kbuf' specifies the pointer to the region of the key.
   `ksiz' specifies the size of the region of the key.
   `num' specifies the additional value.
   If successful, the return value is the summation value, else, it is Not-a-Number.
   If the corresponding record exists, the value is treated as a real number and is added to.  If
   no record corresponds, a new record of the additional value is stored. */
double tcadbadddouble(TCADB* adb, void* kbuf, int ksiz, double num);


/* Synchronize updated contents of an abstract database object with the file and the device.
   `adb' specifies the abstract database object.
   If successful, the return value is true, else, it is false. */
bool tcadbsync(TCADB* adb);


/* Optimize the storage of an abstract database object.
   `adb' specifies the abstract database object.
   `params' specifies the string of the tuning parameters, which works as with the tuning
   of parameters the function `tcadbopen'.  If it is `NULL', it is not used.
   If successful, the return value is true, else, it is false.
   This function is useful to reduce the size of the database storage with data fragmentation by
   successive updating. */
bool tcadboptimize(TCADB* adb, char* params);


/* Remove all records of an abstract database object.
   `adb' specifies the abstract database object.
   If successful, the return value is true, else, it is false. */
bool tcadbvanish(TCADB* adb);


/* Copy the database file of an abstract database object.
   `adb' specifies the abstract database object.
   `path' specifies the path of the destination file.  If it begins with `@', the trailing
   substring is executed as a command line.
   If successful, the return value is true, else, it is false.  False is returned if the executed
   command returns non-zero code.
   The database file is assured to be kept synchronized and not modified while the copying or
   executing operation is in progress.  So, this function is useful to create a backup file of
   the database file. */
bool tcadbcopy(TCADB* adb, char* path);


/* Begin the transaction of an abstract database object.
   `adb' specifies the abstract database object.
   If successful, the return value is true, else, it is false.
   The database is locked by the thread while the transaction so that only one transaction can be
   activated with a database object at the same time.  Thus, the serializable isolation level is
   assumed if every database operation is performed in the transaction.  All updated regions are
   kept track of by write ahead logging while the transaction.  If the database is closed during
   transaction, the transaction is aborted implicitly. */
bool tcadbtranbegin(TCADB* adb);


/* Commit the transaction of an abstract database object.
   `adb' specifies the abstract database object.
   If successful, the return value is true, else, it is false.
   Update in the transaction is fixed when it is committed successfully. */
bool tcadbtrancommit(TCADB* adb);


/* Abort the transaction of an abstract database object.
   `adb' specifies the abstract database object.
   If successful, the return value is true, else, it is false.
   Update in the transaction is discarded when it is aborted.  The state of the database is
   rollbacked to before transaction. */
bool tcadbtranabort(TCADB* adb);


/* Get the file path of an abstract database object.
   `adb' specifies the abstract database object.
   The return value is the path of the database file or `NULL' if the object does not connect to
   any database.  "*" stands for on-memory hash database.  "+" stands for on-memory tree
   database. */
char* tcadbpath(TCADB* adb);


/* Get the number of records of an abstract database object.
   `adb' specifies the abstract database object.
   The return value is the number of records or 0 if the object does not connect to any database
   instance. */
ulong tcadbrnum(TCADB* adb);


/* Get the size of the database of an abstract database object.
   `adb' specifies the abstract database object.
   The return value is the size of the database or 0 if the object does not connect to any
   database instance. */
ulong tcadbsize(TCADB* adb);


/* Call a versatile function for miscellaneous operations of an abstract database object.
   `adb' specifies the abstract database object.
   `name' specifies the name of the function.  All databases support "put", "out", "get",
   "putlist", "outlist", and "getlist".  "put" is to store a record.  It receives a key and a
   value, and returns an empty list.  "out" is to remove a record.  It receives a key, and
   returns an empty list.  "get" is to retrieve a record.  It receives a key, and returns a list
   of the values.  "putlist" is to store records.  It receives keys and values one after the
   other, and returns an empty list.  "outlist" is to remove records.  It receives keys, and
   returns an empty list.  "getlist" is to retrieve records.  It receives keys, and returns keys
   and values of corresponding records one after the other.
   `args' specifies a list object containing arguments.
   If successful, the return value is a list object of the result.  `NULL' is returned on failure.
   Because the object of the return value is created with the function `tclistnew', it
   should be deleted with the function `tclistdel' when it is no longer in use. */
TCLIST* tcadbmisc(TCADB* adb, char* name, TCLIST* args);



/*************************************************************************************************
 * features for experts
 *************************************************************************************************/
/+

struct ADBSKEL {                         /* type of structure for a extra database skeleton */
  void *opq;                             /* opaque pointer */
  void (*del)(void *);                   /* destructor */
  bool (*open)(void *, char* );
  bool (*close)(void *);
  bool (*put)(void*, void*, int, void*, int);
  bool (*putkeep)(void*, void*, int, void *, int);
  bool (*putcat)(void*, void*, int, void*, int);
  bool (*out)(void*, void*, int);
  void *(*get)(void*, void*, int, int *);
  int (*vsiz)(void*, void*, int);
  bool (*iterinit)(void*);
  void *(*iternext)(void*, int*);
  TCLIST *(*fwmkeys)(void*, void*, int, int);
  int (*addint)(void *, void*, int, int);
  double (*adddouble)(void *, void*, int, double);
  bool (*sync)(void *);
  bool (*optimize)(void *, char*);
  bool (*vanish)(void *);
  bool (*copy)(void *, char*);
  bool (*tranbegin)(void *);
  bool (*trancommit)(void *);
  bool (*tranabort)(void *);
  const char *(*path)(void *);
  ulong (*rnum)(void *);
  ulong (*size)(void *);
  TCLIST *(*misc)(void *, char*, TCLIST*);
  bool (*putproc)(void *, void*, int, void*, int, TCPDPROC, void*);
  bool (*foreach)(void*, TCITER, void*);
} ;

/* type of the pointer to a mapping function.
   `map' specifies the pointer to the destination manager.
   `kbuf' specifies the pointer to the region of the key.
   `ksiz' specifies the size of the region of the key.
   `vbuf' specifies the pointer to the region of the value.
   `vsiz' specifies the size of the region of the value.
   `op' specifies the pointer to the optional opaque object.
   The return value is true to continue iteration or false to stop iteration. */
typedef bool (*ADBMAPPROC)(void* map, char* kbuf, int ksiz,  char* vbuf, int vsiz, void* op);


/* Set an extra database sleleton to an abstract database object.
   `adb' specifies the abstract database object.
   `skel' specifies the extra database skeleton.
   If successful, the return value is true, else, it is false. */
bool tcadbsetskel(TCADB* adb, ADBSKEL* skel);


/* Get the open mode of an abstract database object.
   `adb' specifies the abstract database object.
   The return value is `ADBOVOID' for not opened database, `ADBOMDB' for on-memory hash database,
  `ADBONDB' for on-memory tree database, `ADBOHDB' for hash database, `ADBOBDB' for B+ tree
  database, `ADBOFDB' for fixed-length database, `ADBOTDB' for table database. */
int tcadbomode(TCADB* adb);


/* Get the concrete database object of an abstract database object.
   `adb' specifies the abstract database object.
   The return value is the concrete database object depend on the open mode or 0 if the object
   does not connect to any database instance. */
void *tcadbreveal(TCADB* adb);


/* Store a record into an abstract database object with a duplication handler.
   `adb' specifies the abstract database object.
   `kbuf' specifies the pointer to the region of the key.
   `ksiz' specifies the size of the region of the key.
   `vbuf' specifies the pointer to the region of the value.
   `vsiz' specifies the size of the region of the value.
   `proc' specifies the pointer to the callback function to process duplication.
   `op' specifies an arbitrary pointer to be given as a parameter of the callback function.  If
   it is not needed, `NULL' can be specified.
   If successful, the return value is true, else, it is false.
   This function does not work for the table database. */
bool tcadbputproc(TCADB *adb, void* kbuf, int ksiz, void* vbuf, int vsiz, TCPDPROC proc, void* op);


/* Process each record atomically of an abstract database object.
   `adb' specifies the abstract database object.
   `iter' specifies the pointer to the iterator function called for each record.
   `op' specifies an arbitrary pointer to be given as a parameter of the iterator function.  If
   it is not needed, `NULL' can be specified.
   If successful, the return value is true, else, it is false. */
bool tcadbforeach(TCADB* adb, TCITER iter, void* op);


/* Map records of an abstract database object into another B+ tree database.
   `adb' specifies the abstract database object.
   `keys' specifies a list object of the keys of the target records.  If it is `NULL', every
   record is processed.
   `bdb' specifies the B+ tree database object into which records emitted by the mapping function
   are stored.
   `proc' specifies the pointer to the mapping function called for each record.
   `op' specifies specifies the pointer to the optional opaque object for the mapping function.
   `csiz' specifies the size of the cache to sort emitted records.  If it is negative, the
   default size is specified.  The default size is 268435456.
   If successful, the return value is true, else, it is false. */
bool tcadbmapbdb(TCADB *adb, TCLIST* keys, TCBDB* bdb, ADBMAPPROC proc, void* op, long csiz);


/* Emit records generated by the mapping function into the result map.
   `kbuf' specifies the pointer to the region of the key.
   `ksiz' specifies the size of the region of the key.
   `vbuf' specifies the pointer to the region of the value.
   `vsiz' specifies the size of the region of the value.
   If successful, the return value is true, else, it is false. */
bool tcadbmapbdbemit(void* map, char* kbuf, int ksiz, char* vbuf, int vsiz);

+/