module ocean.db.tokyocabinet.c.tcmdb;

import ocean.db.tokyocabinet.c.util.tclist: TCLIST;
import ocean.db.tokyocabinet.c.util.tcmap:  TCMAP, TCPDPROC;

/*************************************************************************************************
 * On-memory hash database
 *************************************************************************************************/

extern (C):

/* type of the pointer to a iterator function.
`kbuf' specifies the pointer to the region of the key.
`ksiz' specifies the size of the region of the key.
`vbuf' specifies the pointer to the region of the value.
`vsiz' specifies the size of the region of the value.
`op' specifies the pointer to the optional opaque object.
The return value is true to continue iteration or false to stop iteration. */
// bool (*TCITER)(void* kbuf, int ksiz, void* vbuf, int vsiz, void* op);
alias bool function (void* kbuf, int ksiz, void* vbuf, int vsiz, void* op) TCITER;


struct TCMDB
{                                               /* type of structure for a on-memory hash database */
    void**  mmtxs;                              /* mutexes for method */
    void*   imtx;                               /* mutex for iterator */
    TCMAP** maps;                               /* internal map objects */
    int iter;                                   /* index of maps for the iterator */
};

/* Create an on-memory hash database object.
   The return value is the new on-memory hash database object.
   The object can be shared by plural threads because of the internal mutex. */
TCMDB* tcmdbnew();


/* Create an on-memory hash database object with specifying the number of the buckets.
   `bnum' specifies the number of the buckets.
   The return value is the new on-memory hash database object.
   The object can be shared by plural threads because of the internal mutex. */
TCMDB* tcmdbnew2(uint bnum);


/* Delete an on-memory hash database object.
   `mdb' specifies the on-memory hash database object. */
void tcmdbdel(TCMDB* mdb);


/* Store a record into an on-memory hash database object.
   `mdb' specifies the on-memory hash database object.
   `kbuf' specifies the pointer to the region of the key.
   `ksiz' specifies the size of the region of the key.
   `vbuf' specifies the pointer to the region of the value.
   `vsiz' specifies the size of the region of the value.
   If a record with the same key exists in the database, it is overwritten. */
void tcmdbput(TCMDB* mdb, void* kbuf, int ksiz, void* vbuf, int vsiz);


/* Store a string record into an on-memory hash database object.
   `mdb' specifies the on-memory hash database object.
   `kstr' specifies the string of the key.
   `vstr' specifies the string of the value.
   If a record with the same key exists in the database, it is overwritten. */
void tcmdbput2(TCMDB* mdb, char* kstr, char* vstr);


/* Store a new record into an on-memory hash database object.
   `mdb' specifies the on-memory hash database object.
   `kbuf' specifies the pointer to the region of the key.
   `ksiz' specifies the size of the region of the key.
   `vbuf' specifies the pointer to the region of the value.
   `vsiz' specifies the size of the region of the value.
   If successful, the return value is true, else, it is false.
   If a record with the same key exists in the database, this function has no effect. */
bool tcmdbputkeep(TCMDB* mdb, void* kbuf, int ksiz, void* vbuf, int vsiz);


/* Store a new string record into an on-memory hash database object.
   `mdb' specifies the on-memory hash database object.
   `kstr' specifies the string of the key.
   `vstr' specifies the string of the value.
   If successful, the return value is true, else, it is false.
   If a record with the same key exists in the database, this function has no effect. */
bool tcmdbputkeep2(TCMDB* mdb, char* kstr, char* vstr);


/* Concatenate a value at the end of the existing record in an on-memory hash database.
   `mdb' specifies the on-memory hash database object.
   `kbuf' specifies the pointer to the region of the key.
   `ksiz' specifies the size of the region of the key.
   `vbuf' specifies the pointer to the region of the value.
   `vsiz' specifies the size of the region of the value.
   If there is no corresponding record, a new record is created. */
void tcmdbputcat(TCMDB* mdb, void* kbuf, int ksiz, void* vbuf, int vsiz);


/* Concatenate a string at the end of the existing record in an on-memory hash database.
   `mdb' specifies the on-memory hash database object.
   `kstr' specifies the string of the key.
   `vstr' specifies the string of the value.
   If there is no corresponding record, a new record is created. */
void tcmdbputcat2(TCMDB* mdb, char* kstr, char* vstr);


/* Remove a record of an on-memory hash database object.
   `mdb' specifies the on-memory hash database object.
   `kbuf' specifies the pointer to the region of the key.
   `ksiz' specifies the size of the region of the key.
   If successful, the return value is true.  False is returned when no record corresponds to
   the specified key. */
bool tcmdbout(TCMDB* mdb, in void* kbuf, int ksiz);


/* Remove a string record of an on-memory hash database object.
   `mdb' specifies the on-memory hash database object.
   `kstr' specifies the string of the key.
   If successful, the return value is true.  False is returned when no record corresponds to
   the specified key. */
bool tcmdbout2(TCMDB* mdb, char* kstr);


/* Retrieve a record in an on-memory hash database object.
   `mdb' specifies the on-memory hash database object.
   `kbuf' specifies the pointer to the region of the key.
   `ksiz' specifies the size of the region of the key.
   `sp' specifies the pointer to the variable into which the size of the region of the return
   value is assigned.
   If successful, the return value is the pointer to the region of the value of the
   corresponding record.  `NULL' is returned when no record corresponds.
   Because an additional zero code is appended at the end of the region of the return value,
   the return value can be treated as a character string.  Because the region of the return
   value is allocated with the `malloc' call, it should be released with the `free' call when
   it is no longer in use. */
void* tcmdbget(TCMDB* mdb, in void* kbuf, int ksiz, int* sp);


/* Retrieve a string record in an on-memory hash database object.
   `mdb' specifies the on-memory hash database object.
   `kstr' specifies the string of the key.
   If successful, the return value is the string of the value of the corresponding record.
   `NULL' is returned when no record corresponds.
   Because the region of the return value is allocated with the `malloc' call, it should be
   released with the `free' call when it is no longer in use. */
char* tcmdbget2(TCMDB* mdb, in char* kstr);


/* Get the size of the value of a record in an on-memory hash database object.
   `mdb' specifies the on-memory hash database object.
   `kbuf' specifies the pointer to the region of the key.
   `ksiz' specifies the size of the region of the key.
   If successful, the return value is the size of the value of the corresponding record, else,
   it is -1. */
int tcmdbvsiz(TCMDB* mdb, in void* kbuf, int ksiz);


/* Get the size of the value of a string record in an on-memory hash database object.
   `mdb' specifies the on-memory hash database object.
   `kstr' specifies the string of the key.
   If successful, the return value is the size of the value of the corresponding record, else,
   it is -1. */
int tcmdbvsiz2(TCMDB* mdb, char* kstr);


/* Initialize the iterator of an on-memory hash database object.
   `mdb' specifies the on-memory hash database object.
   The iterator is used in order to access the key of every record stored in the on-memory
   database. */
void tcmdbiterinit(TCMDB* mdb);


/* Get the next key of the iterator of an on-memory hash database object.
   `mdb' specifies the on-memory hash database object.
   `sp' specifies the pointer to the variable into which the size of the region of the return
   value is assigned.
   If successful, the return value is the pointer to the region of the next key, else, it is
   `NULL'.  `NULL' is returned when no record can be fetched from the iterator.
   Because an additional zero code is appended at the end of the region of the return value,
   the return value can be treated as a character string.  Because the region of the return
   value is allocated with the `malloc' call, it should be released with the `free' call when
   it is no longer in use.  The order of iteration is assured to be the same as the stored
   order. */
void* tcmdbiternext(TCMDB* mdb, int* sp);


/* Get the next key string of the iterator of an on-memory hash database object.
   `mdb' specifies the on-memory hash database object.
   If successful, the return value is the pointer to the region of the next key, else, it is
   `NULL'.  `NULL' is returned when no record can be fetched from the iterator.
   Because the region of the return value is allocated with the `malloc' call, it should be
   released with the `free' call when it is no longer in use.  The order of iteration is assured
   to be the same as the stored order. */
char* tcmdbiternext2(TCMDB* mdb);


/* Get forward matching keys in an on-memory hash database object.
   `mdb' specifies the on-memory hash database object.
   `pbuf' specifies the pointer to the region of the prefix.
   `psiz' specifies the size of the region of the prefix.
   `max' specifies the maximum number of keys to be fetched.  If it is negative, no limit is
   specified.
   The return value is a list object of the corresponding keys.  This function does never fail.
   It returns an empty list even if no key corresponds.
   Because the object of the return value is created with the function `tclistnew', it should be
   deleted with the function `tclistdel' when it is no longer in use.  Note that this function
   may be very slow because every key in the database is scanned. */
TCLIST *tcmdbfwmkeys(TCMDB* mdb, void* pbuf, int psiz, int max);


/* Get forward matching string keys in an on-memory hash database object.
   `mdb' specifies the on-memory hash database object.
   `pstr' specifies the string of the prefix.
   `max' specifies the maximum number of keys to be fetched.  If it is negative, no limit is
   specified.
   The return value is a list object of the corresponding keys.  This function does never fail.
   It returns an empty list even if no key corresponds.
   Because the object of the return value is created with the function `tclistnew', it should be
   deleted with the function `tclistdel' when it is no longer in use.  Note that this function
   may be very slow because every key in the database is scanned. */
TCLIST *tcmdbfwmkeys2(TCMDB* mdb, char* pstr, int max);


/* Get the number of records stored in an on-memory hash database object.
   `mdb' specifies the on-memory hash database object.
   The return value is the number of the records stored in the database. */
ulong tcmdbrnum(TCMDB* mdb);


/* Get the total size of memory used in an on-memory hash database object.
   `mdb' specifies the on-memory hash database object.
   The return value is the total size of memory used in the database. */
ulong tcmdbmsiz(TCMDB* mdb);


/* Add an integer to a record in an on-memory hash database object.
   `mdb' specifies the on-memory hash database object.
   `kbuf' specifies the pointer to the region of the key.
   `ksiz' specifies the size of the region of the key.
   `num' specifies the additional value.
   The return value is the summation value.
   If the corresponding record exists, the value is treated as an integer and is added to.  If no
   record corresponds, a new record of the additional value is stored. */
int tcmdbaddint(TCMDB* mdb, void* kbuf, int ksiz, int num);


/* Add a real number to a record in an on-memory hash database object.
   `mdb' specifies the on-memory hash database object.
   `kbuf' specifies the pointer to the region of the key.
   `ksiz' specifies the size of the region of the key.
   `num' specifies the additional value.
   The return value is the summation value.
   If the corresponding record exists, the value is treated as a real number and is added to.  If
   no record corresponds, a new record of the additional value is stored. */
double tcmdbadddouble(TCMDB* mdb, void* kbuf, int ksiz, double num);


/* Clear an on-memory hash database object.
   `mdb' specifies the on-memory hash database object.
   All records are removed. */
void tcmdbvanish(TCMDB* mdb);


/* Remove front records of an on-memory hash database object.
   `mdb' specifies the on-memory hash database object.
   `num' specifies the number of records to be removed. */
void tcmdbcutfront(TCMDB* mdb, int num);



/*************************************************************************************************
 * on-memory hash database (for experts)
 *************************************************************************************************/


/* Store a record and make it semivolatile in an on-memory hash database object.
   `mdb' specifies the on-memory hash database object.
   `kbuf' specifies the pointer to the region of the key.
   `ksiz' specifies the size of the region of the key.
   `vbuf' specifies the pointer to the region of the value.
   `vsiz' specifies the size of the region of the value.
   If a record with the same key exists in the map, it is overwritten.  The record is moved to
   the tail. */
void tcmdbput3(TCMDB* mdb, void* kbuf, int ksiz, char* vbuf, int vsiz);


/* Store a record of the value of two regions into an on-memory hash database object.
   `mdb' specifies the on-memory hash database object.
   `kbuf' specifies the pointer to the region of the key.
   `ksiz' specifies the size of the region of the key.
   `fvbuf' specifies the pointer to the former region of the value.
   `fvsiz' specifies the size of the former region of the value.
   `lvbuf' specifies the pointer to the latter region of the value.
   `lvsiz' specifies the size of the latter region of the value.
   If a record with the same key exists in the database, it is overwritten. */
void tcmdbput4(TCMDB* mdb, void* kbuf, int ksiz,
               void* fvbuf, int fvsiz, void* lvbuf, int lvsiz);


/* Concatenate a value and make it semivolatile in on-memory hash database object.
   `mdb' specifies the on-memory hash database object.
   `kbuf' specifies the pointer to the region of the key.
   `ksiz' specifies the size of the region of the key.
   `vbuf' specifies the pointer to the region of the value.
   `vsiz' specifies the size of the region of the value.
   If there is no corresponding record, a new record is created. */
void tcmdbputcat3(TCMDB* mdb, void* kbuf, int ksiz, void* vbuf, int vsiz);


/* Store a record into a on-memory hash database object with a duplication handler.
   `mdb' specifies the on-memory hash database object.
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
   not modified.  If it is `(void* )-1', the record is removed.
   `op' specifies an arbitrary pointer to be given as a parameter of the callback function.  If
   it is not needed, `NULL' can be specified.
   If successful, the return value is true, else, it is false. */
bool tcmdbputproc(TCMDB* mdb, void* kbuf, int ksiz, void* vbuf, int vsiz,
                  TCPDPROC proc, void* op);


/* Retrieve a record and move it astern in an on-memory hash database object.
   `mdb' specifies the on-memory hash database object.
   `kbuf' specifies the pointer to the region of the key.
   `ksiz' specifies the size of the region of the key.
   `sp' specifies the pointer to the variable into which the size of the region of the return
   value is assigned.
   If successful, the return value is the pointer to the region of the value of the
   corresponding record.  `NULL' is returned when no record corresponds.
   Because an additional zero code is appended at the end of the region of the return value,
   the return value can be treated as a character string.  Because the region of the return value
   is allocated with the `malloc' call, it should be released with the `free' call when it is no
   longer in use.  The internal region of the returned record is moved to the tail so that the
   record will survive for a time under LRU cache algorithm removing records from the head. */
void* tcmdbget3(TCMDB* mdb, in void* kbuf, int ksiz, int* sp);


/* Initialize the iterator of an on-memory map database object in front of a key.
   `mdb' specifies the on-memory map database object.
   `kbuf' specifies the pointer to the region of the key.
   `ksiz' specifies the size of the region of the key.
   If there is no record corresponding the condition, the iterator is not modified. */
void tcmdbiterinit2(TCMDB* mdb, void* kbuf, int ksiz);


/* Initialize the iterator of an on-memory map database object in front of a key string.
   `mdb' specifies the on-memory map database object.
   `kstr' specifies the string of the key.
   If there is no record corresponding the condition, the iterator is not modified. */
void tcmdbiterinit3(TCMDB* mdb, char* kstr);


/* Process each record atomically of an on-memory hash database object.
   `iter' specifies the pointer to the iterator function called for each record.  It receives
   five parameters.  The first parameter is the pointer to the region of the key.  The second
   parameter is the size of the region of the key.  The third parameter is the pointer to the
   region of the value.  The fourth parameter is the size of the region of the value.  The fifth
   parameter is the pointer to the optional opaque object.  It returns true to continue iteration
   or false to stop iteration.
   `op' specifies an arbitrary pointer to be given as a parameter of the iterator function.  If
   it is not needed, `NULL' can be specified. */
void tcmdbforeach(TCMDB* mdb, TCITER iter, void* op);
