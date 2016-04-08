/*******************************************************************************

    Requires linking with libgcrypt:

        -L-lgcrypt

    Copyright: Copyright (c) 2015 sociomantic labs. All rights reserved

*******************************************************************************/

module ocean.util.cipher.gcrypt.c.gcrypt;

import ocean.transition;

public import ocean.util.cipher.gcrypt.c.general;

extern (C):

/*
   Open a cipher handle for use with cipher algorithm ALGORITHM, using
   the cipher mode MODE (one of the GCRY_CIPHER_MODE_*) and return a
   handle in HANDLE.  Put NULL into HANDLE and return an error code if
   something goes wrong.  FLAGS may be used to modify the
   operation.  The defined flags are:

   GCRY_CIPHER_SECURE:  allocate all internal buffers in secure memory.
   GCRY_CIPHER_ENABLE_SYNC:  Enable the sync operation as used in OpenPGP.
   GCRY_CIPHER_CBC_CTS:  Enable CTS mode.
   GCRY_CIPHER_CBC_MAC:  Enable MAC mode.

   Values for these flags may be combined using OR.
 */

gcry_error_t gcry_cipher_open (gcry_cipher_hd_t* hd, gcry_cipher_algos algo,
    gcry_cipher_modes mode, uint flags);

/* Release all resources associated with the cipher handle H. H may be
   NULL in which case this is a no-operation. */

void gcry_cipher_close (gcry_cipher_hd_t h);

/* Set the key to be used for the encryption context h to k with
   length l.  The length should match the required length. */

gcry_error_t gcry_cipher_setkey (gcry_cipher_hd_t h, Const!(void)* k, size_t l);

/* Set the iv to be used for the encryption context h to k with
   length l.  The length should match the required length. */

gcry_error_t gcry_cipher_setiv (gcry_cipher_hd_t h, Const!(void)* k, size_t l);


/****************
 * Encrypt in_ and write it to out_.  If in_ is NULL, in-place encryption has
 * been requested.
 */

gcry_error_t gcry_cipher_encrypt (gcry_cipher_hd_t h, Const!(void)* out_,
    size_t outsize, Const!(void)* in_, size_t inlen);

/****************
 * Decrypt in_ and write it to out_.  If in_ is NULL, in-place encryption has
 * been requested.
 */

gcry_error_t gcry_cipher_decrypt (gcry_cipher_hd_t h, Const!(void)* out_,
    size_t outsize, Const!(void)* in_, size_t inlen);


// This functions returns the block-length of the algorithm algo counted in
// octets. On error 0 is returned.
size_t gcry_cipher_get_algo_blklen (int algo);

// This function returns length of the key for algorithm algo. If the algorithm
// supports multiple key lengths, the maximum supported key length is returned.
// On error 0 is returned. The key length is returned as number of octets.
size_t gcry_cipher_get_algo_keylen (int algo);

// The handler is a pointer of a struct we don't care about

struct gcry_cipher_handle;
alias gcry_cipher_handle* gcry_cipher_hd_t;

// Algorithms supported

enum gcry_cipher_algos
{
    GCRY_CIPHER_NONE        = 0,
    GCRY_CIPHER_IDEA        = 1,
    GCRY_CIPHER_3DES        = 2,
    GCRY_CIPHER_CAST5       = 3,
    GCRY_CIPHER_BLOWFISH    = 4,
    GCRY_CIPHER_SAFER_SK128 = 5,
    GCRY_CIPHER_DES_SK      = 6,
    GCRY_CIPHER_AES         = 7,
    GCRY_CIPHER_AES192      = 8,
    GCRY_CIPHER_AES256      = 9,
    GCRY_CIPHER_TWOFISH     = 10,

    /* Other cipher numbers are above 300 for OpenPGP reasons. */
    GCRY_CIPHER_ARCFOUR     = 301,  /* Fully compatible with RSA's RC4 (tm). */
    GCRY_CIPHER_DES         = 302,  /* Yes, this is single key 56 bit DES. */
    GCRY_CIPHER_TWOFISH128  = 303,
    GCRY_CIPHER_SERPENT128  = 304,
    GCRY_CIPHER_SERPENT192  = 305,
    GCRY_CIPHER_SERPENT256  = 306,
    GCRY_CIPHER_RFC2268_40  = 307,  /* Ron's Cipher 2 (40 bit). */
    GCRY_CIPHER_RFC2268_128 = 308,  /* Ron's Cipher 2 (128 bit). */
    GCRY_CIPHER_SEED        = 309,  /* 128 bit cipher described in RFC4269. */
    GCRY_CIPHER_CAMELLIA128 = 310,
    GCRY_CIPHER_CAMELLIA192 = 311,
    GCRY_CIPHER_CAMELLIA256 = 312,
    GCRY_CIPHER_SALSA20     = 313,
    GCRY_CIPHER_SALSA20R12  = 314,
    GCRY_CIPHER_GOST28147   = 315,
    GCRY_CIPHER_CHACHA20    = 316
}

// Cipher modes supported

enum gcry_cipher_modes
{
    GCRY_CIPHER_MODE_NONE     = 0,   /* Not yet specified. */
    GCRY_CIPHER_MODE_ECB      = 1,   /* Electronic codebook. */
    GCRY_CIPHER_MODE_CFB      = 2,   /* Cipher feedback. */
    GCRY_CIPHER_MODE_CBC      = 3,   /* Cipher block chaining. */
    GCRY_CIPHER_MODE_STREAM   = 4,   /* Used with stream ciphers. */
    GCRY_CIPHER_MODE_OFB      = 5,   /* Outer feedback. */
    GCRY_CIPHER_MODE_CTR      = 6,   /* Counter. */
    GCRY_CIPHER_MODE_AESWRAP  = 7,   /* AES-WRAP algorithm.  */
    GCRY_CIPHER_MODE_CCM      = 8,   /* Counter with CBC-MAC.  */
    GCRY_CIPHER_MODE_GCM      = 9,   /* Galois Counter Mode. */
    GCRY_CIPHER_MODE_POLY1305 = 10,  /* Poly1305 based AEAD mode. */
    GCRY_CIPHER_MODE_OCB      = 11   /* OCB3 mode.  */
}


