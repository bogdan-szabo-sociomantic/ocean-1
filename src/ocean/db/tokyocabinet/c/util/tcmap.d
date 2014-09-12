module ocean.db.tokyocabinet.c.util.tcmap;

private import ocean.db.tokyocabinet.c.util.tclist: TCLIST;

extern (C):

/*************************************************************************************************
 * Hash map utility
 *************************************************************************************************/

struct TCMAP                                    /* type of structure for a map */
{
    TCMAPREC **buckets;                         /* bucket array */
    TCMAPREC *first;                            /* pointer to the first element */
    TCMAPREC *last;                             /* pointer to the last element */
    TCMAPREC *cur;                              /* pointer to the current element */
    uint  bnum;                                 /* number of buckets */
    ulong rnum;                                 /* number of records */
    ulong msiz;                                 /* total size of records */
};


    /* type of the pointer to a callback function to process record duplication.
    `vbuf' specifies the pointer to the region of the value.
    `vsiz' specifies the size of the region of the value.
    `sp' specifies the pointer to the variable into which the size of the region of the return
    value is assigned.
    `op' specifies the pointer to the optional opaque object.
    The return value is the pointer to the result object allocated with `malloc'.  It is
    released by the caller.  If it is `NULL', the record is not modified. */
//     void* (*TCPDPROC)(void* vbuf, int vsiz, int* sp, void* op);
 alias void* function (void* vbuf, int vsiz, int* sp, void* op) TCPDPROC;


struct _TCMAPREC                                /* type of structure for an element of a map */
{
    int ksiz;                                   /* size of the region of the key */
    int vsiz;                                   /* size of the region of the value */
    _TCMAPREC* left;                            /* pointer to the left child */
    _TCMAPREC* right;                           /* pointer to the right child */
    _TCMAPREC* prev;                            /* pointer to the previous element */
    _TCMAPREC* next;                            /* pointer to the next element */
};

alias _TCMAPREC TCMAPREC;

  /* Create a map object.
     The return value is the new map object. */
  TCMAP* tcmapnew();


  /* Create a map object with specifying the number of the buckets.
     `bnum' specifies the number of the buckets.
     The return value is the new map object. */
  TCMAP* tcmapnew2(uint bnum);


  /* Create a map object with initial string elements.
     `str' specifies the string of the first element.
     The other arguments are other elements.  They should be trailed by a `NULL' argument.
     The return value is the new map object.
     The key and the value of each record are situated one after the other. */
  TCMAP* tcmapnew3(char* str, ...);


  /* Copy a map object.
     `map' specifies the map object.
     The return value is the new map object equivalent to the specified object. */
  TCMAP* tcmapdup(TCMAP* map);


  /* Delete a map object.
     `map' specifies the map object.
     Note that the deleted object and its derivatives can not be used anymore. */
  void tcmapdel(TCMAP* map);


  /* Store a record into a map object.
     `map' specifies the map object.
     `kbuf' specifies the pointer to the region of the key.
     `ksiz' specifies the size of the region of the key.
     `vbuf' specifies the pointer to the region of the value.
     `vsiz' specifies the size of the region of the value.
     If a record with the same key exists in the map, it is overwritten. */
  void tcmapput(TCMAP* map, void* kbuf, int ksiz, void* vbuf, int vsiz);


  /* Store a string record into a map object.
     `map' specifies the map object.
     `kstr' specifies the string of the key.
     `vstr' specifies the string of the value.
     If a record with the same key exists in the map, it is overwritten. */
  void tcmapput2(TCMAP* map, char* kstr, char* vstr);


  /* Store a new record into a map object.
     `map' specifies the map object.
     `kbuf' specifies the pointer to the region of the key.
     `ksiz' specifies the size of the region of the key.
     `vbuf' specifies the pointer to the region of the value.
     `vsiz' specifies the size of the region of the value.
     If successful, the return value is true, else, it is false.
     If a record with the same key exists in the map, this function has no effect. */
  bool tcmapputkeep(TCMAP* map, void* kbuf, int ksiz, void* vbuf, int vsiz);


  /* Store a new string record into a map object.
     `map' specifies the map object.
     `kstr' specifies the string of the key.
     `vstr' specifies the string of the value.
     If successful, the return value is true, else, it is false.
     If a record with the same key exists in the map, this function has no effect. */
  bool tcmapputkeep2(TCMAP* map, char* kstr, char* vstr);


  /* Concatenate a value at the end of the value of the existing record in a map object.
     `map' specifies the map object.
     `kbuf' specifies the pointer to the region of the key.
     `ksiz' specifies the size of the region of the key.
     `vbuf' specifies the pointer to the region of the value.
     `vsiz' specifies the size of the region of the value.
     If there is no corresponding record, a new record is created. */
  void tcmapputcat(TCMAP* map, void* kbuf, int ksiz, void* vbuf, int vsiz);


  /* Concatenate a string value at the end of the value of the existing record in a map object.
     `map' specifies the map object.
     `kstr' specifies the string of the key.
     `vstr' specifies the string of the value.
     If there is no corresponding record, a new record is created. */
  void tcmapputcat2(TCMAP* map, char* kstr, char* vstr);


  /* Remove a record of a map object.
     `map' specifies the map object.
     `kbuf' specifies the pointer to the region of the key.
     `ksiz' specifies the size of the region of the key.
     If successful, the return value is true.  False is returned when no record corresponds to
     the specified key. */
  bool tcmapout(TCMAP* map, void* kbuf, int ksiz);


  /* Remove a string record of a map object.
     `map' specifies the map object.
     `kstr' specifies the string of the key.
     If successful, the return value is true.  False is returned when no record corresponds to
     the specified key. */
  bool tcmapout2(TCMAP* map, char* kstr);


  /* Retrieve a record in a map object.
     `map' specifies the map object.
     `kbuf' specifies the pointer to the region of the key.
     `ksiz' specifies the size of the region of the key.
     `sp' specifies the pointer to the variable into which the size of the region of the return
     value is assigned.
     If successful, the return value is the pointer to the region of the value of the
     corresponding record.  `NULL' is returned when no record corresponds.
     Because an additional zero code is appended at the end of the region of the return value,
     the return value can be treated as a character string. */
  void* tcmapget(TCMAP* map, void* kbuf, int ksiz, int* sp);


  /* Retrieve a string record in a map object.
     `map' specifies the map object.
     `kstr' specifies the string of the key.
     If successful, the return value is the string of the value of the corresponding record.
     `NULL' is returned when no record corresponds. */
  char* tcmapget2(TCMAP* map, char* kstr);


  /* Move a record to the edge of a map object.
     `map' specifies the map object.
     `kbuf' specifies the pointer to the region of a key.
     `ksiz' specifies the size of the region of the key.
     `head' specifies the destination which is the head if it is true or the tail if else.
     If successful, the return value is true.  False is returned when no record corresponds to
     the specified key. */
  bool tcmapmove(TCMAP* map, void* kbuf, int ksiz, bool head);


  /* Move a string record to the edge of a map object.
     `map' specifies the map object.
     `kstr' specifies the string of a key.
     `head' specifies the destination which is the head if it is true or the tail if else.
     If successful, the return value is true.  False is returned when no record corresponds to
     the specified key. */
  bool tcmapmove2(TCMAP* map, char* kstr, bool head);


  /* Initialize the iterator of a map object.
     `map' specifies the map object.
     The iterator is used in order to access the key of every record stored in the map object. */
  void tcmapiterinit(TCMAP* map);


  /* Get the next key of the iterator of a map object.
     `map' specifies the map object.
     `sp' specifies the pointer to the variable into which the size of the region of the return
     value is assigned.
     If successful, the return value is the pointer to the region of the next key, else, it is
     `NULL'.  `NULL' is returned when no record can be fetched from the iterator.
     Because an additional zero code is appended at the end of the region of the return value,
     the return value can be treated as a character string.
     The order of iteration is assured to be the same as the stored order. */
  void* tcmapiternext(TCMAP* map, int* sp);


  /* Get the next key string of the iterator of a map object.
     `map' specifies the map object.
     If successful, the return value is the pointer to the region of the next key, else, it is
     `NULL'.  `NULL' is returned when no record can be fetched from the iterator.
     The order of iteration is assured to be the same as the stored order. */
  char* tcmapiternext2(TCMAP* map);


  /* Get the number of records stored in a map object.
     `map' specifies the map object.
     The return value is the number of the records stored in the map object. */
  ulong tcmaprnum(TCMAP* map);


  /* Get the total size of memory used in a map object.
     `map' specifies the map object.
     The return value is the total size of memory used in a map object. */
  ulong tcmapmsiz(TCMAP* map);


  /* Create a list object containing all keys in a map object.
     `map' specifies the map object.
     The return value is the new list object containing all keys in the map object.
     Because the object of the return value is created with the function `tclistnew', it should
     be deleted with the function `tclistdel' when it is no longer in use. */
  TCLIST *tcmapkeys(TCMAP* map);


  /* Create a list object containing all values in a map object.
     `map' specifies the map object.
     The return value is the new list object containing all values in the map object.
     Because the object of the return value is created with the function `tclistnew', it should
     be deleted with the function `tclistdel' when it is no longer in use. */
  TCLIST *tcmapvals(TCMAP* map);


  /* Add an integer to a record in a map object.
     `map' specifies the map object.
     `kbuf' specifies the pointer to the region of the key.
     `ksiz' specifies the size of the region of the key.
     `num' specifies the additional value.
     The return value is the summation value.
     If the corresponding record exists, the value is treated as an integer and is added to.  If no
     record corresponds, a new record of the additional value is stored. */
  int tcmapaddint(TCMAP* map, void* kbuf, int ksiz, int num);


  /* Add a real number to a record in a map object.
     `map' specifies the map object.
     `kbuf' specifies the pointer to the region of the key.
     `ksiz' specifies the size of the region of the key.
     `num' specifies the additional value.
     The return value is the summation value.
     If the corresponding record exists, the value is treated as a real number and is added to.  If
     no record corresponds, a new record of the additional value is stored. */
  double tcmapadddouble(TCMAP* map, void* kbuf, int ksiz, double num);


  /* Clear a map object.
     `map' specifies the map object.
     All records are removed. */
  void tcmapclear(TCMAP* map);


  /* Remove front records of a map object.
     `map' specifies the map object.
     `num' specifies the number of records to be removed. */
  void tcmapcutfront(TCMAP* map, int num);


  /* Serialize a map object into a byte array.
     `map' specifies the map object.
     `sp' specifies the pointer to the variable into which the size of the region of the return
     value is assigned.
     The return value is the pointer to the region of the result serial region.
     Because the region of the return value is allocated with the `malloc' call, it should be
     released with the `free' call when it is no longer in use. */
  void* tcmapdump(TCMAP* map, int* sp);


  /* Create a map object from a serialized byte array.
     `ptr' specifies the pointer to the region of serialized byte array.
     `size' specifies the size of the region.
     The return value is a new map object.
     Because the object of the return value is created with the function `tcmapnew', it should be
     deleted with the function `tcmapdel' when it is no longer in use. */
  TCMAP* tcmapload(void* ptr, int size);



  /*************************************************************************************************
   * hash map (for experts)
   *************************************************************************************************/


  /* Store a record and make it semivolatile in a map object.
     `map' specifies the map object.
     `kbuf' specifies the pointer to the region of the key.
     `ksiz' specifies the size of the region of the key.
     `vbuf' specifies the pointer to the region of the value.
     `vsiz' specifies the size of the region of the value.
     If a record with the same key exists in the map, it is overwritten.  The record is moved to
     the tail. */
  void tcmapput3(TCMAP* map, void* kbuf, int ksiz, char* vbuf, int vsiz);


  /* Store a record of the value of two regions into a map object.
     `map' specifies the map object.
     `kbuf' specifies the pointer to the region of the key.
     `ksiz' specifies the size of the region of the key.
     `fvbuf' specifies the pointer to the former region of the value.
     `fvsiz' specifies the size of the former region of the value.
     `lvbuf' specifies the pointer to the latter region of the value.
     `lvsiz' specifies the size of the latter region of the value.
     If a record with the same key exists in the map, it is overwritten. */
  void tcmapput4(TCMAP* map, void* kbuf, int ksiz,
                 void* fvbuf, int fvsiz, void* lvbuf, int lvsiz);


  /* Concatenate a value at the existing record and make it semivolatile in a map object.
     `map' specifies the map object.
     `kbuf' specifies the pointer to the region of the key.
     `ksiz' specifies the size of the region of the key.
     `vbuf' specifies the pointer to the region of the value.
     `vsiz' specifies the size of the region of the value.
     If there is no corresponding record, a new record is created. */
  void tcmapputcat3(TCMAP* map, void* kbuf, int ksiz, void* vbuf, int vsiz);


  /* Store a record into a map object with a duplication handler.
     `map' specifies the map object.
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
  bool tcmapputproc(TCMAP* map, void* kbuf, int ksiz, void* vbuf, int vsiz,
                    TCPDPROC proc, void* op);


  /* Retrieve a semivolatile record in a map object.
     `map' specifies the map object.
     `kbuf' specifies the pointer to the region of the key.
     `ksiz' specifies the size of the region of the key.
     `sp' specifies the pointer to the variable into which the size of the region of the return
     value is assigned.
     If successful, the return value is the pointer to the region of the value of the
     corresponding record.  `NULL' is returned when no record corresponds.
     Because an additional zero code is appended at the end of the region of the return value,
     the return value can be treated as a character string.  The internal region of the returned
     record is moved to the tail so that the record will survive for a time under LRU cache
     algorithm removing records from the head. */
  void* tcmapget3(TCMAP* map, void* kbuf, int ksiz, int* sp);


  /* Retrieve a string record in a map object with specifying the default value string.
     `map' specifies the map object.
     `kstr' specifies the string of the key.
     `dstr' specifies the string of the default value.
     The return value is the string of the value of the corresponding record or the default value
     string. */
  char* tcmapget4(TCMAP* map, char* kstr, char* dstr);


  /* Initialize the iterator of a map object at the record corresponding a key.
     `map' specifies the map object.
     `kbuf' specifies the pointer to the region of the key.
     `ksiz' specifies the size of the region of the key.
     If there is no record corresponding the condition, the iterator is not modified. */
  void tcmapiterinit2(TCMAP* map, void* kbuf, int ksiz);


  /* Initialize the iterator of a map object at the record corresponding a key string.
     `map' specifies the map object.
     `kstr' specifies the string of the key.
     If there is no record corresponding the condition, the iterator is not modified. */
  void tcmapiterinit3(TCMAP* map, char* kstr);


  /* Get the value bound to the key fetched from the iterator of a map object.
     `kbuf' specifies the pointer to the region of the iteration key.
     `sp' specifies the pointer to the variable into which the size of the region of the return
     value is assigned.
     The return value is the pointer to the region of the value of the corresponding record.
     Because an additional zero code is appended at the end of the region of the return value,
     the return value can be treated as a character string. */
  void* tcmapiterval(void* kbuf, int* sp);


  /* Get the value string bound to the key fetched from the iterator of a map object.
     `kstr' specifies the string of the iteration key.
     The return value is the pointer to the region of the value of the corresponding record. */
  char* tcmapiterval2(char* kstr);


  /* Create an array of strings of all keys in a map object.
     `map' specifies the map object.
     `np' specifies the pointer to a variable into which the number of elements of the return value
     is assigned.
     The return value is the pointer to the array of all string keys in the map object.
     Because the region of the return value is allocated with the `malloc' call, it should be
     released with the `free' call if when is no longer in use.  Note that elements of the array
     point to the inner objects, whose life duration is synchronous with the map object. */
  char* *tcmapkeys2(TCMAP* map, int* np);


  /* Create an array of strings of all values in a map object.
     `map' specifies the map object.
     `np' specifies the pointer to a variable into which the number of elements of the return value
     is assigned.
     The return value is the pointer to the array of all string values in the map object.
     Because the region of the return value is allocated with the `malloc' call, it should be
     released with the `free' call if when is no longer in use.  Note that elements of the array
     point to the inner objects, whose life duration is synchronous with the map object. */
  char* *tcmapvals2(TCMAP* map, int* np);


  /* Extract a map record from a serialized byte array.
     `ptr' specifies the pointer to the region of serialized byte array.
     `size' specifies the size of the region.
     `kbuf' specifies the pointer to the region of the key.
     `ksiz' specifies the size of the region of the key.
     `sp' specifies the pointer to the variable into which the size of the region of the return
     value is assigned.
     If successful, the return value is the pointer to the region of the value of the
     corresponding record.  `NULL' is returned when no record corresponds.
     Because an additional zero code is appended at the end of the region of the return value,
     the return value can be treated as a character string. */
  void* tcmaploadone(void* ptr, int size, void* kbuf, int ksiz, int* sp);


  /* Perform formatted output into a map object.
     `map' specifies the map object.
     `kstr' specifies the string of the key.
     `format' specifies the printf-like format string.  The conversion character `%' can be used
     with such flag characters as `s', `d', `o', `u', `x', `X', `c', `e', `E', `f', `g', `G', `@',
     `?', `b', and `%'.  `@' works as with `s' but escapes meta characters of XML.  `?' works as
     with `s' but escapes meta characters of URL.  `b' converts an integer to the string as binary
     numbers.  The other conversion character work as with each original.
     The other arguments are used according to the format string. */
  void tcmapprintf(TCMAP* map, char* kstr, char* format, ...);
