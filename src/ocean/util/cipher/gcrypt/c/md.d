/*******************************************************************************

    Cryptograhic Hash Functions

    Requires linking with libgcrypt:

        -L-lgcrypt

    Copyright:
        Copyright (c) 2009-2016, Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.util.cipher.gcrypt.c.md;

public import ocean.util.cipher.gcrypt.c.general;

import ocean.transition;

extern (C):

/* Algorithm IDs for the hash functions we know about. Not all of them
   are implemnted. */
enum gcry_md_algos
{
    GCRY_MD_NONE    = 0,
    GCRY_MD_MD5     = 1,
    GCRY_MD_SHA1    = 2,
    GCRY_MD_RMD160  = 3,
    GCRY_MD_MD2     = 5,
    GCRY_MD_TIGER   = 6,   /* TIGER/192 as used by gpg <= 1.3.2. */
    GCRY_MD_HAVAL   = 7,   /* HAVAL, 5 pass, 160 bit. */
    GCRY_MD_SHA256  = 8,
    GCRY_MD_SHA384  = 9,
    GCRY_MD_SHA512  = 10,
    GCRY_MD_SHA224  = 11,
    GCRY_MD_MD4     = 301,
    GCRY_MD_CRC32         = 302,
    GCRY_MD_CRC32_RFC1510 = 303,
    GCRY_MD_CRC24_RFC2440 = 304,
    GCRY_MD_WHIRLPOOL = 305,
    GCRY_MD_TIGER1  = 306, /* TIGER fixed.  */
    GCRY_MD_TIGER2  = 307  /* TIGER2 variant.   */
}

/* Flags used with the open function.  */
enum gcry_md_flags
{
    GCRY_MD_FLAG_SECURE = 1,  /* Allocate all buffers in "secure" memory.  */
    GCRY_MD_FLAG_HMAC   = 2   /* Make an HMAC out of this algorithm.  */
}

// This object is used to hold a handle to a message digest object.
struct gcry_md_handle;
alias gcry_md_handle* gcry_md_hd_t;

/* Create a message digest object for algorithm ALGO.  FLAGS may be
   given as an bitwise OR of the gcry_md_flags values.  ALGO may be
   given as 0 if the algorithms to be used are later set using
   gcry_md_enable.  */
gcry_error_t gcry_md_open (gcry_md_hd_t* h, gcry_md_algos algo, gcry_md_flags flags);

/* Release the message digest object HD.  */
void gcry_md_close (gcry_md_hd_t hd);

/* Add the message digest algorithm ALGO to the digest object HD.  */
gcry_error_t gcry_md_enable (gcry_md_hd_t hd, gcry_md_algos algo);

/* Create a new digest object as an exact copy of the object HD.  */
gcry_error_t gcry_md_copy (gcry_md_hd_t* bhd, gcry_md_hd_t ahd);

/* Reset the digest object HD to its initial state.  */
void gcry_md_reset (gcry_md_hd_t hd);

/* Perform various operations on the digest object HD. */
gcry_error_t gcry_md_ctl (gcry_md_hd_t hd, int cmd,
                          void* buffer, size_t buflen);

/* Pass LENGTH bytes of data in BUFFER to the digest object HD so that
   it can update the digest values.  This is the actual hash
   function. */
void gcry_md_write (gcry_md_hd_t hd, Const!(void)* buffer, size_t length);

/* Read out the final digest from HD return the digest value for
   algorithm ALGO. */
ubyte* gcry_md_read (gcry_md_hd_t hd, gcry_md_algos algo = gcry_md_algos.init);

extern (D) ubyte[] gcry_md_read_slice (gcry_md_hd_t hd, gcry_md_algos algo = gcry_md_algos.init)
{
    if (ubyte* data = gcry_md_read(hd, algo))
    {
        return data[0 .. gcry_md_get_algo_dlen(algo? algo : gcry_md_get_algo(hd))];
    }
    else
    {
        return null;
    }
}

/* Convenience function to calculate the hash from the data in BUFFER
   of size LENGTH using the algorithm ALGO avoiding the creating of a
   hash object.  The hash is returned in the caller provided buffer
   DIGEST which must be large enough to hold the digest of the given
   algorithm. */
void gcry_md_hash_buffer (gcry_md_algos algo, void* digest,
                          Const!(void)* buffer, size_t length);

/* Retrieve the algorithm used with HD.  This does not work reliable
   if more than one algorithm is enabled in HD. */
gcry_md_algos gcry_md_get_algo (gcry_md_hd_t hd);

/* Retrieve the length in bytes of the digest yielded by algorithm
   ALGO. */
uint gcry_md_get_algo_dlen (gcry_md_algos algo);

/* Return true if the the algorithm ALGO is enabled in the digest
   object A. */
int gcry_md_is_enabled (gcry_md_hd_t a, gcry_md_algos algo);

/* Return true if the digest object A is allocated in "secure" memory. */
int gcry_md_is_secure (gcry_md_hd_t a);

/* Retrieve various information about the object H.  */
gcry_error_t gcry_md_info (gcry_md_hd_t h, gcry_ctl_cmds what, void* buffer,
                          size_t* nbytes);

/* Retrieve various information about the algorithm ALGO.  */
gcry_error_t gcry_md_algo_info (gcry_md_algos algo, gcry_ctl_cmds what, void* buffer,
                               size_t* nbytes);

/* Map the digest algorithm id ALGO to a string representation of the
   algorithm name.  For unknown algorithms this function returns
   "?". */
Const!(char)* gcry_md_algo_name (gcry_md_algos algo);

/* Map the algorithm NAME to a digest algorithm Id.  Return 0 if
   the algorithm name is not known. */
int gcry_md_map_name (Const!(char)* name);

/* For use with the HMAC feature, the set MAC key to the KEY of
   KEYLEN bytes. */
gcry_error_t gcry_md_setkey (gcry_md_hd_t hd, Const!(void)* key, size_t keylen);

/* Start or stop debugging for digest handle HD; i.e. create a file
   named dbgmd-<n>.<suffix> while hashing.  If SUFFIX is NULL,
   debugging stops and the file will be closed. */
void gcry_md_debug (gcry_md_hd_t hd, Const!(char)* suffix);


/* Return 0 if the algorithm A is available for use. */
extern (D) gcry_error_t gcry_md_test_algo(gcry_md_algos a)
{
    return gcry_md_algo_info(a, gcry_ctl_cmds.GCRYCTL_TEST_ALGO, null, null);
}

/* Return an DER encoded ASN.1 OID for the algorithm A in buffer B. N
   must point to size_t variable with the available size of buffer B.
   After return it will receive the actual size of the returned
   OID. */
extern (D) gcry_error_t gcry_md_get_asnoid(gcry_md_algos a, ref ubyte[] b)
{
    size_t len = b.length;

    if (auto error = gcry_md_algo_info(a, gcry_ctl_cmds.GCRYCTL_GET_ASNOID, b.ptr, &len))
    {
        return error;
    }
    else
    {
        b = b[0 .. len];
        return 0;
    }
}

/* Get a list consisting of the IDs of the loaded message digest
   modules.  If LIST is zero, write the number of loaded message
   digest modules to LIST_LENGTH and return.  If LIST is non-zero, the
   first *LIST_LENGTH algorithm IDs are stored in LIST, which must be
   of according size.  In case there are less message digest modules
   than *LIST_LENGTH, *LIST_LENGTH is updated to the correct
   number.  */
gcry_error_t gcry_md_list (int* list, int* list_length);
