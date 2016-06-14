/**
 * D header file for POSIX.
 *
 * Copyright:
 *     Public Domain
 *     Some parts copyright (c) 2009-2016 Sociomantic Labs GmbH.
 *     All rights reserved.
 *
 * License: Tango 3-Clause BSD License. See LICENSE_BSD.txt for details.
 *
 * Authors: Leandro Lucarella
 *
 * Standards: The Open Group Base Specifications Issue 6, IEEE Std 1003.1, 2004 Edition
 *
 */
module ocean.stdc.posix.libgen;

extern (C):

char* basename(char*);
char* dirname(char*);
