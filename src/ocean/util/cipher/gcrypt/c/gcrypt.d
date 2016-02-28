/*******************************************************************************

    Requires linking with libgcrypt:

        -L-lgcrypt

    Copyright: Copyright (c) 2015 sociomantic labs. All rights reserved

*******************************************************************************/

module ocean.util.cipher.gcrypt.c.gcrypt;

import ocean.transition;

// The minimum version supported by the bindings
public istring gcrypt_version = "1.5.0";


/*******************************************************************************

    Module constructor that insures that the used libgcrypt version is at least
    the same as the bindings was written for.

*******************************************************************************/

public static this ( )
{
    Const!(char)* ver = gcry_check_version(gcrypt_version.ptr);

    if ( !ver )
    {
        throw new Exception("Version of libgcrypt is less than "~gcrypt_version);
    }
}


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


// The function gcry_strerror returns a pointer to a statically allocated string
// containing a description of the error code contained in the error value err.
// This string can be used to output a diagnostic message to the user.
Const!(char)* gcry_strerror (gcry_error_t err);

// The function gcry_strsource returns a pointer to a statically allocated
// string containing a description of the error source contained in the error
// value err. This string can be used to output a diagnostic message to the user.
Const!(char)* gcry_strsource (gcry_error_t err);

// This functions returns the block-length of the algorithm algo counted in
// octets. On error 0 is returned.
size_t gcry_cipher_get_algo_blklen (int algo);

// This function returns length of the key for algorithm algo. If the algorithm
// supports multiple key lengths, the maximum supported key length is returned.
// On error 0 is returned. The key length is returned as number of octets.
size_t gcry_cipher_get_algo_keylen (int algo);

/* Check that the library fulfills the version requirement.  */
Const!(char)* gcry_check_version ( Const!(char)* req_version);

/* Perform various operations defined by CMD. */
gcry_error_t gcry_control ( gcry_ctl_cmds CMD, ...);

// The error type is an unsigned integer
alias uint gcry_error_t;

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


/* Codes used with the gcry_control function. */
enum gcry_ctl_cmds
{
    /* Note: 1 .. 2 are not anymore used. */
    GCRYCTL_CFB_SYNC = 3,
    GCRYCTL_RESET    = 4,   /* e.g. for MDs */
    GCRYCTL_FINALIZE = 5,
    GCRYCTL_GET_KEYLEN = 6,
    GCRYCTL_GET_BLKLEN = 7,
    GCRYCTL_TEST_ALGO = 8,
    GCRYCTL_IS_SECURE = 9,
    GCRYCTL_GET_ASNOID = 10,
    GCRYCTL_ENABLE_ALGO = 11,
    GCRYCTL_DISABLE_ALGO = 12,
    GCRYCTL_DUMP_RANDOM_STATS = 13,
    GCRYCTL_DUMP_SECMEM_STATS = 14,
    GCRYCTL_GET_ALGO_NPKEY    = 15,
    GCRYCTL_GET_ALGO_NSKEY    = 16,
    GCRYCTL_GET_ALGO_NSIGN    = 17,
    GCRYCTL_GET_ALGO_NENCR    = 18,
    GCRYCTL_SET_VERBOSITY     = 19,
    GCRYCTL_SET_DEBUG_FLAGS   = 20,
    GCRYCTL_CLEAR_DEBUG_FLAGS = 21,
    GCRYCTL_USE_SECURE_RNDPOOL= 22,
    GCRYCTL_DUMP_MEMORY_STATS = 23,
    GCRYCTL_INIT_SECMEM       = 24,
    GCRYCTL_TERM_SECMEM       = 25,
    GCRYCTL_DISABLE_SECMEM_WARN = 27,
    GCRYCTL_SUSPEND_SECMEM_WARN = 28,
    GCRYCTL_RESUME_SECMEM_WARN  = 29,
    GCRYCTL_DROP_PRIVS          = 30,
    GCRYCTL_ENABLE_M_GUARD      = 31,
    GCRYCTL_START_DUMP          = 32,
    GCRYCTL_STOP_DUMP           = 33,
    GCRYCTL_GET_ALGO_USAGE      = 34,
    GCRYCTL_IS_ALGO_ENABLED     = 35,
    GCRYCTL_DISABLE_INTERNAL_LOCKING = 36,
    GCRYCTL_DISABLE_SECMEM      = 37,
    GCRYCTL_INITIALIZATION_FINISHED = 38,
    GCRYCTL_INITIALIZATION_FINISHED_P = 39,
    GCRYCTL_ANY_INITIALIZATION_P = 40,
    GCRYCTL_SET_CBC_CTS = 41,
    GCRYCTL_SET_CBC_MAC = 42,
    /* Note: 43 is not anymore used. */
    GCRYCTL_ENABLE_QUICK_RANDOM = 44,
    GCRYCTL_SET_RANDOM_SEED_FILE = 45,
    GCRYCTL_UPDATE_RANDOM_SEED_FILE = 46,
    GCRYCTL_SET_THREAD_CBS = 47,
    GCRYCTL_FAST_POLL = 48,
    GCRYCTL_SET_RANDOM_DAEMON_SOCKET = 49,
    GCRYCTL_USE_RANDOM_DAEMON = 50,
    GCRYCTL_FAKED_RANDOM_P = 51,
    GCRYCTL_SET_RNDEGD_SOCKET = 52,
    GCRYCTL_PRINT_CONFIG = 53,
    GCRYCTL_OPERATIONAL_P = 54,
    GCRYCTL_FIPS_MODE_P = 55,
    GCRYCTL_FORCE_FIPS_MODE = 56,
    GCRYCTL_SELFTEST = 57,
    /* Note: 58 .. 62 are used internally.  */
    GCRYCTL_DISABLE_HWF = 63,
    GCRYCTL_SET_ENFORCED_FIPS_FLAG = 64,
    GCRYCTL_SET_PREFERRED_RNG_TYPE = 65,
    GCRYCTL_GET_CURRENT_RNG_TYPE = 66,
    GCRYCTL_DISABLE_LOCKED_SECMEM = 67,
    GCRYCTL_DISABLE_PRIV_DROP = 68,
    GCRYCTL_SET_CCM_LENGTHS = 69,
    GCRYCTL_CLOSE_RANDOM_DEVICE = 70,
    GCRYCTL_INACTIVATE_FIPS_FLAG = 71,
    GCRYCTL_REACTIVATE_FIPS_FLAG = 72,
    GCRYCTL_SET_SBOX = 73,
    GCRYCTL_DRBG_REINIT = 74,
    GCRYCTL_SET_TAGLEN = 75
}
