/*******************************************************************************

    glibc stdlib functions.

*******************************************************************************/

module tango.stdc.posix.gnu.stdlib;

version (GLIBC):

extern (C):

int mkstemps(char*, int); // BSD and other systems too
int mkostemp(char*, int);
int mkostemps(char*, int, int);

