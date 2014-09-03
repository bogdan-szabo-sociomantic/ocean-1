/******************************************************************************

    copyright:      Copyright (c) 2014 sociomantic labs. All rights reserved

    Provides basic utilities to work with version information in structures.

*******************************************************************************/

module ocean.util.serialize.model.Version;

/*******************************************************************************
    
    Imports

*******************************************************************************/

version(UnitTest) import ocean.core.Test;

/*******************************************************************************
    
    Tag type that denotes missing version type for either next or previous
    version of a struct.

*******************************************************************************/

public struct MissingVersion
{
    const exists = false;
}

/*******************************************************************************
    
    Namespace struct is desired because most of symbols have very common and
    generic names.

*******************************************************************************/

struct Version
{
    /***************************************************************************
        
        The type of the version number tag that is prepended to serialised data.

    ***************************************************************************/

    public alias ubyte Type;

    /***************************************************************************

        Evaluates to version information of S if S is a versioned struct:

            - exists: true if S is a versioned struct or false if S is a struct
              without version or not a struct. If false the other constants are
              not defined.
            - number: The value of the struct version (S.Info), expected to
              be of type Type.
            - next/prev: Info for S.StructNext or S.StructPrev, respectively
            - type : type of struct this info belongs to

        next/prev are recursive instances of this template so they can be
        checked for existence by Info!(S).next.exists
        If that's true the next version number is Info!(S).next.number.
        The next version itself can contain a next version,
        use Info!(S).next.next.exists to check it out.

    ***************************************************************************/

    template Info ( S )
    {
        static assert (is(S == struct));

        static if (is(typeof(S.StructVersion) V))
        {
            static assert (
                S.StructVersion <= Version.Type.max,
                S.stringof ~ ".StructVersion == " ~ 
                S.StructVersion.stringof ~
                ", but it must be lower than Version.Type.max"
            );

            const exists = true;
            const number = S.StructVersion;

            alias S type;

            static if (is(S.StructNext))
            {
                alias Info!(S.StructNext) next;
            }
            else
            {
                alias MissingVersion next; // dummy 
            }

            static if (is(S.StructPrevious))
            {
                alias Info!(S.StructPrevious) prev;
            }
            else
            {
                alias MissingVersion prev; // dummy
            }
        }
        else
        {
            alias MissingVersion Info;
        }
    }

    unittest
    {
        struct S { }
        static assert (is(Info!(S) == MissingVersion));
        static assert (!  Info!(S).exists);
    }

    unittest
    {
        struct S1 { const StructVersion = 1; }
        alias Info!(S1) Ver;
        static assert (Ver.exists);
        static assert (Ver.number == 1);
        static assert (is(Ver.next == MissingVersion));
        static assert (is(Ver.prev == MissingVersion));

        struct S2 { const StructVersion = Version.Type.max + 1; }
        static assert (!is(typeof(Info!(S2))));
    }

    unittest
    {
        struct S
        {
            const StructVersion = 1;
            alias S StructPrevious;
            alias S StructNext;
        }

        alias Info!(S) Ver;

        static assert (Ver.exists);
        static assert (is(Ver.next.type == S));
        static assert (is(Ver.prev.type == S));
    }

    /***************************************************************************
        
        Assumes that input is versioned struct chunk and extracts version number
        from it. Otherwise will return garbage

        Params:
            data = serialized struct data, untouched
            ver  = out parameter to store version number

        Returns:
            data slices after the version bytes

    ***************************************************************************/

    static void[] extract ( void[] data, ref Version.Type ver )
    in
    {
        assert (data.length > Version.Type.sizeof);
    }
    body
    {
        ver = *(cast(Version.Type*) data.ptr);
        return data[Version.Type.sizeof .. $];
    }

    unittest
    {
        Version.Type V = 42;
        void[] data = [ V, 1, 1 ];
        Version.Type ver;
        auto data_unver = extract(data, ver);
        test!("==")(ver, V); 
        test!("==")(data_unver.length, 2); 
    }

    /***************************************************************************
        
        Writes version data in the beginning of provided data buffer. Grows buffer
        if it is too small. Call this function before actually writing any useful
        payload to the buffer or it will be overwritten.

        Params:
            data = any byte buffer, will be modified to start with version info
            ver  = version number to inject

        Returns:
            slice of data after the version data. Use that slice to add actual
            payload

    ***************************************************************************/

    static void[] inject ( ref void[] data, Version.Type ver )
    {
        if (data.length < Version.Type.sizeof)
        {
            data.length = Version.Type.sizeof;
        }

        *(cast(Version.Type*) data.ptr) = ver;

        return data[Version.Type.sizeof .. $];
    }

    unittest
    {
        Version.Type V = 42;
        void[] data = [ cast(ubyte) 1, 2, 3 ];
        auto result = inject(data, V);
        test!("is")(data.ptr + V.sizeof, result.ptr);
        test!("==")(data, [ V, 2, 3 ]);
    }
}
