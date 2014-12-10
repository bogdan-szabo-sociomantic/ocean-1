/******************************************************************************

    copyright:      Copyright (c) 2014 sociomantic labs. All rights reserved

    version:        April 2014: Initial release

    author:         Mathias Baumann

    Extends the StructLoaderCore with the ability to load versioned structs

 ******************************************************************************/

deprecated module ocean.io.serialize.model.StructVersionBase;

import ocean.util.container.ConcatBuffer,
       ocean.io.serialize.StructDumper,
       ocean.core.StructConverter,
       ocean.core.Array : copy;


class StructVersionBase
{
    /***************************************************************************

        Size of the version field

    ***************************************************************************/

    public alias ubyte Version;

    /***************************************************************************

        Buffers used for the functions doing the conversion

    ***************************************************************************/

    public ConcatBuffer!(void[]) convert_buffer;

    /***************************************************************************

        Constructs a new instance of StructVersionBase, allocating required
        buffers

    ***************************************************************************/

    public this ( )
    {
        this.convert_buffer = new ConcatBuffer!(void[])();
    }


   /***************************************************************************

        Returns: True if S has a version field, else False

    ***************************************************************************/

    public static bool hasVersion ( S ) ( )
    {
        static if ( is ( typeof(S.StructVersion) ) )
        {
            static assert ( S.StructVersion <= ubyte.max,
                            S.StructVersion.stringof ~
                            " must be of lower than ubyte.max!!");

            return true;
        }
        else
        {
            return false;
        }
    }


    /***************************************************************************

        Checks a the given struct type for whether it has a version that can be
        converted.

        Template Parameter:
            S = struct to check

        Returns:
            true if it can converted, else false

    ***************************************************************************/

    static public bool canConvertStruct ( S ) ( )
    {
        static if ( StructVersionBase.hasVersion!(S)() )
        {
            return (StructVersionBase.getStructVersion!(S)() > 0) || is(S.StructNext);
        }

        return false;
    }


    /***************************************************************************

        Returns the version of the given struct

        Template Parameter:
            S = struct to check

        Returns:
            Version of S

    ***************************************************************************/

    static public ubyte getStructVersion ( S ) ( )
    {
        static assert (StructVersionBase.hasVersion!(S)());
        return S.StructVersion;
    }

    /***************************************************************************

        Updates a struct to the next version

        Template Parameters:
            Current = type of the struct you have
            Desired = type of the struct you want to get

        Params:
            current = current struct instance
            dst = buffer to use for the new struct

        Returns:
            pointer to the new struct

    ***************************************************************************/

    public Desired* convertStruct ( Current, Desired, StructLoader )
        ( StructLoader loader, ref Current current, ref void[] dst )
    {
        scope(exit) this.convert_buffer.clear();
        Desired* desired_struct = cast(Desired*)this.requestBuffer(Desired.sizeof);

        structCopy(current, *desired_struct, &this.requestBuffer);

        StructDumper.dump(dst, *desired_struct);

        return loader.loadExtend!(Desired)(dst);
    }


    /***************************************************************************

        Passed as delegate to converter functions so they can request buffers
        that are to be used during conversion

        Params:
            size = size in bytes of the requested buffer

        Returns:
            a slice of the requested size

    ***************************************************************************/

    private void[] requestBuffer ( size_t size )
    {
        return this.convert_buffer.add ( size );
    }

    /***************************************************************************

        Returns the version saved in the struct header in data

        Params:
            data = source data expected to contain a struct header

        Returns:
            the version number saved in the struct header or garbage if the data
            doesn't have a version header

    ***************************************************************************/

    public ubyte getVersion ( void[] data )
    {
        return *(cast(StructVersionBase.Version*)
            data[0..StructVersionBase.Version.sizeof].ptr);
    }

    /***************************************************************************

        Deletes buffer instance on explicit deletion

    ***************************************************************************/

    public void dispose ( )
    {
        delete this.convert_buffer;
    }
}

