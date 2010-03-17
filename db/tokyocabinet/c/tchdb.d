module ocean.db.tokyocabinet.c.tchdb;

/*************************************************************************************************
 * The hash database API of Tokyo Cabinet
 *                                                      Copyright (C) 2006-2009 Mikio Hirabayashi
 * This file is part of Tokyo Cabinet.
 * Tokyo Cabinet is free software; you can redistribute it and/or modify it under the terms of
 * the GNU Lesser General Public License as published by the Free Software Foundation; either
 * version 2.1 of the License or any later version.  Tokyo Cabinet is distributed in the hope
 * that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
 * License for more details.
 * You should have received a copy of the GNU Lesser General Public License along with Tokyo
 * Cabinet; if not, write to the Free Software Foundation, Inc., 59 Temple Place, Suite 330,
 * Boston, MA 02111-1307 USA.
 *************************************************************************************************/


extern (C)
{

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


/*************************************************************************************************
 * API
 *************************************************************************************************/

alias _TCMAPREC TCMAPREC;

/* type of structure for an element of a map */
struct _TCMAPREC
{               
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

enum
{                                   /* enumeration for additional flags */
  HDBFOPEN = 1 << 0,                     /* whether opened */
  HDBFFATAL = 1 << 1                     /* whetehr with fatal error */
};

enum HDBOPT : ubyte
{                                   /* enumeration for tuning options */
  HDBTLARGE   = 1 << 0,                 /* use 64-bit bucket array */
  HDBTDEFLATE = 1 << 1,                 /* compress each record with Deflate */
  HDBTBZIP    = 1 << 2,                 /* compress each record with BZIP2 */
  HDBTTCBS    = 1 << 3,                 /* compress each record with TCBS */
  HDBTEXCODEC = 1 << 4                  /* compress each record with custom functions */
};

enum HDBOMODE : int
{                                   /* enumeration for open modes */
  HDBOREADER = 1 << 0,                  /* open as a reader */
  HDBOWRITER = 1 << 1,                  /* open as a writer */
  HDBOCREAT  = 1 << 2,                  /* writer creating */
  HDBOTRUNC  = 1 << 3,                  /* writer truncating */
  HDBONOLCK  = 1 << 4,                  /* open without locking */
  HDBOLCKNB  = 1 << 5,                  /* lock without blocking */
  HDBOTSYNC  = 1 << 6                   /* synchronize every transaction */
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


enum TCHERRCODE : int
{                                       /* enumeration for error codes */
    TCESUCCESS,                            /* success */
    TCETHREAD,                             /* threading error */
    TCEINVALID,                            /* invalid operation */
    TCENOFILE,                             /* file not found */
    TCENOPERM,                             /* no permission */
    TCEMETA,                               /* invalid meta data */
    TCERHEAD,                              /* invalid record header */
    TCEOPEN,                               /* open error */
    TCECLOSE,                              /* close error */
    TCETRUNC,                              /* trunc error */
    TCESYNC,                               /* sync error */
    TCESTAT,                               /* stat error */
    TCESEEK,                               /* seek error */
    TCEREAD,                               /* read error */
    TCEWRITE,                              /* write error */
    TCEMMAP,                               /* mmap error */
    TCELOCK,                               /* lock error */
    TCEUNLINK,                             /* unlink error */
    TCERENAME,                             /* rename error */
    TCEMKDIR,                              /* mkdir error */
    TCERMDIR,                              /* rmdir error */
    TCEKEEP,                               /* existing record */
    TCENOREC,                              /* no record found */
    TCEMISC = 9999                         /* miscellaneous error */
};





/* Get the message string corresponding to an error code.
   `ecode' specifies the error code.
   The return value is the message string of the error code. */
char* tchdberrmsg(int ecode);


/* Create a hash database object.
   The return value is the new hash database object. */
TCHDB *tchdbnew();


/* Delete a hash database object.
   `hdb' specifies the hash database object.
   If the database is not closed, it is closed implicitly.  Note that the deleted object and its
   derivatives can not be used anymore. */
void tchdbdel(TCHDB *hdb);


/* Get the last happened error code of a hash database object.
   `hdb' specifies the hash database object.
   The return value is the last happened error code.
   The following error codes are defined:
       `TCESUCCESS' for success,
       `TCETHREAD'  for threading error,
       `TCEINVALID' for invalid operation,
       `TCENOFILE'  for file not found,
       `TCENOPERM'  for no permission,
       `TCEMETA'    for invalid meta data,
       `TCERHEAD'   for invalid record header,
       `TCEOPEN'    for open error,
       `TCECLOSE'   for close error,
       `TCETRUNC'   for trunc error,
       `TCESYNC'    for sync error,
       `TCESTAT'    for stat error,
       `TCESEEK'    for seek error,
       `TCEREAD'    for read error,
       `TCEWRITE'   for write error,
       `TCEMMAP'    for mmap error,
       `TCELOCK'    for lock error,
       `TCEUNLINK'  for unlink error,
       `TCERENAME'  for rename error,
       `TCEMKDIR'   for mkdir error,
       `TCERMDIR'   for rmdir error,
       `TCEKEEP'    for existing record,
       `TCENOREC'   for no record found, and
       `TCEMISC'    for miscellaneous error.
*/
TCHERRCODE tchdbecode(TCHDB *hdb);


/* Set mutual exclusion control of a hash database object for threading.
   `hdb' specifies the hash database object which is not opened.
   If successful, the return value is true, else, it is false.
   Note that the mutual exclusion control is needed if the object is shared by plural threads and
   this function should should be called before the database is opened. */
bool tchdbsetmutex(TCHDB *hdb);


/* Set the tuning parameters of a hash database object.
   `hdb' specifies the hash database object which is not opened.
   `bnum' specifies the number of elements of the bucket array.  If it is not more than 0, the
   default value is specified.  The default value is 131071.  Suggested size of the bucket array
   is about from 0.5 to 4 times of the number of all records to be stored.
   `apow' specifies the size of record alignment by power of 2.  If it is negative, the default
   value is specified.  The default value is 4 standing for 2^4=16.
   `fpow' specifies the maximum number of elements of the free block pool by power of 2.  If it
   is negative, the default value is specified.  The default value is 10 standing for 2^10=1024.
   `opts' specifies options by bitwise-or: `HDBTLARGE' specifies that the size of the database
   can be larger than 2GB by using 64-bit bucket array, `HDBTDEFLATE' specifies that each record
   is compressed with Deflate encoding, `HDBTBZIP' specifies that each record is compressed with
   BZIP2 encoding, `HDBTTCBS' specifies that each record is compressed with TCBS encoding.
   If successful, the return value is true, else, it is false.
   Note that the tuning parameters should be set before the database is opened. */
bool tchdbtune(TCHDB *hdb, long bnum, byte apow, byte fpow, ubyte opts);


/* Set the caching parameters of a hash database object.
   `hdb' specifies the hash database object which is not opened.
   `rcnum' specifies the maximum number of records to be cached.  If it is not more than 0, the
   record cache is disabled.  It is disabled by default.
   If successful, the return value is true, else, it is false.
   Note that the caching parameters should be set before the database is opened. */
bool tchdbsetcache(TCHDB *hdb, int rcnum);


/* Set the size of the extra mapped memory of a hash database object.
   `hdb' specifies the hash database object which is not opened.
   `xmsiz' specifies the size of the extra mapped memory.  If it is not more than 0, the extra
   mapped memory is disabled.  The default size is 67108864.
   If successful, the return value is true, else, it is false.
   Note that the mapping parameters should be set before the database is opened. */
bool tchdbsetxmsiz(TCHDB *hdb, long xmsiz);


/* Set the unit step number of auto defragmentation of a hash database object.
   `hdb' specifies the hash database object which is not opened.
   `dfunit' specifie the unit step number.  If it is not more than 0, the auto defragmentation
   is disabled.  It is disabled by default.
   If successful, the return value is true, else, it is false.
   Note that the defragmentation parameters should be set before the database is opened. */
bool tchdbsetdfunit(TCHDB *hdb, int dfunit);


/* Open a database file and connect a hash database object.
   `hdb' specifies the hash database object which is not opened.
   `path' specifies the path of the database file.
   `omode' specifies the connection mode: `HDBOWRITER' as a writer, `HDBOREADER' as a reader.
   If the mode is `HDBOWRITER', the following may be added by bitwise-or: `HDBOCREAT', which
   means it creates a new database if not exist, `HDBOTRUNC', which means it creates a new
   database regardless if one exists, `HDBOTSYNC', which means every transaction synchronizes
   updated contents with the device.  Both of `HDBOREADER' and `HDBOWRITER' can be added to by
   bitwise-or: `HDBONOLCK', which means it opens the database file without file locking, or
   `HDBOLCKNB', which means locking is performed without blocking.
   If successful, the return value is true, else, it is false. */
bool tchdbopen(TCHDB *hdb, char* path, HDBOMODE omode);


/* Close a hash database object.
   `hdb' specifies the hash database object.
   If successful, the return value is true, else, it is false.
   Update of a database is assured to be written when the database is closed.  If a writer opens
   a database but does not close it appropriately, the database will be broken. */
bool tchdbclose(TCHDB *hdb);


/* Store a record into a hash database object.
   `hdb' specifies the hash database object connected as a writer.
   `kbuf' specifies the pointer to the region of the key.
   `ksiz' specifies the size of the region of the key.
   `vbuf' specifies the pointer to the region of the value.
   `vsiz' specifies the size of the region of the value.
   If successful, the return value is true, else, it is false.
   If a record with the same key exists in the database, it is overwritten. */
bool tchdbput(TCHDB *hdb, void* kbuf, int ksiz, void* vbuf, int vsiz);


/* Store a string record into a hash database object.
   `hdb' specifies the hash database object connected as a writer.
   `kstr' specifies the string of the key.
   `vstr' specifies the string of the value.
   If successful, the return value is true, else, it is false.
   If a record with the same key exists in the database, it is overwritten. */
bool tchdbput2(TCHDB *hdb, char* kstr, char* vstr);


/* Store a new record into a hash database object.
   `hdb' specifies the hash database object connected as a writer.
   `kbuf' specifies the pointer to the region of the key.
   `ksiz' specifies the size of the region of the key.
   `vbuf' specifies the pointer to the region of the value.
   `vsiz' specifies the size of the region of the value.
   If successful, the return value is true, else, it is false.
   If a record with the same key exists in the database, this function has no effect. */
bool tchdbputkeep(TCHDB *hdb, void* kbuf, int ksiz, void *vbuf, int vsiz);


/* Store a new string record into a hash database object.
   `hdb' specifies the hash database object connected as a writer.
   `kstr' specifies the string of the key.
   `vstr' specifies the string of the value.
   If successful, the return value is true, else, it is false.
   If a record with the same key exists in the database, this function has no effect. */
bool tchdbputkeep2(TCHDB *hdb, char *kstr, char *vstr);


/* Concatenate a value at the end of the existing record in a hash database object.
   `hdb' specifies the hash database object connected as a writer.
   `kbuf' specifies the pointer to the region of the key.
   `ksiz' specifies the size of the region of the key.
   `vbuf' specifies the pointer to the region of the value.
   `vsiz' specifies the size of the region of the value.
   If successful, the return value is true, else, it is false.
   If there is no corresponding record, a new record is created. */
bool tchdbputcat(TCHDB *hdb, void *kbuf, int ksiz, void *vbuf, int vsiz);


/* Concatenate a string value at the end of the existing record in a hash database object.
   `hdb' specifies the hash database object connected as a writer.
   `kstr' specifies the string of the key.
   `vstr' specifies the string of the value.
   If successful, the return value is true, else, it is false.
   If there is no corresponding record, a new record is created. */
bool tchdbputcat2(TCHDB *hdb, char *kstr, char *vstr);


/* Store a record into a hash database object in asynchronous fashion.
   `hdb' specifies the hash database object connected as a writer.
   `kbuf' specifies the pointer to the region of the key.
   `ksiz' specifies the size of the region of the key.
   `vbuf' specifies the pointer to the region of the value.
   `vsiz' specifies the size of the region of the value.
   If successful, the return value is true, else, it is false.
   If a record with the same key exists in the database, it is overwritten.  Records passed to
   this function are accumulated into the inner buffer and wrote into the file at a blast. */
bool tchdbputasync(TCHDB *hdb, void *kbuf, int ksiz, void *vbuf, int vsiz);


/* Store a string record into a hash database object in asynchronous fashion.
   `hdb' specifies the hash database object connected as a writer.
   `kstr' specifies the string of the key.
   `vstr' specifies the string of the value.
   If successful, the return value is true, else, it is false.
   If a record with the same key exists in the database, it is overwritten.  Records passed to
   this function are accumulated into the inner buffer and wrote into the file at a blast. */
bool tchdbputasync2(TCHDB *hdb, char *kstr, char *vstr);


/* Remove a record of a hash database object.
   `hdb' specifies the hash database object connected as a writer.
   `kbuf' specifies the pointer to the region of the key.
   `ksiz' specifies the size of the region of the key.
   If successful, the return value is true, else, it is false. */
bool tchdbout(TCHDB *hdb, void *kbuf, int ksiz);


/* Remove a string record of a hash database object.
   `hdb' specifies the hash database object connected as a writer.
   `kstr' specifies the string of the key.
   If successful, the return value is true, else, it is false. */
bool tchdbout2(TCHDB *hdb, char *kstr);


/* Retrieve a record in a hash database object.
   `hdb' specifies the hash database object.
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
void *tchdbget(TCHDB *hdb, void *kbuf, int ksiz, int *sp);


/* Retrieve a string record in a hash database object.
   `hdb' specifies the hash database object.
   `kstr' specifies the string of the key.
   If successful, the return value is the string of the value of the corresponding record.
   `NULL' is returned if no record corresponds.
   Because the region of the return value is allocated with the `malloc' call, it should be
   released with the `free' call when it is no longer in use. */
char *tchdbget2(TCHDB *hdb, char *kstr);


/* Retrieve a record in a hash database object and write the value into a buffer.
   `hdb' specifies the hash database object.
   `kbuf' specifies the pointer to the region of the key.
   `ksiz' specifies the size of the region of the key.
   `vbuf' specifies the pointer to the buffer into which the value of the corresponding record is
   written.
   `max' specifies the size of the buffer.
   If successful, the return value is the size of the written data, else, it is -1.  -1 is
   returned if no record corresponds to the specified key.
   Note that an additional zero code is not appended at the end of the region of the writing
   buffer. */
int tchdbget3(TCHDB *hdb, void *kbuf, int ksiz, void *vbuf, int max);


/* Get the size of the value of a record in a hash database object.
   `hdb' specifies the hash database object.
   `kbuf' specifies the pointer to the region of the key.
   `ksiz' specifies the size of the region of the key.
   If successful, the return value is the size of the value of the corresponding record, else,
   it is -1. */
int tchdbvsiz(TCHDB *hdb, void *kbuf, int ksiz);


/* Get the size of the value of a string record in a hash database object.
   `hdb' specifies the hash database object.
   `kstr' specifies the string of the key.
   If successful, the return value is the size of the value of the corresponding record, else,
   it is -1. */
int tchdbvsiz2(TCHDB *hdb, char *kstr);


/* Initialize the iterator of a hash database object.
   `hdb' specifies the hash database object.
   If successful, the return value is true, else, it is false.
   The iterator is used in order to access the key of every record stored in a database. */
bool tchdbiterinit(TCHDB *hdb);


/* Get the next key of the iterator of a hash database object.
   `hdb' specifies the hash database object.
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
void *tchdbiternext(TCHDB *hdb, int *sp);


/* Get the next key string of the iterator of a hash database object.
   `hdb' specifies the hash database object.
   If successful, the return value is the string of the next key, else, it is `NULL'.  `NULL' is
   returned when no record is to be get out of the iterator.
   Because the region of the return value is allocated with the `malloc' call, it should be
   released with the `free' call when it is no longer in use.  It is possible to access every
   record by iteration of calling this function.  However, it is not assured if updating the
   database is occurred while the iteration.  Besides, the order of this traversal access method
   is arbitrary, so it is not assured that the order of storing matches the one of the traversal
   access. */
char *tchdbiternext2(TCHDB *hdb);


/* Get the next extensible objects of the iterator of a hash database object.
   `hdb' specifies the hash database object.
   `kxstr' specifies the object into which the next key is wrote down.
   `vxstr' specifies the object into which the next value is wrote down.
   If successful, the return value is true, else, it is false.  False is returned when no record
   is to be get out of the iterator. */
bool tchdbiternext3(TCHDB *hdb, TCXSTR *kxstr, TCXSTR *vxstr);


/* Get forward matching keys in a hash database object.
   `hdb' specifies the hash database object.
   `pbuf' specifies the pointer to the region of the prefix.
   `psiz' specifies the size of the region of the prefix.
   `max' specifies the maximum number of keys to be fetched.  If it is negative, no limit is
   specified.
   The return value is a list object of the corresponding keys.  This function does never fail.
   It returns an empty list even if no key corresponds.
   Because the object of the return value is created with the function `tclistnew', it should be
   deleted with the function `tclistdel' when it is no longer in use.  Note that this function
   may be very slow because every key in the database is scanned. */
TCLIST* tchdbfwmkeys(TCHDB *hdb, void *pbuf, int psiz, int max);


/* Get forward matching string keys in a hash database object.
   `hdb' specifies the hash database object.
   `pstr' specifies the string of the prefix.
   `max' specifies the maximum number of keys to be fetched.  If it is negative, no limit is
   specified.
   The return value is a list object of the corresponding keys.  This function does never fail.
   It returns an empty list even if no key corresponds.
   Because the object of the return value is created with the function `tclistnew', it should be
   deleted with the function `tclistdel' when it is no longer in use.  Note that this function
   may be very slow because every key in the database is scanned. */
TCLIST* tchdbfwmkeys2(TCHDB *hdb, char *pstr, int max);


/* Add an integer to a record in a hash database object.
   `hdb' specifies the hash database object connected as a writer.
   `kbuf' specifies the pointer to the region of the key.
   `ksiz' specifies the size of the region of the key.
   `num' specifies the additional value.
   If successful, the return value is the summation value, else, it is `INT_MIN'.
   If the corresponding record exists, the value is treated as an integer and is added to.  If no
   record corresponds, a new record of the additional value is stored. */
int tchdbaddint(TCHDB *hdb, void *kbuf, int ksiz, int num);


/* Add a real number to a record in a hash database object.
   `hdb' specifies the hash database object connected as a writer.
   `kbuf' specifies the pointer to the region of the key.
   `ksiz' specifies the size of the region of the key.
   `num' specifies the additional value.
   If successful, the return value is the summation value, else, it is Not-a-Number.
   If the corresponding record exists, the value is treated as a real number and is added to.  If
   no record corresponds, a new record of the additional value is stored. */
double tchdbadddouble(TCHDB *hdb, void *kbuf, int ksiz, double num);


/* Synchronize updated contents of a hash database object with the file and the device.
   `hdb' specifies the hash database object connected as a writer.
   If successful, the return value is true, else, it is false.
   This function is useful when another process connects to the same database file. */
bool tchdbsync(TCHDB *hdb);


/* Optimize the file of a hash database object.
   `hdb' specifies the hash database object connected as a writer.
   `bnum' specifies the number of elements of the bucket array.  If it is not more than 0, the
   default value is specified.  The default value is two times of the number of records.
   `apow' specifies the size of record alignment by power of 2.  If it is negative, the current
   setting is not changed.
   `fpow' specifies the maximum number of elements of the free block pool by power of 2.  If it
   is negative, the current setting is not changed.
   `opts' specifies options by bitwise-or: `HDBTLARGE' specifies that the size of the database
   can be larger than 2GB by using 64-bit bucket array, `HDBTDEFLATE' specifies that each record
   is compressed with Deflate encoding, `HDBTBZIP' specifies that each record is compressed with
   BZIP2 encoding, `HDBTTCBS' specifies that each record is compressed with TCBS encoding.  If it
   is `UINT8_MAX', the current setting is not changed.
   If successful, the return value is true, else, it is false.
   This function is useful to reduce the size of the database file with data fragmentation by
   successive updating. */
bool tchdboptimize(TCHDB *hdb, long bnum, byte apow, byte fpow, HDBOPT opts);


/* Remove all records of a hash database object.
   `hdb' specifies the hash database object connected as a writer.
   If successful, the return value is true, else, it is false. */
bool tchdbvanish(TCHDB *hdb);


/* Copy the database file of a hash database object.
   `hdb' specifies the hash database object.
   `path' specifies the path of the destination file.  If it begins with `@', the trailing
   substring is executed as a command line.
   If successful, the return value is true, else, it is false.  False is returned if the executed
   command returns non-zero code.
   The database file is assured to be kept synchronized and not modified while the copying or
   executing operation is in progress.  So, this function is useful to create a backup file of
   the database file. */
bool tchdbcopy(TCHDB *hdb, char *path);


/* Begin the transaction of a hash database object.
   `hdb' specifies the hash database object connected as a writer.
   If successful, the return value is true, else, it is false.
   The database is locked by the thread while the transaction so that only one transaction can be
   activated with a database object at the same time.  Thus, the serializable isolation level is
   assumed if every database operation is performed in the transaction.  All updated regions are
   kept track of by write ahead logging while the transaction.  If the database is closed during
   transaction, the transaction is aborted implicitly. */
bool tchdbtranbegin(TCHDB *hdb);


/* Commit the transaction of a hash database object.
   `hdb' specifies the hash database object connected as a writer.
   If successful, the return value is true, else, it is false.
   Update in the transaction is fixed when it is committed successfully. */
bool tchdbtrancommit(TCHDB *hdb);


/* Abort the transaction of a hash database object.
   `hdb' specifies the hash database object connected as a writer.
   If successful, the return value is true, else, it is false.
   Update in the transaction is discarded when it is aborted.  The state of the database is
   rollbacked to before transaction. */
bool tchdbtranabort(TCHDB *hdb);


/* Get the file path of a hash database object.
   `hdb' specifies the hash database object.
   The return value is the path of the database file or `NULL' if the object does not connect to
   any database file. */
char *tchdbpath(TCHDB *hdb);


/* Get the number of records of a hash database object.
   `hdb' specifies the hash database object.
   The return value is the number of records or 0 if the object does not connect to any database
   file. */
ulong tchdbrnum(TCHDB *hdb);


/* Get the size of the database file of a hash database object.
   `hdb' specifies the hash database object.
   The return value is the size of the database file or 0 if the object does not connect to any
   database file. */
ulong tchdbfsiz(TCHDB *hdb);



/*************************************************************************************************
 * features for experts
 *************************************************************************************************/


/* Set the error code of a hash database object.
   `hdb' specifies the hash database object.
   `ecode' specifies the error code.
   `file' specifies the file name of the code.
   `line' specifies the line number of the code.
   `func' specifies the function name of the code. */
void tchdbsetecode(TCHDB *hdb, int ecode, char *filename, int line, char *func);


/* Set the type of a hash database object.
   `hdb' specifies the hash database object.
   `type' specifies the database type. */
void tchdbsettype(TCHDB *hdb, ubyte type);


/* Set the file descriptor for debugging output.
   `hdb' specifies the hash database object.
   `fd' specifies the file descriptor for debugging output. */
void tchdbsetdbgfd(TCHDB *hdb, int fd);


/* Get the file descriptor for debugging output.
   `hdb' specifies the hash database object.
   The return value is the file descriptor for debugging output. */
int tchdbdbgfd(TCHDB *hdb);


/* Check whether mutual exclusion control is set to a hash database object.
   `hdb' specifies the hash database object.
   If mutual exclusion control is set, it is true, else it is false. */
bool tchdbhasmutex(TCHDB *hdb);


/* Synchronize updating contents on memory of a hash database object.
   `hdb' specifies the hash database object connected as a writer.
   `phys' specifies whether to synchronize physically.
   If successful, the return value is true, else, it is false. */
bool tchdbmemsync(TCHDB *hdb, bool phys);


/* Clear the cache of a hash tree database object.
   `hdb' specifies the hash tree database object.
   If successful, the return value is true, else, it is false. */
bool tchdbcacheclear(TCHDB *hdb);


/* Get the number of elements of the bucket array of a hash database object.
   `hdb' specifies the hash database object.
   The return value is the number of elements of the bucket array or 0 if the object does not
   connect to any database file. */
ulong tchdbbnum(TCHDB *hdb);


/* Get the record alignment of a hash database object.
   `hdb' specifies the hash database object.
   The return value is the record alignment or 0 if the object does not connect to any database
   file. */
uint tchdbalign(TCHDB *hdb);


/* Get the maximum number of the free block pool of a a hash database object.
   `hdb' specifies the hash database object.
   The return value is the maximum number of the free block pool or 0 if the object does not
   connect to any database file. */
uint tchdbfbpmax(TCHDB *hdb);


/* Get the size of the extra mapped memory of a hash database object.
   `hdb' specifies the hash database object.
   The return value is the size of the extra mapped memory or 0 if the object does not connect to
   any database file. */
uint tchdbxmsiz(TCHDB *hdb);


/* Get the inode number of the database file of a hash database object.
   `hdb' specifies the hash database object.
   The return value is the inode number of the database file or 0 if the object does not connect
   to any database file. */
ulong tchdbinode(TCHDB *hdb);


/* Get the modification time of the database file of a hash database object.
   `hdb' specifies the hash database object.
   The return value is the inode number of the database file or 0 if the object does not connect
   to any database file. */
long tchdbmtime(TCHDB *hdb);


/* Get the connection mode of a hash database object.
   `hdb' specifies the hash database object.
   The return value is the connection mode. */
int tchdbomode(TCHDB *hdb);


/* Get the database type of a hash database object.
   `hdb' specifies the hash database object.
   The return value is the database type. */
ubyte tchdbtype(TCHDB *hdb);


/* Get the additional flags of a hash database object.
   `hdb' specifies the hash database object.
   The return value is the additional flags. */
ubyte tchdbflags(TCHDB *hdb);


/* Get the options of a hash database object.
   `hdb' specifies the hash database object.
   The return value is the options. */
ubyte tchdbopts(TCHDB *hdb);


/* Get the pointer to the opaque field of a hash database object.
   `hdb' specifies the hash database object.
   The return value is the pointer to the opaque field whose size is 128 bytes. */
char *tchdbopaque(TCHDB *hdb);


/* Get the number of used elements of the bucket array of a hash database object.
   `hdb' specifies the hash database object.
   The return value is the number of used elements of the bucket array or 0 if the object does
   not connect to any database file. */
ulong tchdbbnumused(TCHDB *hdb);


/* Set the custom codec functions of a hash database object.
   `hdb' specifies the hash database object.
   `enc' specifies the pointer to the custom encoding function.  It receives four parameters.
   The first parameter is the pointer to the region.  The second parameter is the size of the
   region.  The third parameter is the pointer to the variable into which the size of the region
   of the return value is assigned.  The fourth parameter is the pointer to the optional opaque
   object.  It returns the pointer to the result object allocated with `malloc' call if
   successful, else, it returns `NULL'.
   `encop' specifies an arbitrary pointer to be given as a parameter of the encoding function.
   If it is not needed, `NULL' can be specified.
   `dec' specifies the pointer to the custom decoding function.
   `decop' specifies an arbitrary pointer to be given as a parameter of the decoding function.
   If it is not needed, `NULL' can be specified.
   If successful, the return value is true, else, it is false.
   Note that the custom codec functions should be set before the database is opened and should be
   set every time the database is being opened. */
bool tchdbsetcodecfunc(TCHDB *hdb, TCCODEC enc, void *encop, TCCODEC dec, void *decop);


/* Get the custom codec functions of a hash database object.
   `hdb' specifies the hash database object.
   `ep' specifies the pointer to a variable into which the pointer to the custom encoding
   function is assigned
   `eop' specifies the pointer to a variable into which the arbitrary pointer to be given to the
   encoding function is assigned.
   `dp' specifies the pointer to a variable into which the pointer to the custom decoding
   function is assigned
   `dop' specifies the pointer to a variable into which the arbitrary pointer to be given to the
   decoding function is assigned. */
void tchdbcodecfunc(TCHDB *hdb, TCCODEC *ep, void **eop, TCCODEC *dp, void **dop);


/* Get the unit step number of auto defragmentation of a hash database object.
   `hdb' specifies the hash database object.
   The return value is the unit step number of auto defragmentation. */
uint tchdbdfunit(TCHDB *hdb);


/* Perform dynamic defragmentation of a hash database object.
   `hdb' specifies the hash database object connected as a writer.
   `step' specifie the number of steps.  If it is not more than 0, the whole file is defragmented
   gradually without keeping a continuous lock.
   If successful, the return value is true, else, it is false. */
bool tchdbdefrag(TCHDB *hdb, long step);


/* Store a record into a hash database object with a duplication handler.
   `hdb' specifies the hash database object connected as a writer.
   `kbuf' specifies the pointer to the region of the key.
   `ksiz' specifies the size of the region of the key.
   `vbuf' specifies the pointer to the region of the value.  `NULL' means that record addition is
   ommited if there is no corresponding record.
   `vsiz' specifies the size of the region of the value.
   `proc' specifies the pointer to the callback function to process duplication.  It receives
   four parameters.  The first parameter is the pointer to the region of the value.  The second
   parameter is the size of the region of the value.  The third parameter is the pointer to the
   variable into which the size of the region of the return value is assigned.  The fourth
   parameter is the pointer to the optional opaque object.  It returns the pointer to the result
   object allocated with `malloc'.  It is released by the caller.  If it is `NULL', the record is
   not modified.  If it is `(void *)-1', the record is removed.
   `op' specifies an arbitrary pointer to be given as a parameter of the callback function.  If
   it is not needed, `NULL' can be specified.
   If successful, the return value is true, else, it is false.
   Note that the callback function can not perform any database operation because the function
   is called in the critical section guarded by the same locks of database operations. */
bool tchdbputproc(TCHDB *hdb, void *kbuf, int ksiz, void *vbuf = null, int vsiz = 0,
                  TCPDPROC proc = null, void *op = null);


/* Retrieve the next record of a record in a hash database object.
   `hdb' specifies the hash database object.
   `kbuf' specifies the pointer to the region of the key.  If it is `NULL', the first record is
   retrieved.
   `ksiz' specifies the size of the region of the key.
   `sp' specifies the pointer to the variable into which the size of the region of the return
   value is assigned.
   If successful, the return value is the pointer to the region of the key of the next record.
   `NULL' is returned if no record corresponds.
   Because an additional zero code is appended at the end of the region of the return value,
   the return value can be treated as a character string.  Because the region of the return
   value is allocated with the `malloc' call, it should be released with the `free' call when
   it is no longer in use. */
void *tchdbgetnext(TCHDB *hdb, void *kbuf, int ksiz, int *sp);


/* Retrieve the next string record in a hash database object.
   `hdb' specifies the hash database object.
   `kstr' specifies the string of the key.  If it is `NULL', the first record is retrieved.
   If successful, the return value is the string of the key of the next record.  `NULL' is
   returned if no record corresponds.
   Because the region of the return value is allocated with the `malloc' call, it should be
   released with the `free' call when it is no longer in use. */
char *tchdbgetnext2(TCHDB *hdb, char *kstr = null);


/* Retrieve the key and the value of the next record of a record in a hash database object.
   `hdb' specifies the hash database object.
   `kbuf' specifies the pointer to the region of the key.
   `ksiz' specifies the size of the region of the key.
   `sp' specifies the pointer to the variable into which the size of the region of the return
   value is assigned.
   `vbp' specifies the pointer to the variable into which the pointer to the value is assigned.
   `vsp' specifies the pointer to the variable into which the size of the value is assigned.
   If successful, the return value is the pointer to the region of the key of the next
   record.
   Because the region of the return value is allocated with the `malloc' call, it should be
   released with the `free' call when it is no longer in use.  The retion pointed to by `vbp'
   should not be released. */
char *tchdbgetnext3(TCHDB *hdb, char *kbuf, int ksiz, int *sp, char **vbp, int *vsp);


/* Move the iterator to the record corresponding a key of a hash database object.
   `hdb' specifies the hash database object.
   `kbuf' specifies the pointer to the region of the key.
   `ksiz' specifies the size of the region of the key.
   If successful, the return value is true, else, it is false.  False is returned if there is
   no record corresponding the condition. */
bool tchdbiterinit2(TCHDB *hdb, void *kbuf, int ksiz);


/* Move the iterator to the record corresponding a key string of a hash database object.
   `hdb' specifies the hash database object.
   `kstr' specifies the string of the key.
   If successful, the return value is true, else, it is false.  False is returned if there is
   no record corresponding the condition. */
bool tchdbiterinit3(TCHDB *hdb, char *kstr);


/* Process each record atomically of a hash database object.
   `hdb' specifies the hash database object.
   `iter' specifies the pointer to the iterator function called for each record.  It receives
   five parameters.  The first parameter is the pointer to the region of the key.  The second
   parameter is the size of the region of the key.  The third parameter is the pointer to the
   region of the value.  The fourth parameter is the size of the region of the value.  The fifth
   parameter is the pointer to the optional opaque object.  It returns true to continue iteration
   or false to stop iteration.
   `op' specifies an arbitrary pointer to be given as a parameter of the iterator function.  If
   it is not needed, `NULL' can be specified.
   If successful, the return value is true, else, it is false.
   Note that the callback function can not perform any database operation because the function
   is called in the critical section guarded by the same locks of database operations. */
bool tchdbforeach(TCHDB *hdb, TCITER iter, void *op = null);


/* Void the transaction of a hash database object.
   `hdb' specifies the hash database object connected as a writer.
   If successful, the return value is true, else, it is false.
   This function should be called only when no update in the transaction. */
bool tchdbtranvoid(TCHDB *hdb);
} // extern (C)


/******************************************************************************

    TchDbIterator structure
    
    TchDbIterator holds the static tchdbopapply() method which can be used to
    perform 'foreach' iteration over the Tokyo Cabinet database. The iteration
    variables are key and value, both of type char[].
    
    Essentially, TchDbIterator invokes tchdbforeach(), adapting the D 'foreach'
    delegate to the callback function reference of tchdbforeach().
    
    The provided functionality should be reentrant/thread-safe.
    
    Usage example:
    
    ---
    
        import $(TITLE);
        
        class MyTokyo
        {
            TCHDB* hdb;
             
            // opApply forwarding to tchdbopapply():
             
            int opApply ( TchDbIterator.ForeachDelg delg )
            {
                return TchDbIterator.tchdbopapply(this.hdb, delg);
            }
        }
        
        void iterate ( )
        {
            auto database = new MyTokyo;
            
            foreach (key, value; database)
            {
                // "key" now contains the key and "val" the value of the current
                // database record
            }
        }
        
    ---
    
 ******************************************************************************/

struct TchDbIterator
{
    /**************************************************************************
    
        D 'foreach' delegate definition
    
     **************************************************************************/

    public alias int delegate ( ref char[] key, ref char[] val ) ForeachDelg;
    
    /**************************************************************************
    
        Invokes tchdbforeach() with the provided D 'foreach' delegate.
        
        Params:
            hdb:  TokyoCabinet database reference
            delg: D 'foreach' delegate
            
        Returns:
            false on to continue or true to stop iteration, complying to the
            return value prescripted for a D 'foreach' delegate.
          
     **************************************************************************/
    
    public static int tchdbopapply ( TCHDB* hdb, ForeachDelg delg )
    {
        return !tchdbforeach(hdb, &tchiter_callback, &delg);
    }
    
    /**************************************************************************
    
        tchdbforeach() callback function
        
        Assumes that the pointer to a D delegate of type ForeachDelg was passed
        to tchdbforeach() as custom reference parameter "op" (last argument of
        tchdbforeach()) and invokes this delegate.
        
        Params:
            kbuf = key buffer
            ksiz = key length (bytes)
            vbuf = value buffer
            ksiz = value length (bytes)
            op   = custom reference; contains the value of the last
                   tchdbforeach() argument "op". This must be a pointer to the D
                   delegate of type ForeachDelg to invoke.
            
        Returns:
            true on to continue or false to stop iteration, complying to the
            return value prescripted for the tchdbforeach() callback function.
          
     **************************************************************************/

    extern (C) private static bool tchiter_callback ( void* kbuf, int ksiz,
                                                      void* vbuf, int vsiz, void* op )
    in
    {
        assert (kbuf,       "tchiter: got null key from tchdbforeach()");
        assert (vbuf,       "tchiter: got null value from tchdbforeach()");
        assert (ksiz >= 0,  "tchiter: invalid key length from tchdbforeach()");
        assert (vsiz >= 0,  "tchiter: invalid value length from tchdbforeach()");
        assert (op,         "tchiter: got null op from tchdbforeach(); expected "
                            "pointer to ForeachDelg delegate");
    }
    body
    {
        char[] key = cast (char[]) kbuf[0 .. ksiz];
        char[] val = cast (char[]) vbuf[0 .. vsiz];
        
        ForeachDelg delg = *(cast (ForeachDelg*) op); 
        
        return !delg(key, val);
    }
}