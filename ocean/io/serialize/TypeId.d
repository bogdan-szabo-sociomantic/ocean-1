/******************************************************************************

    Templates to generate a a hash or a string that describes the binary layout
    of a value type, fully recursing into aggregates.

    copyright:      Copyright (c) 2012 sociomantic labs. All rights reserved

    version:        October 2012: Initial release

    authors:        David Eckardt

    The data layout identifier hash is the 64-bit Fnv1a hash value of a string
    that is generated from a struct or union by concatenating the offsets
    and types of each field in order of appearance, recursing into structs,
    unions and function/delegate parameter lists and using the base type of
    enums and typedefs.

    Example:

    ---
        struct S
        {
            typedef int Spam;

            struct T
            {
                enum Eggs : ushort
                {
                    Ham = 7
                }

                Eggs eggs;                              // at offset 0

                char[] str;                             // at offset 8
            }

            Spam x;                                     // at offset 0

            T[][5] y;                                   // at offset 8

            Spam delegate ( T ) dg;                     // at offset 88

            T*[float function(Spam, T.Eggs)] a;         // at offset 104
        }


        const id = TypeId!(S);

        // id is now "struct{
        //               "0LUint"
        //               "8LU"
        //               "struct{"
        //                   "0LUushort"
        //                   "8LUchar[]"
        //               "}[][5LU]"
        //               "88LUintdelegate("
        //                   "struct{"
        //                       "0LUushort"
        //                       "8LUchar[]"
        //                   "}"
        //               ")"
        //               "104LUstruct{"
        //                   "0LUushort"
        //                   "8LUchar[]"
        //               "}*[floatfunction(intushort)]
        //           "}".

        const hash = TypeHash!(S);

        // hash is now 0x3ff282c0d315761b, the 64-bit Fnv1a hash of id .
    ---

    The type identifier of a non-aggregate type is the .stringof of that type
    (or its base if it is a typedef or enum).

 ******************************************************************************/

module ocean.io.serialize.TypeId;

/******************************************************************************

    Imports

 ******************************************************************************/

private import ocean.io.digest.Fnv1: StaticFnv1a64, Fnv164Const;

/******************************************************************************

    Evaluates to the type identifier of T, fully recursing into structs, unions
    and function/delegate parameter lists. T may be or contain any type except
    a class or interface.

 ******************************************************************************/

template TypeId ( T )
{
    static if (is (T == struct))
    {
        const TypeId = "struct{" ~ AggregateId!(CheckedBaseType!(T)) ~ "}";
    }
    else static if (is (T == union))
    {
        const TypeId = "union{" ~ AggregateId!(CheckedBaseType!(T)) ~ "}";
    }
    else static if (is (T Base : Base[]))
    {
        static if (is (T == Base[]))
        {
            const TypeId = TypeId!(Base) ~ "[]";
        }
        else
        {
            const TypeId = TypeId!(Base) ~ "[" ~ T.length.stringof ~ "]";
        }
    }
    else static if (is (T Base == Base*))
    {
        static if (is (Base Args == function) && is (Base R == return))
        {
            const TypeId = TypeId!(R) ~ "function(" ~ TupleId!(Args) ~ ")";
        }
        else
        {
            const TypeId = TypeId!(Base) ~ "*";
        }
    }
    else static if (is (T    Func == delegate) &&
                    is (Func Args == function) && is (Func R == return))
    {
        const TypeId = TypeId!(R) ~ "delegate(" ~ TupleId!(Args) ~ ")";
    }
    else static if (is (typeof (T.init.values[0]) V) &&
                    is (typeof (T.init.keys[0])   K) &&
                    is (V[K] == T))
    {
        const TypeId = TypeId!(V) ~ "[" ~ TypeId!(K) ~ "]";
    }
    else
    {
        const TypeId = CheckedBaseType!(T).stringof;
    }
}

/******************************************************************************

    Evaluates to the type hash of T, which is the 64-bit Fnv1a hash of the
    string that would be generated by TypeId!(T).

 ******************************************************************************/

template TypeHash ( T )
{
    const TypeHash = TypeHash!(Fnv164Const.INIT, T);
}

/******************************************************************************

    Evaluates to the type hash of T, which is the 64-bit Fnv1a hash of the
    string that would be generated by TypeId!(T), using hash as initial hash
    value so that TypeHash!(TypeHash!(A), B) evaluates to the 64-bit Fvn1a hash
    value of TypeId!(A) ~ TypeId!(B).

 ******************************************************************************/

template TypeHash ( ulong hash, T )
{
    static if (is (T == struct))
    {
        const TypeHash = StaticFnv1a64!(AggregateHash!(StaticFnv1a64!(hash, "struct{"), CheckedBaseType!(T)), "}");
    }
    else static if (is (T == union))
    {
        const TypeHash = StaticFnv1a64!(AggregateHash!(StaticFnv1a64!(hash, "union{"), CheckedBaseType!(T)), "}");
    }
    else static if (is (T Base : Base[]))
    {
        static if (is (T == Base[]))
        {
            const TypeHash = StaticFnv1a64!(TypeHash!(hash, Base), "[]");
        }
        else
        {
            const TypeHash = StaticFnv1a64!(TypeHash!(hash, Base), "[" ~ T.length.stringof ~ "]");
        }
    }
    else static if (is (T Base == Base*))
    {
        static if (is (Base Args == function) && is (Base R == return))
        {
            const TypeHash = StaticFnv1a64!(TupleHash!(StaticFnv1a64!(TypeHash!(hash, R), "function("), Args), ")");
        }
        else
        {
            const TypeHash = StaticFnv1a64!(TypeHash!(Base), "*");
        }
    }
    else static if (is (T    Func == delegate) &&
                    is (Func Args == function) && is (Func R == return))
    {
        const TypeHash = StaticFnv1a64!(TupleHash!(StaticFnv1a64!(TypeHash!(hash, R), "delegate("), Args), ")");
    }
    else static if (is (typeof (T.init.values[0]) V) &&
                    is (typeof (T.init.keys[0])   K) &&
                    is (V[K] == T))
    {
        const TypeHash = StaticFnv1a64!(TypeHash!(StaticFnv1a64!(TypeHash!(hash, V), "["), K), "]");
    }
    else
    {
        const TypeHash = StaticFnv1a64!(hash, CheckedBaseType!(T).stringof);
    }
}

/******************************************************************************

    Evaluates to the concatenated type identifiers of the fields of T, starting
    with the n-th field. T must be a struct or union.

 ******************************************************************************/

template AggregateId ( T, size_t n = 0 )
{
    static if (n < T.tupleof.length)
    {
        const AggregateId = T.tupleof[n].offsetof.stringof ~ TypeId!(typeof (T.tupleof[n])) ~ AggregateId!(T, n + 1);
    }
    else
    {
        const AggregateId = "";
    }
}

/******************************************************************************

    Evaluates to the concatenated type identifiers of the elements of T.

 ******************************************************************************/

template TupleId ( T ... )
{
    static if (T.length)
    {
        const TupleId = TypeId!(T[0]) ~ TupleId!(T[1 .. $]);
    }
    else
    {
        const TupleId = "";
    }
}

/******************************************************************************

    Evaluates to the hash value of the type identifiers of the fields of T,
    starting with the n-th field, using hash as initial hash value. T must be a
    struct or union.

 ******************************************************************************/

template AggregateHash ( ulong hash, T, size_t n = 0 )
{
    static if (n < T.tupleof.length)
    {
        const AggregateHash = AggregateHash!(TypeHash!(StaticFnv1a64!(hash, T.tupleof[n].offsetof.stringof), typeof (T.tupleof[n])), T, n + 1);
    }
    else
    {
        const AggregateHash = hash;
    }
}

/******************************************************************************

    Evaluates to the hash value of the concatenated type identifiers of the
    elements of T, using hash as initial hash value.

 ******************************************************************************/

template TupleHash ( ulong hash, T ... )
{
    static if (T.length)
    {
        const TupleHash = TupleHash!(TypeHash!(hash, T[0]), T[1 .. $]);
    }
    else
    {
        const TupleHash = hash;
    }
}

/******************************************************************************

    Aliases the base type of T, if T is a typedef or enum, or T otherwise.
    Recurses into further typedefs/enums if required.
    Veryfies that the aliased type is not a class, pointer, function, delegate
    or associative array (a reference type other than a dynamic array).

 ******************************************************************************/

template CheckedBaseType ( T )
{
    alias BaseType!(T) CheckedBaseType;

    static assert (!(is (CheckedBaseType == class) ||
                     is (CheckedBaseType == interface)), TypeErrorMsg!(T, CheckedBaseType));
}

/******************************************************************************

    Aliases the base type of T, if T is a typedef or enum, or T otherwise.
    Recurses into further typedefs/enums if required.

 ******************************************************************************/

template BaseType ( T )
{
    static if (is (T Base == typedef) || is (T Base == enum))
    {
        alias BaseType!(Base) BaseType;
    }
    else
    {
        alias T BaseType;
    }
}

/******************************************************************************

    Evaluates to an error messsage used by CheckedBaseType.

 ******************************************************************************/

template TypeErrorMsg ( T, Base )
{
    static if (is (T == Base))
    {
        const TypeErrorMsg = Base.stringof ~ " is not supported because it is a class or interface";
    }
    else
    {
        const TypeErrorMsg = T.stringof ~ " is a typedef of " ~ Base.stringof ~ " which is not supported because it is a class or interface";
    }
}
