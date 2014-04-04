/*******************************************************************************

    Deep copy template functions for dynamic & static arrays, structs and class
    instances.

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    version:        May 2011: Initial release

    authors:        Gavin Norman, Joseph Wakeling

    Creates a deep copy from one instance of a type to another. Also provides
    a method to do a deep reset of a struct.

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

private import ocean.core.Traits : isTypedef, StripTypedef;

private import tango.core.Traits;



/*******************************************************************************

    Template to determine the correct DeepCopy function to call dependent
    on the type given.

    Template params:
        T = type to deep copy

    Evaluates to:
        aliases function appropriate to T

*******************************************************************************/

public template DeepCopy ( T )
{
    static if ( isTypedef!(T) )
    {
        alias DeepCopy!(StripTypedef!(T)) DeepCopy;
    }
    else static if ( is(T == union) )
    {
        alias UnionDeepCopy DeepCopy;
    }
    else static if ( is(T == class) )
    {
        alias ClassDeepCopy DeepCopy;
    }
    else static if ( is(T == struct))
    {
        alias StructDeepCopy DeepCopy;
    }
    else static if ( isAssocArrayType!(T) )
    {
        alias AssocArrayDeepCopy DeepCopy;
    }
    else static if ( isDynamicArrayType!(T) )
    {
        alias DynamicArrayDeepCopy DeepCopy;
    }
    else static if ( isStaticArrayType!(T) )
    {
        alias StaticArrayDeepCopy DeepCopy;
    }
    else static if ( isAtomicType!(T) || is(T == enum) )
    {
        alias ValueDeepCopy DeepCopy;
    }
    else
    {
        alias UnknownDeepCopy DeepCopy;
    }
}


/*******************************************************************************

    Handler for types that are unknown to DeepCopy.  This simply static
    asserts to alert the user the copy cannot be made.

    Params:
        src = source variable
        dst = destination variable

    Template params:
        T = type of variables to copy

*******************************************************************************/

public void UnknownDeepCopy (T) (T src, ref T dst)
{
    static assert(false, "Error: DeepCopy template could not expand for type " ~ T.stringof);
}


/*******************************************************************************

    "Deep" copy function for unions.  In theory this should be able to
    handle unions of basic value types (i.e. not structs, classes, arrays
    and so on).  However, in practice we simply static assert(false) in
    order to prevent deep copying of these very type-unsafe variables.

    Params:
        src = source value
        dst = destination value

    Template params:
        T = type of values to copy

*******************************************************************************/

public void UnionDeepCopy (T) (T src, ref T dst)
{
    static assert(is(T == union), "UnionDeepCopy: " ~ T.stringof ~ " is not a union.");
    static assert(false, "UnionDeepCopy: impossible to safely deep-copy unions.");
}


/*******************************************************************************

    "Deep" copy function for atomic types and enums.  This is provided
    simply to give support for generic code that may wish to deep-copy
    variables of arbitrary type.

    Params:
        src = source array
        dst = destination array

    Template params:
        T = type of values to copy

*******************************************************************************/

public void ValueDeepCopy (T) (T src, ref T dst)
{
    static assert(isAtomicType!(StripTypedef!(T)) || is(StripTypedef!(T) == enum),
                  "ValueDeepCopy: " ~ T.stringof ~ " is not an atomic type or enum.");

    dst = src;
}


/*******************************************************************************

    Deep copy function for associative arrays.

    Params:
        src = source associative array
        dst = destination associative array

    Template params:
        Array = type of associative array to deep copy

*******************************************************************************/

public void AssocArrayDeepCopy (Array) (Array src, ref Array dst)
{
    static assert(isAssocArrayType!(StripTypedef!(Array)), "AssocArrayDeepCopy: "
                  ~ Array.stringof ~ " is not an associative array type.");
    static assert(false, "AssocArrayDeepCopy: deep copy of associative arrays "
                         "not yet implemented");
}


/*******************************************************************************

    Deep copy function for dynamic arrays.

    Params:
        src = source array
        dst = destination array

    Template params:
        Array = type of array to deep copy

*******************************************************************************/

public void DynamicArrayDeepCopy (Array) (Array src, ref Array dst)
{
    static assert(isDynamicArrayType!(StripTypedef!(Array)), "DynamicArrayDeepCopy: "
                  ~ Array.stringof ~ " is not a dynamic array type.");

    dst.length = src.length;

    ArrayDeepCopy(src, dst);
}


/*******************************************************************************

    Deep copy function for static arrays.

    Params:
        src = source array
        dst = destination array

    Template params:
        Array = type of array to deep copy

*******************************************************************************/

public void StaticArrayDeepCopy (Array) (Array src, Array dst)
in
{
    assert(src.length == dst.length, "StaticArrayDeepCopy: static array length mismatch");
}
body
{
    static assert(isStaticArrayType!(StripTypedef!(Array)), "StaticArrayDeepCopy: "
                  ~ Array.stringof ~ " is not a static array type.");

    ArrayDeepCopy(src, dst);
}


/*******************************************************************************

    Deep copy function for arrays.

    Params:
        src = source array
        dst = destination array

    Template params:
        Array = type of array to deep copy

*******************************************************************************/

private void ArrayDeepCopy (Array) (Array src, Array dst)
in
{
    assert(src.length == dst.length, "ArrayDeepCopy: length mismatch");
}
body
{
    static assert(isArrayType!(StripTypedef!(Array)), "ArrayDeepCopy: "
                  ~ Array.stringof ~ " is not an array type.");

    static if (is(StripTypedef!(Array) T : T[]))
    {
        static if (isAtomicType!(T) || is(T == enum) || is(T == void))
        {
            dst[] = src[];
        }
        else
        {
            foreach (i, e; src)
            {
                DeepCopy!(T)(e, dst[i]);
            }
        }
    }
    else
    {
        static assert(false, "ArrayDeepCopy: unable to copy arrays of type "
                             ~ Array.stringof);
    }
}


/*******************************************************************************

    Deep copy function for structs

    Params:
        src = source struct
        dst = destination struct

    Template params:
        T = type of struct to deep copy

*******************************************************************************/

public void StructDeepCopy (T) (T src, ref T dst)
{
    static assert(is(StripTypedef!(T) == struct), "StructDeepCopy: " ~ T.stringof ~
                                                  " is not a struct.");

    AggregateDeepCopy(src, dst);
}


/*******************************************************************************

    Deep copy function for dynamic class instances.

    Params:
        src = source instance
        dst = destination instance

    Template params:
        T = type of class to deep copy

*******************************************************************************/

public void ClassDeepCopy (T) (T src, T dst)
{
    static assert(is(StripTypedef!(T) == class), "ClassDeepCopy: " ~ T.stringof ~
                                                 " is not a struct or class.");

    AggregateDeepCopy(src, dst);

    // Recurse into super any classes
    static if (is(StripTypedef!(T) S == super))
    {
        foreach (V; S)
        {
            static if (!is(V == Object))
            {
                DeepCopy!(V)(cast(V) src, cast(V) dst);
            }
        }
    }
}


/*******************************************************************************

    Deep copy function used internally by StructDeepCopy and ClassDeepCopy.
    This will copy the immediate members of a struct or class, but not for
    example subclass members.

    Params:
        src = source struct/class
        dst = destination struct/class

    Template params:
        T = type of struct/class to deep copy

*******************************************************************************/

public void AggregateDeepCopy (T) (T src, ref T dst)
{
    static assert((is(StripTypedef!(T) == struct) || is(StripTypedef!(T) == class)),
                  "StructClassDeepCopy: " ~ T.stringof ~ " is not a struct or class.");

    foreach (i, member; src.tupleof)
    {
        DeepCopy!(typeof(member))(member, dst.tupleof[i]);
    }
}


/*******************************************************************************

    Template to determine the correct DeepCopy function to call dependant on the
    type given.

    Template params:
        T = type to deep reset

    Evaluates to:
        aliases function appropriate to T

*******************************************************************************/

public template DeepReset ( T )
{
    static if ( is(T == class) )
    {
        alias ClassDeepReset DeepReset;
    }
    else static if ( is(T == struct) )
    {
        alias StructDeepReset DeepReset;
    }
    else static if ( isAssocArrayType!(T) )
    {
        // TODO: reset associative arrays
        pragma(msg, "Warning: deep reset of associative arrays not yet implemented");
        alias nothing DeepReset;
    }
    else static if ( is(T S : S[]) && is(T S == S[]) )
    {
        alias DynamicArrayDeepReset DeepReset;
    }
    else static if ( is(T S : S[]) && !is(T S == S[]) )
    {
        alias StaticArrayDeepReset DeepReset;
    }
    else
    {
        pragma(msg, "Warning: DeepReset template could not expand for type " ~ T.stringof);
        alias nothing DeepReset;
    }
}



/*******************************************************************************

    Deep reset function for dynamic arrays. To reset a dynamic array set the
    length to 0.

    Params:
        dst = destination array

    Template params:
        T = type of array to deep copy

*******************************************************************************/

public void DynamicArrayDeepReset ( T ) ( ref T[] dst )
{
    ArrayDeepReset(dst);
    dst.length = 0;
}



/*******************************************************************************

    Deep reset function for static arrays. To reset a static array go through
    the whole array and set the items to the init values for the type of the
    array.

    Params:
        dst = destination array

    Template params:
        T = type of array to deep copy

*******************************************************************************/

public void StaticArrayDeepReset ( T ) ( T[] dst )
{
    ArrayDeepReset(dst);
}



/*******************************************************************************

    Deep reset function for arrays.

    Params:
        dst = destination array

    Template params:
        T = type of array to deep copy

*******************************************************************************/

private void ArrayDeepReset ( T ) ( ref T[] dst )
{
    static if ( isAssocArrayType!(T) )
    {
        // TODO: copy associative arrays
        pragma(msg, "Warning: deep reset of associative arrays not yet implemented");
    }
    else static if ( is(T S : S[]) )
    {
        foreach ( i, e; dst )
        {
            static if ( is(T S == S[]) ) // dynamic array
            {
                DynamicArrayDeepReset(dst[i]);
            }
            else // static array
            {
                StaticArrayDeepReset(dst[i]);
            }
        }
    }
    else static if ( is(T == struct) )
    {
        foreach ( i, e; dst )
        {
            StructDeepReset(dst[i]);
        }
    }
    else static if ( is(T == class) )
    {
        foreach ( i, e; dst )
        {
            ClassDeepReset(dst[i]);
        }
    }
    else
    {
        // TODO this probably does not need to be done for a dynamic array
        foreach ( ref item; dst )
        {
            item = item.init;
        }
    }
}



/*******************************************************************************

    Deep reset function for structs.

    Params:
        dst = destination struct

    Template params:
        T = type of struct to deep copy

*******************************************************************************/

// TODO: struct & class both share basically the same body, could be shared?

public void StructDeepReset ( T ) ( ref T dst )
{
    static if ( !is(T == struct) )
    {
        static assert(false, "StructDeepReset: " ~ T.stringof ~ " is not a struct");
    }

    foreach ( i, member; dst.tupleof )
    {
        static if ( isAssocArrayType!(typeof(member)) )
        {
            // TODO: copy associative arrays
            pragma(msg, "Warning: deep reset of associative arrays not yet implemented");
        }
        else static if ( is(typeof(member) S : S[]) )
        {
            static if ( is(typeof(member) U == S[]) ) // dynamic array
            {
                DynamicArrayDeepReset(dst.tupleof[i]);
            }
            else // static array
            {
                StaticArrayDeepReset(dst.tupleof[i]);
            }
        }
        else static if ( is(typeof(member) == class) )
        {
            ClassDeepReset(dst.tupleof[i]);
        }
        else static if ( is(typeof(member) == struct) )
        {
            StructDeepReset(dst.tupleof[i]);
        }
        else
        {
            dst.tupleof[i] = dst.tupleof[i].init;
        }
    }
}



/*******************************************************************************

    Deep reset function for dynamic class instances.

    Params:
        dst = destination instance

    Template params:
        T = type of class to deep copy

*******************************************************************************/

public void ClassDeepReset ( T ) ( ref T dst )
{
    static if ( !is(T == class) )
    {
        static assert(false, "ClassDeepReset: " ~ T.stringof ~ " is not a class");
    }

    foreach ( i, member; dst.tupleof )
    {
        static if ( isAssocArrayType!(typeof(member)) )
        {
            // TODO: copy associative arrays
            pragma(msg, "Warning: deep reset of associative arrays not yet implemented");
        }
        else static if ( is(typeof(member) S : S[]) )
        {
            static if ( is(typeof(member) S == S[]) ) // dynamic array
            {
                DynamicArrayDeepReset(dst.tupleof[i]);
            }
            else // static array
            {
                StaticArrayDeepReset(dst.tupleof[i]);
            }
        }
        else static if ( is(typeof(member) == class) )
        {
            ClassDeepReset(dst.tupleof[i]);
        }
        else static if ( is(typeof(member) == struct) )
        {
            StructDeepReset(dst.tupleof[i]);
        }
        else
        {
            dst.tupleof[i] = dst.tupleof[i].init;
        }
    }

    // Recurse into super any classes
    static if ( is(T S == super ) )
    {
        foreach ( V; S )
        {
            static if ( !is(V == Object) )
            {
                ClassDeepReset(cast(V)dst);
            }
        }
    }
}



/*******************************************************************************

    unit test for the DeepReset method. Makes a test structure and fills it
    with data before calling reset and making sure it is cleared.

    We first build a basic struct that has both a single sub struct and a
    dynamic array of sub structs. Both of these are then filled along with
    the fursther sub sub struct.

    The DeepReset method is then called. The struct is then confirmed to
    have had it's members reset to the correct values

    TODO Adjust the unit test so it also deals with struct being
    re-initialised to make sure they are not full of old data (~=)

*******************************************************************************/


unittest
{
    struct TestStruct
    {
        int a;
        char[] b;
        int[7] c;

        public struct SubStruct
        {
            int d;
            char[] e;
            char[][] f;
            int[7] g;

            public struct SubSubStruct
            {
                int h;
                char[] i;
                char[][] j;
                int[7] k;

                void InitStructure()
                {
                    this.h = -52;
                    this.i.copy("even even more test text");
                    this.j.length = 3;
                    this.j[0].copy("abc");
                    this.j[1].copy("def");
                    this.j[2].copy("ghi");
                    foreach ( ref item; this.k )
                    {
                        item = 120000;
                    }
                }
            }

            void InitStructure()
            {
                this.d = 32;
                this.e.copy("even more test text");

                this.f.length = 1;
                this.f[0].copy("abc");
                foreach ( ref item; this.g )
                {
                    item = 32400;
                }
            }

            SubSubStruct[] sub_sub_struct;
        }

        SubStruct sub_struct;

        SubStruct[] sub_struct_array;
    }

    TestStruct test_struct;
    test_struct.a = 7;
    test_struct.b.copy("some test");
    foreach ( i, ref item; test_struct.c )
    {
        item = 64800;
    }

    TestStruct.SubStruct sub_struct;
    sub_struct.InitStructure;
    test_struct.sub_struct = sub_struct;
    test_struct.sub_struct_array ~= sub_struct;
    test_struct.sub_struct_array ~= sub_struct;


    TestStruct.SubStruct.SubSubStruct sub_sub_struct;
    sub_sub_struct.InitStructure;
    test_struct.sub_struct_array[0].sub_sub_struct ~= sub_sub_struct;
    test_struct.sub_struct_array[1].sub_sub_struct ~= sub_sub_struct;
    test_struct.sub_struct_array[1].sub_sub_struct ~= sub_sub_struct;
    test_struct.sub_struct.sub_sub_struct ~= sub_sub_struct;
    test_struct.sub_struct.sub_sub_struct ~= sub_sub_struct;

    DeepReset!(TestStruct)(test_struct);

    assert (test_struct.a == 0, "failed DeepReset check");
    assert (test_struct.b == "", "failed DeepReset check");
    foreach ( item; test_struct.c )
    {
        assert (item == 0, "failed DeepReset check");
    }

    assert(test_struct.sub_struct_array.length == 0, "failed DeepReset check");

    assert (test_struct.sub_struct.d == 0, "failed DeepReset check");
    assert (test_struct.sub_struct.e == "", "failed DeepReset check");
    assert (test_struct.sub_struct.f.length == 0, "failed DeepReset check");
    foreach ( item; test_struct.sub_struct.g )
    {
        assert (item == 0, "failed DeepReset check");
    }

    assert(test_struct.sub_struct.sub_sub_struct.length == 0, "failed DeepReset check");

}
