/*******************************************************************************

    Random Generating Functions

    Requires linking with libgcrypt:

        -L-lgcrypt

    Copyright: Copyright (c) 2016 sociomantic labs. All rights reserved

*******************************************************************************/

module ocean.util.cipher.gcrypt.c.random;

import ocean.util.cipher.gcrypt.c.general;

import ocean.transition;

extern (C):

/* The possible values for the random quality.  The rule of thumb is
   to use STRONG for session keys and VERY_STRONG for key material.
   WEAK is usually an alias for STRONG and should not be used anymore
   (except with gcry_mpi_randomize); use gcry_create_nonce instead. */
enum gcry_random_level
{
    GCRY_WEAK_RANDOM = 0,
    GCRY_STRONG_RANDOM = 1,
    GCRY_VERY_STRONG_RANDOM = 2
}


/* Fill BUFFER with LENGTH bytes of random, using random numbers of
   quality LEVEL. */
void gcry_randomize (void* buffer, size_t length,
                     gcry_random_level level);

/* Add the external random from BUFFER with LENGTH bytes into the
   pool. QUALITY should either be -1 for unknown or in the range of 0
   to 100 */
gcry_error_t gcry_random_add_bytes (Const!(void)* buffer, size_t length,
                                    int quality = -1);

/* If random numbers are used in an application, this macro should be
   called from time to time so that new stuff gets added to the
   internal pool of the RNG.  */

gcry_error_t gcry_fast_random_poll ( )
{
    return gcry_control(gcry_ctl_cmds.GCRYCTL_FAST_POLL, null);
}


/* Return NBYTES of allocated random using a random numbers of quality
   LEVEL. */
void* gcry_random_bytes (size_t nbytes, gcry_random_level level);

/* Return NBYTES of allocated random using a random numbers of quality
   LEVEL.  The random numbers are created returned in "secure"
   memory. */
void* gcry_random_bytes_secure (size_t nbytes, gcry_random_level level);


/* Create an unpredicable nonce of LENGTH bytes in BUFFER. */
void gcry_create_nonce (void* buffer, size_t length);
