/*******************************************************************************

    libgcrypt version definition and run-time test

    Requires linking with libgcrypt:

        -L-lgcrypt

    Copyright: Copyright (c) 2016 sociomantic labs. All rights reserved

*******************************************************************************/

module ocean.util.cipher.gcrypt.c.libversion;

import ocean.transition;

// The minimum version supported by the bindings
public istring gcrypt_version = "1.5.0";

/*******************************************************************************

    Module constructor that insures that the used libgcrypt version is at least
    the same as the bindings was written for.

*******************************************************************************/

static this ( )
{
    if ( !gcry_check_version(gcrypt_version.ptr) )
    {
        throw new Exception("Version of libgcrypt is less than "~gcrypt_version);
    }
}

/* Check that the library fulfills the version requirement.  */
extern (C) Const!(char)* gcry_check_version ( Const!(char)* req_version);
