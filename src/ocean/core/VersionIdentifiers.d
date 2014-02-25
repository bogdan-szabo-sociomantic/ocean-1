/*******************************************************************************

    copyright:      Copyright (c) 2012 sociomantic labs. All rights reserved

    version:        22/08/2012: Initial release

    authors:        Gavin Norman

    Functions / templates dealing with version() identifiers.

*******************************************************************************/

module ocean.core.VersionIdentifiers;



/*******************************************************************************

    Calls the passed delegate with the names of any pre-defined version
    identifiers with which the program is compiled.

    Params:
        dg = delegate to receive the names of active version identifiers

*******************************************************************************/

public void versionIdentifiers ( void delegate ( char[] version_name ) dg )
{
    mixin(Version!("DigitalMars", "dg"));
    mixin(Version!("GNU", "dg"));
    mixin(Version!("LDC", "dg"));
    mixin(Version!("SDC", "dg"));
    mixin(Version!("D_NET", "dg"));
    mixin(Version!("Windows", "dg"));
    mixin(Version!("Win32", "dg"));
    mixin(Version!("Win64", "dg"));
    mixin(Version!("linux", "dg"));
    mixin(Version!("OSX", "dg"));
    mixin(Version!("FreeBSD", "dg"));
    mixin(Version!("OpenBSD", "dg"));
    mixin(Version!("BSD", "dg"));
    mixin(Version!("Solaris", "dg"));
    mixin(Version!("Posix", "dg"));
    mixin(Version!("AIX", "dg"));
    mixin(Version!("SkyOS", "dg"));
    mixin(Version!("SysV3", "dg"));
    mixin(Version!("SysV4", "dg"));
    mixin(Version!("Hurd", "dg"));
    mixin(Version!("Cygwin", "dg"));
    mixin(Version!("MinGW", "dg"));
    mixin(Version!("X86", "dg"));
    mixin(Version!("X86_64", "dg"));
    mixin(Version!("ARM", "dg"));
    mixin(Version!("PPC", "dg"));
    mixin(Version!("PPC64", "dg"));
    mixin(Version!("IA64", "dg"));
    mixin(Version!("MIPS", "dg"));
    mixin(Version!("MIPS64", "dg"));
    mixin(Version!("SPARC", "dg"));
    mixin(Version!("SPARC64", "dg"));
    mixin(Version!("S390", "dg"));
    mixin(Version!("S390X", "dg"));
    mixin(Version!("HPPA", "dg"));
    mixin(Version!("HPPA64", "dg"));
    mixin(Version!("SH", "dg"));
    mixin(Version!("SH64", "dg"));
    mixin(Version!("Alpha", "dg"));
    mixin(Version!("LittleEndian", "dg"));
    mixin(Version!("BigEndian", "dg"));
    mixin(Version!("D_Coverage", "dg"));
    mixin(Version!("D_Ddoc", "dg"));
    mixin(Version!("D_InlineAsm_X86", "dg"));
    mixin(Version!("D_InlineAsm_X86_64", "dg"));
    mixin(Version!("D_LP64", "dg"));
    mixin(Version!("D_PIC", "dg"));
}


/*******************************************************************************

    Template which generates code to call a function with the specified name
    with the name of the version identifier specified as the parameter, in the
    case where the program is compiled with that version identifier.

    Template params:
        version_name = name of version identifier to check
        func_name = name of function to call if version identifier is active

*******************************************************************************/

private template Version ( char[] version_name, char[] func_name )
{
    const char[] Version = "version(" ~ version_name ~ ")"
        ~ func_name ~ `("` ~ version_name ~ `");`;
}

