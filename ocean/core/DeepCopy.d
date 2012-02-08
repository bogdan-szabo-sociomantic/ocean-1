/*******************************************************************************

    Deep copy template functions for dynamic & static arrays, structs and class
    instances.

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    version:        May 2011: Initial release

    authors:        Gavin Norman

    Creates a deep copy from one instance of a type to another.
    
    'Deep' meaning:
        * The contents of arrays are copied (rather than sliced).
        * Types are recursed, allowing multi-dimensional arrays to be copied.
        * All members of structs or classes are copied (recursively, if needed).
          This includes all members of all a class' superclasses.

*******************************************************************************/

module ocean.core.DeepCopy;



/*******************************************************************************

    Imports

*******************************************************************************/

private import ocean.core.Array : copy;

private import tango.core.Traits;



/*******************************************************************************

    Template to determine the correct DeepCopy function to call dependant on the
    type given.

    Template params:
        T = type to deep copy

    Evaluates to:
        aliases function appropriate to T

*******************************************************************************/

public template DeepCopy ( T )
{
    static if ( is(T == class) )
    {
        alias ClassDeepCopy DeepCopy;
    }
    else static if ( is(T == struct) )
    {
        alias StructDeepCopy DeepCopy;
    }
    else static if ( isAssocArrayType!(T) )
    {
        // TODO: copy associative arrays
        pragma(msg, "Warning: deep copy of associative arrays not yet implemented");
        alias nothing DeepCopy;
    }
    else static if ( is(T S : S[]) && is(T S == S[]) )
    {
        alias DynamicArrayDeepCopy DeepCopy;
    }
    else static if ( is(T S : S[]) && !is(T S == S[]) )
    {
        alias StaticArrayDeepCopy DeepCopy;
    }
    else
    {
        pragma(msg, "Warning: DeepCopy template could not expand for type " ~ T.stringof);
        alias nothing DeepCopy;
    }
}



/*******************************************************************************

    Deep copy function for dynamic arrays.

    Params:
        src = source array
        dst = destination array

    Template params:
        T = type of array to deep copy

*******************************************************************************/

public void DynamicArrayDeepCopy ( T ) ( T[] src, ref T[] dst )
{
    dst.length = src.length;

    ArrayDeepCopy(src, dst);
}


/*******************************************************************************

    Deep copy function for static arrays.
    
    Params:
        src = source array
        dst = destination array
    
    Template params:
        T = type of array to deep copy

*******************************************************************************/

public void StaticArrayDeepCopy ( T ) ( T[] src, T[] dst )
in
{
    assert(src.length == dst.length, "StaticArrayDeepCopy: static array length mismatch");
}
body
{
    ArrayDeepCopy(src, dst);
}



/*******************************************************************************

    Deep copy function for arrays.

    Params:
        src = source array
        dst = destination array

    Template params:
        T = type of array to deep copy

*******************************************************************************/

private void ArrayDeepCopy ( T ) ( T[] src, T[] dst )
{
    static if ( isAssocArrayType!(T) )
    {
        // TODO: copy associative arrays
        pragma(msg, "Warning: deep copy of associative arrays not yet implemented");
    }
    else static if ( is(T S : S[]) )
    {
        foreach ( i, e; src )
        {
            static if ( is(T S == S[]) ) // dynamic array
            {
                DynamicArrayDeepCopy(src[i], dst[i]);
            }
            else // static array
            {
                StaticArrayDeepCopy(src[i], dst[i]);
            }
        }
    }
    else static if ( is(T == struct) )
    {
        foreach ( i, e; src )
        {
            StructDeepCopy(src[i], dst[i]);
        }
    }
    else static if ( is(T == class) )
    {
        foreach ( i, e; src )
        {
            ClassDeepCopy(src[i], dst[i]);
        }
    }
    else
    {
        dst[] = src[];
    }
}



/*******************************************************************************

    Deep copy function for structs.
    
    Params:
        src = source struct
        dst = destination struct
    
    Template params:
        T = type of struct to deep copy

*******************************************************************************/

// TODO: struct & class both share basically the same body, could be shared?

public void StructDeepCopy ( T ) ( T src, ref T dst )
{
    static if ( !is(T == struct) )
    {
        static assert(false, "StructDeepCopy: " ~ T.stringof ~ " is not a struct");
    }
    
    foreach ( i, member; src.tupleof )
    {
        static if ( isAssocArrayType!(typeof(member)) )
        {
            // TODO: copy associative arrays
            pragma(msg, "Warning: deep copy of associative arrays not yet implemented");
        }
        else static if ( is(typeof(member) S : S[]) )
        {
            static if ( is(typeof(member) U == S[]) ) // dynamic array
            {
                DynamicArrayDeepCopy(src.tupleof[i], dst.tupleof[i]);
            }
            else // static array
            {
                StaticArrayDeepCopy(src.tupleof[i], dst.tupleof[i]);
            }
        }
        else static if ( is(typeof(member) == class) )
        {
            ClassDeepCopy(src.tupleof[i], dst.tupleof[i]);
        }
        else static if ( is(typeof(member) == struct) )
        {
            StructDeepCopy(src.tupleof[i], dst.tupleof[i]);
        }
        else
        {
            dst.tupleof[i] = src.tupleof[i];
        }
    }
}



/*******************************************************************************

    Deep copy function for dynamic class instances.
    
    Params:
        src = source instance
        dst = destination instance
    
    Template params:
        T = type of class to deep copy

*******************************************************************************/

public void ClassDeepCopy ( T ) ( T src, T dst )
{
    static if ( !is(T == class) )
    {
        static assert(false, "ClassDeepCopy: " ~ T.stringof ~ " is not a class");
    }

    foreach ( i, member; src.tupleof )
    {
        static if ( isAssocArrayType!(typeof(member)) )
        {
            // TODO: copy associative arrays
            pragma(msg, "Warning: deep copy of associative arrays not yet implemented");
        }
        else static if ( is(typeof(member) S : S[]) )
        {
            static if ( is(typeof(member) S == S[]) ) // dynamic array
            {
                DynamicArrayDeepCopy(src.tupleof[i], dst.tupleof[i]);
            }
            else // static array
            {
                StaticArrayDeepCopy(src.tupleof[i], dst.tupleof[i]);
            }
        }
        else static if ( is(typeof(member) == class) )
        {
            ClassDeepCopy(src.tupleof[i], dst.tupleof[i]);
        }
        else static if ( is(typeof(member) == struct) )
        {
            StructDeepCopy(src.tupleof[i], dst.tupleof[i]);
        }
        else
        {
            dst.tupleof[i] = src.tupleof[i];
        }
    }

    // Recurse into super any classes
    static if ( is(T S == super ) )
    {
        foreach ( V; S )
        {
            static if ( !is(V == Object) )
            {
                ClassDeepCopy(cast(V)src, cast(V)dst);
            }
        }
    }
}

