module ocean.db.tokyocabinet.c.bdb.tcbdbcur;

private import ocean.db.tokyocabinet.c.tcbdb:       TCBDB;
private import ocean.db.tokyocabinet.c.util.tcxstr: TCXSTR;

extern (C):

/*************************************************************************************************
 * B+tree cursor utility
 *************************************************************************************************/

struct BDBCUR                           /* type of structure for a B+ tree cursor */
{
    TCBDB* bdb;                         /* database object */
    ulong clock;                        /* logical clock */
    ulong id;                           /* ID number of the leaf */
    int kidx;                           /* number of the key */
    int vidx;                           /* number of the value */
};

enum BDBCP : int                        /* enumeration for cursor put mode */
{
    BDBCPCURRENT,                       /* current */
    BDBCPBEFORE,                        /* before */
    BDBCPAFTER                          /* after */
};

    /* Create a cursor object.
    `bdb' specifies the B+ tree database object.
    The return value is the new cursor object.
    Note that the cursor is available only after initialization with the `tcbdbcurfirst' or the
    `tcbdbcurjump' functions and so on.  Moreover, the position of the cursor will be indefinite
    when the database is updated after the initialization of the cursor. */
 BDBCUR* tcbdbcurnew(TCBDB* bdb);


 /* Delete a cursor object.
    `cur' specifies the cursor object. */
 void tcbdbcurdel(BDBCUR* cur);


 /* Move a cursor object to the first record.
    `cur' specifies the cursor object.
    If successful, the return value is true, else, it is false.  False is returned if there is
    no record in the database. */
 bool tcbdbcurfirst(BDBCUR* cur);


 /* Move a cursor object to the last record.
    `cur' specifies the cursor object.
    If successful, the return value is true, else, it is false.  False is returned if there is
    no record in the database. */
 bool tcbdbcurlast(BDBCUR* cur);


 /* Move a cursor object to the front of records corresponding a key.
    `cur' specifies the cursor object.
    `kbuf' specifies the pointer to the region of the key.
    `ksiz' specifies the size of the region of the key.
    If successful, the return value is true, else, it is false.  False is returned if there is
    no record corresponding the condition.
    The cursor is set to the first record corresponding the key or the next substitute if
    completely matching record does not exist. */
 bool tcbdbcurjump(BDBCUR* cur, void* kbuf, int ksiz);


 /* Move a cursor object to the front of records corresponding a key string.
    `cur' specifies the cursor object.
    `kstr' specifies the string of the key.
    If successful, the return value is true, else, it is false.  False is returned if there is
    no record corresponding the condition.
    The cursor is set to the first record corresponding the key or the next substitute if
    completely matching record does not exist. */
 bool tcbdbcurjump2(BDBCUR* cur, char* kstr);


 /* Move a cursor object to the previous record.
    `cur' specifies the cursor object.
    If successful, the return value is true, else, it is false.  False is returned if there is
    no previous record. */
 bool tcbdbcurprev(BDBCUR* cur);


 /* Move a cursor object to the next record.
    `cur' specifies the cursor object.
    If successful, the return value is true, else, it is false.  False is returned if there is
    no next record. */
 bool tcbdbcurnext(BDBCUR* cur);


 /* Insert a record around a cursor object.
    `cur' specifies the cursor object of writer connection.
    `vbuf' specifies the pointer to the region of the value.
    `vsiz' specifies the size of the region of the value.
    `cpmode' specifies detail adjustment: `BDBCPCURRENT', which means that the value of the
    current record is overwritten, `BDBCPBEFORE', which means that the new record is inserted
    before the current record, `BDBCPAFTER', which means that the new record is inserted after the
    current record.
    If successful, the return value is true, else, it is false.  False is returned when the cursor
    is at invalid position.
    After insertion, the cursor is moved to the inserted record. */
 bool tcbdbcurput(BDBCUR* cur, void* vbuf, int vsiz, BDBCP cpmode);


 /* Insert a string record around a cursor object.
    `cur' specifies the cursor object of writer connection.
    `vstr' specifies the string of the value.
    `cpmode' specifies detail adjustment: `BDBCPCURRENT', which means that the value of the
    current record is overwritten, `BDBCPBEFORE', which means that the new record is inserted
    before the current record, `BDBCPAFTER', which means that the new record is inserted after the
    current record.
    If successful, the return value is true, else, it is false.  False is returned when the cursor
    is at invalid position.
    After insertion, the cursor is moved to the inserted record. */
 bool tcbdbcurput2(BDBCUR* cur, char* vstr, BDBCP cpmode);


 /* Remove the record where a cursor object is.
    `cur' specifies the cursor object of writer connection.
    If successful, the return value is true, else, it is false.  False is returned when the cursor
    is at invalid position.
    After deletion, the cursor is moved to the next record if possible. */
 bool tcbdbcurout(BDBCUR* cur);


 /* Get the key of the record where the cursor object is.
    `cur' specifies the cursor object.
    `sp' specifies the pointer to the variable into which the size of the region of the return
    value is assigned.
    If successful, the return value is the pointer to the region of the key, else, it is `NULL'.
    `NULL' is returned when the cursor is at invalid position.
    Because an additional zero code is appended at the end of the region of the return value,
    the return value can be treated as a character string.  Because the region of the return
    value is allocated with the `malloc' call, it should be released with the `free' call when
    it is no longer in use. */
 void* tcbdbcurkey(BDBCUR* cur, int* sp);


 /* Get the key string of the record where the cursor object is.
    `cur' specifies the cursor object.
    If successful, the return value is the string of the key, else, it is `NULL'.  `NULL' is
    returned when the cursor is at invalid position.
    Because the region of the return value is allocated with the `malloc' call, it should be
    released with the `free' call when it is no longer in use. */
 char* tcbdbcurkey2(BDBCUR* cur);


 /* Get the key of the record where the cursor object is, as a volatile buffer.
    `cur' specifies the cursor object.
    `sp' specifies the pointer to the variable into which the size of the region of the return
    value is assigned.
    If successful, the return value is the pointer to the region of the key, else, it is `NULL'.
    `NULL' is returned when the cursor is at invalid position.
    Because an additional zero code is appended at the end of the region of the return value,
    the return value can be treated as a character string.  Because the region of the return value
    is volatile and it may be spoiled by another operation of the database, the data should be
    copied into another involatile buffer immediately. */
 void* tcbdbcurkey3(BDBCUR* cur, int* sp);


 /* Get the value of the record where the cursor object is.
    `cur' specifies the cursor object.
    `sp' specifies the pointer to the variable into which the size of the region of the return
    value is assigned.
    If successful, the return value is the pointer to the region of the value, else, it is `NULL'.
    `NULL' is returned when the cursor is at invalid position.
    Because an additional zero code is appended at the end of the region of the return value,
    the return value can be treated as a character string.  Because the region of the return
    value is allocated with the `malloc' call, it should be released with the `free' call when
    it is no longer in use. */
 void* tcbdbcurval(BDBCUR* cur, int* sp);


 /* Get the value string of the record where the cursor object is.
    `cur' specifies the cursor object.
    If successful, the return value is the string of the value, else, it is `NULL'.  `NULL' is
    returned when the cursor is at invalid position.
    Because the region of the return value is allocated with the `malloc' call, it should be
    released with the `free' call when it is no longer in use. */
 char* tcbdbcurval2(BDBCUR* cur);


 /* Get the value of the record where the cursor object is, as a volatile buffer.
    `cur' specifies the cursor object.
    `sp' specifies the pointer to the variable into which the size of the region of the return
    value is assigned.
    If successful, the return value is the pointer to the region of the value, else, it is `NULL'.
    `NULL' is returned when the cursor is at invalid position.
    Because an additional zero code is appended at the end of the region of the return value,
    the return value can be treated as a character string.  Because the region of the return value
    is volatile and it may be spoiled by another operation of the database, the data should be
    copied into another involatile buffer immediately. */
 void* tcbdbcurval3(BDBCUR* cur, int* sp);


 /* Get the key and the value of the record where the cursor object is.
    `cur' specifies the cursor object.
    `kxstr' specifies the object into which the key is wrote down.
    `vxstr' specifies the object into which the value is wrote down.
    If successful, the return value is true, else, it is false.  False is returned when the cursor
    is at invalid position. */
 bool tcbdbcurrec(BDBCUR* cur, TCXSTR* kxstr, TCXSTR* vxstr);

 /* Move a cursor object to the rear of records corresponding a key.
 `cur' specifies the cursor object.
 `kbuf' specifies the pointer to the region of the key.
 `ksiz' specifies the size of the region of the key.
 If successful, the return value is true, else, it is false.  False is returned if there is
 no record corresponding the condition.
 The cursor is set to the last record corresponding the key or the previous substitute if
 completely matching record does not exist. */
bool tcbdbcurjumpback(BDBCUR* cur, void* kbuf, int ksiz);


/* Move a cursor object to the rear of records corresponding a key string.
 `cur' specifies the cursor object.
 `kstr' specifies the string of the key.
 If successful, the return value is true, else, it is false.  False is returned if there is
 no record corresponding the condition.
 The cursor is set to the last record corresponding the key or the previous substitute if
 completely matching record does not exist. */
bool tcbdbcurjumpback2(BDBCUR* cur, char* kstr);
