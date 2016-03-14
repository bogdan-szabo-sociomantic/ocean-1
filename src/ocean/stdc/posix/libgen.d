/**
 * D header file for POSIX.
 *
 * Copyright: Public Domain
 * License:   Public Domain
 * Authors:   Leandro Lucarella
 * Standards: The Open Group Base Specifications Issue 6, IEEE Std 1003.1, 2004 Edition
 */
module ocean.stdc.posix.libgen;

extern (C):

char* basename(char*);
char* dirname(char*);
