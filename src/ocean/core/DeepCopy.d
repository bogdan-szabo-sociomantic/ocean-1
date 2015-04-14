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

import ocean.core.Array : copy;

import ocean.core.Traits : isTypedef, StripTypedef;

import tango.core.Traits;

version (UnitTest)
{
    import tango.text.convert.Format;
}


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

// DeepCopy structs, including nested structs
unittest
{
    TestStruct1 from = TestStruct1(3, 9.2, "hello!", "1234567890", [1, 2, 3], [1.3, 4.9, 7.8, 3.2],
                                   NestedStruct1(7, "GBP", [33, 41, 123, 456]));

    TestStruct1 to;

    preDeepCopyCheck(from, to, __FILE__, __LINE__);
    DeepCopy!(TestStruct1)(from, to);
    postDeepCopyCheck(from, to, __FILE__, __LINE__);
}

// DeepCopy classes, including nested classes
unittest
{

    TestClass1 from = new TestClass1(3, 9.2, "hello!", "1234567890", [1, 2, 3], [1.3, 4.9, 7.8, 3.2],
                                     new NestedClass1(7, "GBP", [33, 41, 123, 456]));

    TestClass1 to = new TestClass1;

    preDeepCopyCheck(from, to, __FILE__, __LINE__);
    DeepCopy!(TestClass1)(from, to);
    postDeepCopyCheck(from, to, __FILE__, __LINE__);
}

// DeepCopy subclass
unittest
{
    TestSubclass1a from = new TestSubclass1a("mnopqr", 11, "beta!!", StructInClass1(201, [5.6, 6.7, 7.8, 8.9, 9.1, 10.11])),
                   to = new TestSubclass1a;

    preDeepCopyCheck(from, to, __FILE__, __LINE__);
    DeepCopy!(TestSubclass1a)(from, to);
    postDeepCopyCheck(from, to, __FILE__, __LINE__);

    /* DeepCopy shouldn't work for a different,
     * even if otherwise identical subclass.
     */
    TestSubclass1b to2 = new TestSubclass1b("ijefgk", 1, "zeta!!", StructInClass1(199, [3.2, 9.4]));
    static assert(!is(typeof(DeepCopy!(TestSubclass1a)(from, to2))));
    static assert(!is(typeof(DeepCopy!(TestSubclass1b)(from, to2))));
}

// DeepCopy of associative arrays is not yet implemented
unittest
{
    int[char[3]] from = ["abc" : 5, "def": 2],
                 to;

    static assert(!is(typeof(DeepCopy!(int[char[3]])(from, to))));
}

// DeepCopy dynamic arrays
unittest
{
    long[] from = [-12345, 402, 78910, -102030405],
           to;

    dynamicArrayDeepCopyCheck(from, to, { DeepCopy!(long[])(from, to); }, __FILE__, __LINE__);

    // Confirm DeepCopy doesn't work for different array types
    double[] to2;
    static assert(!is(typeof(DeepCopy!(long[])(from, to2))));
    static assert(!is(typeof(DeepCopy!(double[])(from, to2))));
}

// DeepCopy static arrays
unittest
{
    char[7] from = "hello!!",
            to;

    staticArrayDeepCopyCheck(from, to, { DeepCopy!(char[7])(from, to); }, __FILE__, __LINE__);

    // Confirm DeepCopy doesn't work for static arrays of different length
    char[8] to2;
    static assert(!is(typeof(DeepCopy!(char[7])(from, to2))));
    static assert(!is(typeof(DeepCopy!(char[8])(from, to2))));
}

// DeepCopy atomic value types
unittest
{
    int from = 3,
        to;

    valueDeepCopyCheck(from, to, { DeepCopy!(int)(from, to); }, __FILE__, __LINE__);

    // Confirm DeepCopy doesn't work for different types
    long to2;
    static assert(!is(typeof(DeepCopy!(int)(from, to2))));
    static assert(!is(typeof(DeepCopy!(long)(from, to2))));
}

// DeepCopy enums
unittest
{
    enum TestEnum
    {
        one = 1,
        two = 2,
        three = 3
    }

    TestEnum from = TestEnum.three,
             to;

    valueDeepCopyCheck(from, to, { DeepCopy!(TestEnum)(from, to); }, __FILE__, __LINE__);

    // Confirm DeepCopy doesn't work for different types
    int to2;
    static assert(!is(typeof(DeepCopy!(TestEnum)(from, to2))));
    static assert(!is(typeof(DeepCopy!(int)(from, to2))));
}

// DeepCopy enums with specified base type
unittest
{
    enum ByteEnum : ubyte
    {
        zero = 0,
        one = 1,
        two = 2
    }

    ByteEnum from = ByteEnum.two,
             to;

    valueDeepCopyCheck(from, to, { DeepCopy!(ByteEnum)(from, to); }, __FILE__, __LINE__);

    // Confirm DeepCopy doesn't work with base type
    ubyte to2;
    static assert(!is(typeof(DeepCopy!(ByteEnum)(from, to2))));
    static assert(!is(typeof(DeepCopy!(ubyte)(from, to2))));
}

// DeepCopy typedefs
unittest
{
    // atomic types
    {
        mixin(Typedef!(hash_t, "Hash"));

        Hash from = cast(Hash) 1234567890123456uL,
             to;

        valueDeepCopyCheck(from, to, { DeepCopy!(Hash)(from, to); }, __FILE__, __LINE__);

        // Confirm DeepCopy doesn't work with base type
        hash_t to2;
        static assert(!is(typeof(DeepCopy!(Hash)(from, to2))));
        static assert(!is(typeof(DeepCopy!(hash_t)(from, to2))));
    }

    // structs
    {
        TypedefStruct1 from = TypedefStruct1(7, "hello!", [127, 0, 0, 1]),
                       to;

        preDeepCopyCheck(from, to, __FILE__, __LINE__);
        DeepCopy!(TypedefStruct1)(from, to);
        postDeepCopyCheck(from, to, __FILE__, __LINE__);

        // Confirm DeepCopy doesn't work with base type
        TypedefBaseStruct1 to2;
        static assert(!is(typeof(DeepCopy!(TypedefStruct1)(from, to2))));
        static assert(!is(typeof(DeepCopy!(TypedefBaseStruct1)(from, to2))));
    }

    // dynamic arrays
    {
        mixin(Typedef!(long[], "DynArr"));

        DynArr from = cast(DynArr) [-1023L, 4444444L, 29296L],
               to;

        dynamicArrayDeepCopyCheck(from, to, { DeepCopy!(DynArr)(from, to); }, __FILE__, __LINE__);

        // Confirm DeepCopy doesn't work with base type
        long[] to2;
        static assert(!is(typeof(DeepCopy!(DynArr)(from, to2))));
        static assert(!is(typeof(DeepCopy!(long[])(from, to2))));
    }

    // static arrays
    {
        mixin(Typedef!(char[3], "Currency"));

        Currency from = "BIF",
                 to;

        staticArrayDeepCopyCheck(from, to, { DeepCopy!(Currency)(from, to); }, __FILE__, __LINE__);

        // Confirm DeepCopy doesn't work with base type
        char[3] to2;
        static assert(!is(typeof(DeepCopy!(Currency)(from, to2))));
        static assert(!is(typeof(DeepCopy!(char[3])(from, to2))));
    }
}

// DeepCopy of unions should not be possible
unittest
{
    union TestUnion
    {
        int n;
        double x;
    }

    TestUnion from, to;

    static assert(is(TestUnion == union));

    from.n = 23;

    static assert(!is(typeof(DeepCopy!(TestUnion)(from, to))));
}

// DeepCopy of arrays of unions should also fail
unittest
{
    union TestUnion
    {
        int n;
        double x;
    }

    TestUnion[] from, to;
    TestUnion f;

    f.x = 33.2;

    from[] = f;

    static assert(!is(typeof(DeepCopy!(TestUnion[])(from, to))));
}

// DeepCopy of pointers should fail
unittest
{
    int* from1, to1;
    static assert(!is(typeof(DeepCopy!(int*)(from, to))));

    double from2, to2;
    static assert(!is(typeof(DeepCopy!(typeof(&to2))(&from2, &to2))));
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

// Should not build with anything.
unittest
{
    int from, to;
    static assert(!is(typeof(UnknownDeepCopy(from, to))));
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

unittest
{
    struct TestStruct
    {
        int a;
        double x;
    }

    union TestUnion
    {
        int n;
        TestStruct s;
    }

    TestUnion from, to;

    static assert(is(TestUnion == union));

    from.s = TestStruct(7, 23.2);

    static assert(!is(typeof(UnionDeepCopy(from, to))));
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

// ValueDeepCopy with atomic types
unittest
{
    double from = 3.3,
           to;

    valueDeepCopyCheck(from, to, { ValueDeepCopy(from, to); }, __FILE__, __LINE__);

    real to2;
    static assert(!is(typeof(ValueDeepCopy(from, to2))));
}

// ValueDeepCopy with enums
unittest
{
    enum TestEnum
    {
        zero,
        one,
        two,
        three,
        four
    }

    TestEnum from = TestEnum.three,
             to;

    valueDeepCopyCheck(from, to, { ValueDeepCopy(from, to); }, __FILE__, __LINE__);

    int to2;
    static assert(!is(typeof(ValueDeepCopy(from, to2))));
}

// ValueDeepCopy with typedef'd atomic type
unittest
{
    mixin(Typedef!(hash_t, "Hash"));

    Hash from = cast(Hash) 1234567890uL,
         to;

    valueDeepCopyCheck(from, to, { ValueDeepCopy(from, to); }, __FILE__, __LINE__);

    hash_t to2;
    static assert(!is(typeof(ValueDeepCopy(from, to2))));
}

// ValueDeepCopy with typedef'd enums
unittest
{
    enum TestEnum : byte
    {
        zero,
        one,
        two,
        three,
        four
    }

    mixin(Typedef!(TestEnum, "OtherEnum"));

    OtherEnum from = OtherEnum.three,
              to;

    valueDeepCopyCheck(from, to, { ValueDeepCopy(from, to); }, __FILE__, __LINE__);

    byte to2;
    static assert(!is(typeof(ValueDeepCopy(from, to2))));
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

unittest
{
    int[char[3]] from = ["abc" : 5, "def": 2],
                 to;

    static assert(!is(typeof(AssocArrayDeepCopy(from, to))));
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

// Test that deep-copying regular dynamic arrays works
unittest
{
    char[] from = "hello!",
           to;

    dynamicArrayDeepCopyCheck(from, to, { DynamicArrayDeepCopy(from, to); }, __FILE__, __LINE__);

    ubyte[] to2;
    static assert(!is(typeof(DynamicArrayDeepCopy(from, to2))));
}

/* Test that copying from dynamic arrays works when they are typedefs.
 * Just to have fun, let's make them double typedefs :-)
 */
unittest
{
    mixin(Typedef!(int[], "_Arr"));
    mixin(Typedef!(_Arr, "Arr"));

    Arr from = cast(Arr) [127, 0, 0, 1],
        to;

    dynamicArrayDeepCopyCheck(from, to, { DynamicArrayDeepCopy(from, to); }, __FILE__, __LINE__);

    int[] to2;
    static assert(!is(typeof(DynamicArrayDeepCopy(from, to2))));
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


// Test that deep-copying regular static arrays works
unittest
{
    char[6] from = "hello!",
            to;

    staticArrayDeepCopyCheck(from, to, { StaticArrayDeepCopy(from, to); }, __FILE__, __LINE__);

    // deep copy shouldn't work with different-length static arrays.
    char[7] to2;
    static assert(!is(typeof(DynamicArrayDeepCopy(from, to2))));
}

// Test that copying static arrays works when they are typedefs
unittest
{
    mixin(Typedef!(int[4], "Arr"));

    Arr from = cast(Arr) [127, 0, 0, 1],
        to;

    staticArrayDeepCopyCheck(from, to, { StaticArrayDeepCopy(from, to); }, __FILE__, __LINE__);

    int[4] to2;
    static assert(!is(typeof(DynamicArrayDeepCopy(from, to2))));
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

// ArrayDeepCopy with dynamic arrays
unittest
{
    int[] from = [1, 2, 3, 4, 5],
          to = new int[from.length];

    dynamicArrayDeepCopyCheck(from, to, { ArrayDeepCopy(from, to); }, __FILE__, __LINE__);

    double[] to2 = new double[from.length];
    static assert(!is(typeof(ArrayDeepCopy(from, to2))));
}

// ArrayDeepCopy with static arrays
unittest
{
    int[5] from = [1, 2, 3, 4, 5],
           to;

    staticArrayDeepCopyCheck(from, to, { ArrayDeepCopy(from, to); }, __FILE__, __LINE__);

    int[] to2;
    static assert(!is(typeof(ArrayDeepCopy(from, to2))));
}

// ArrayDeepCopy with typedef'd dynamic arrays
unittest
{
    mixin(Typedef!(int[], "Arr"));

    Arr from = [1, 2, 3, 4, 5],
        to;

    to.length = from.length;

    dynamicArrayDeepCopyCheck(from, to, { ArrayDeepCopy(from, to); }, __FILE__, __LINE__);

    int[] to2;
    static assert(!is(typeof(ArrayDeepCopy(from, to2))));
}

// ArrayDeepCopy with typedef'd static arrays
unittest
{
    mixin(Typedef!(int[5], "Arr"));

    Arr from = [1, 2, 3, 4, 5],
        to;

    staticArrayDeepCopyCheck(from, to, { ArrayDeepCopy(from, to); }, __FILE__, __LINE__);

    int[5] to2;
    static assert(!is(typeof(ArrayDeepCopy(from, to2))));
}

// ArrayDeepCopy with dynamic arrays of static arrays
unittest
{
    uint[4][] from = [[127, 10, 3, 1], [255, 255, 255, 1], [192, 168, 2, 1]],
              to;

    to.length = from.length;

    foreach (i, row; from)
    {
        foreach (j, e; row)
        {
            assert(to[i][j] != e, "Elements of 2D arrays from and to should not be equal before deep copy.");
        }
    }

    ArrayDeepCopy(from, to);

    foreach (i, row; from)
    {
        foreach (j, e; row)
        {
            assert(to[i][j] == e, "Elements of 2D arrays from and to should be equal after deep copy.");
        }
    }

    int[4][] to2;
    static assert(!is(typeof(ArrayDeepCopy(from, to2))));
}

// ArrayDeepCopy with static arrays of dynamic arrays
unittest
{
    uint[][3] from = [[1, 2, 3], [4, 5, 6, 7, 8, 9, 10], [192, 168, 2, 1]],
              to;

    foreach (i, row; from)
    {
        to[i].length = row.length;
    }

    foreach (i, row; from)
    {
        foreach (j, e; row)
        {
            assert(to[i][j] != e, "Elements of 2D arrays from and to should not be equal before deep copy.");
        }
    }

    ArrayDeepCopy(from, to);

    foreach (i, row; from)
    {
        foreach (j, e; row)
        {
            assert(to[i][j] == e, "Elements of 2D arrays from and to should be equal after deep copy.");
        }
    }

    int[][3] to2;
    static assert(!is(typeof(ArrayDeepCopy(from, to2))));
}

// ArrayDeepCopy with void[] arrays
unittest
{
    void[] from = cast(void[]) "hello!",
           to;

    to.length = from.length;

    dynamicArrayDeepCopyCheck(from, to, { ArrayDeepCopy(from, to); }, __FILE__, __LINE__);

    assert(cast(char[]) to == "hello!", "void[] array to should be equal to 'hello!'.");

    char[] to2;
    static assert(!is(typeof(ArrayDeepCopy(from, to2))));
}

// ArrayDeepCopy with static void arrays
unittest
{
    void[6] from = cast(void[6]) "hello!",
            to = cast(void[6]) "wotcha";

    staticArrayDeepCopyCheck(from, to, { ArrayDeepCopy(from, to); }, __FILE__, __LINE__);

    assert(cast(char[6]) to == "hello!", "void[6] array to should be equal to 'hello!'.");

    char[6] to2;
    static assert(!is(typeof(ArrayDeepCopy(from, to2))));
}

// ArrayDeepCopy with static array of enums
unittest
{
    enum TestEnum
    {
        zero,
        one,
        two,
        three
    }

    TestEnum[3] from = [TestEnum.one, TestEnum.two, TestEnum.three],
                to;

    staticArrayDeepCopyCheck(from, to, { ArrayDeepCopy(from, to); }, __FILE__, __LINE__);

    int[3] to2;
    static assert(!is(typeof(ArrayDeepCopy(from, to2))));
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

/* StructDeepCopy is pretty well covered elsewhere so let's have
 * some fun with this direct unittest: a typedef'd struct with
 * typedefs within.
 */
unittest
{
    TypedefStruct2 from = TypedefStruct2(cast(TestName) "localhost", [127, 0, 0, 1]),
                   to;

    preDeepCopyCheck(from, to, __FILE__, __LINE__);
    StructDeepCopy(from, to);
    postDeepCopyCheck(from, to, __FILE__, __LINE__);

    TypedefBaseStruct2 to2;
    static assert(!is(typeof(StructDeepCopy(from, to2))));
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

// Deep copy a class with no base class apart from Object
unittest
{
    TestClass1 from = new TestClass1(1, 11.2, "alpha!", "123456789012", [7, 8, 9], [21.3, 4.9, 2.1, 1.1],
                                     new NestedClass1(9, "USD", [1, 2]));

    TestClass1 to = new TestClass1;

    preDeepCopyCheck(from, to, __FILE__, __LINE__);
    AggregateDeepCopy(from, to);
    postDeepCopyCheck(from, to, __FILE__, __LINE__);
}

// Deep copy a subclass
unittest
{
    TestSubclass1a from = new TestSubclass1a("abcdef", 7, "hello!", StructInClass1(5, [3.3, 1.2, 9.9])),
                   to = new TestSubclass1a;

    preDeepCopyCheck(from, to, __FILE__, __LINE__);
    ClassDeepCopy(from, to);
    postDeepCopyCheck(from, to, __FILE__, __LINE__);

    TestSubclass1b to2 = new TestSubclass1b;

    static assert(!is(typeof(ClassDeepCopy(from, to2))));
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

/* Given a class with no base class apart from Object,
 * AggregateDeepCopy should copy it entirely.
 */
unittest
{
    TestClass1 from = new TestClass1(2, 8.3, "wotcha", "123456789012345", [4, 5, 6], [21.3, 4.9],
                                     new NestedClass1(2, "EUR", [19, 20, 15, 88, 1, 9]));

    TestClass1 to = new TestClass1;

    preDeepCopyCheck(from, to, __FILE__, __LINE__);
    AggregateDeepCopy(from, to);
    postDeepCopyCheck(from, to, __FILE__, __LINE__);
}

/* Given a subclass, AggregateDeepCopy should copy the
 * subclass variables but not those of the base class.
 */
unittest
{
    TestSubclass1a from = new TestSubclass1a("ghijkl", 3, "wotcha!", StructInClass1(2, [9.1, 8.2, 7.3, 6.4, 5.5])),
                   to = new TestSubclass1a;

    preDeepCopyCheck(from, to, __FILE__, __LINE__);
    AggregateDeepCopy(from, to);
    postAggregateDeepCopyCheck(from, to, __FILE__, __LINE__);

    // Shouldn't copy a different (but identical) subclass.
    TestSubclass1b to2 = new TestSubclass1b;
    static assert(!is(typeof(AggregateDeepCopy(from, to2))));
}


/* Define a bunch of useful functionality for unittesting
 * DeepCopy and its subsidiary functions.
 */
version (UnitTest)
{
    private void valueDeepCopyCheck (T) (ref T from, ref T to, void delegate() copy, char[] file, long line)
    {
        assert(from != to, Format("Value deep-copy check called from {}:{}: {} from and to should "
                                  "not be equal before deep copy.", file, line, T.stringof));
        assert(from !is to, Format("Value deep-copy check called from {}:{}: {} from and to should "
                                   "not be identical before deep copy.", file, line, T.stringof));

        copy();

        assert(from == to, Format("Value deep-copy check called from {}:{}: {} from and to should "
                                  "be equal after deep copy.", file, line, T.stringof));
        assert(from is to, Format("Value deep-copy check called from {}:{}: {} from and to should "
                                  "be identical after deep copy.", file, line, T.stringof));
    }

    private void arrayPreDeepCopyCheck (T) (T from, T to, char[] file, long line)
    {
        assert(from != to, Format("Array deep-copy check called from {}:{}: {} from and to should "
                                  "not be equal before deep copy.", file, line, T.stringof));
        assert(from !is to, Format("Array deep-copy check called from {}:{}: {} from and to should "
                                   "not be identical before deep copy.", file, line, T.stringof));

        static if (!is(ElementTypeOfArray!(T) == void))
        {
            if (from.length == to.length)
            {
                bool equal = true;
                foreach (i, e; from)
                {
                    if (to[i] != e)
                    {
                        equal = false;
                    }
                }
                assert(!equal, Format("Array deep-copy check called from {}:{}: elements of {} from and to "
                                      "should not be equal before deep copy.", file, line, T.stringof));
            }
        }
    }

    private void arrayPostDeepCopyCheck (T) (T from, T to, char[] file, long line)
    {
        assert(from == to, Format("Array deep-copy check called from {}:{}: {} from and to should "
                                  "be equal after deep copy.", file, line, T.stringof));
        assert(from !is to, Format("Array deep-copy check called from {}:{}: {} from and to should "
                                   "not be identical after deep copy.", file, line, T.stringof));

        static if (!is(ElementTypeOfArray!(T) == void))
        {
            foreach (i, e; from)
            {
                assert(to[i] == e, Format("Array deep-copy check called from {}:{}: elements of {} from and to "
                                          "should be equal after deep copy.", file, line, T.stringof));
            }
        }
    }

    private void dynamicArrayDeepCopyCheck (T) (ref T from, ref T to, void delegate() copy, char[] file, long line)
    {
        arrayPreDeepCopyCheck(from, to, file, line);
        copy();
        arrayPostDeepCopyCheck(from, to, file, line);
    }

    private void staticArrayDeepCopyCheck (T) (T from, T to, void delegate() copy, char[] file, long line)
    {
        arrayPreDeepCopyCheck(from, to, file, line);
        copy();
        arrayPostDeepCopyCheck(from, to, file, line);
    }



    private struct NestedStruct1
    {
        int b;
        char[3] curr;
        int[] amt;
    }

    private struct TestStruct1
    {
        int a;
        double x;
        char[6] msg;
        char[] buffer;
        int[3] vals;
        double[] z;
        NestedStruct1 nest;
    }

    private void preDeepCopyCheck (ref TestStruct1 from, ref TestStruct1 to, char[] file, long line)
    {
        assert(from != to, Format("preDeepCopyCheck called from {}:{}: TestStruct1 from and to "
                                  "should not be equal before deep copy.", file, line));
        assert(from !is to, Format("preDeepCopyCheck called from {}:{}: TestStruct1 from and to "
                                   "should not be identical before deep copy.", file, line));

        assert(from.a != to.a, Format("preDeepCopyCheck called from {}:{}: TestStruct1 fields from.a and to.a "
                                      "should not be equal before deep copy.", file, line));
        assert(from.a !is to.a, Format("preDeepCopyCheck called from {}:{}: TestStruct1 fields from.a and to.a "
                                       "should not be identical before deep copy.", file, line));

        assert(from.x != to.x, Format("preDeepCopyCheck called from {}:{}: TestStruct1 fields from.x and to.x "
                                      "should not be equal before deep copy.", file, line));
        assert(from.x !is to.x, Format("preDeepCopyCheck called from {}:{}: TestStruct1 fields from.x and to.x "
                                       "should not be identical before deep copy.", file, line));

        assert(from.msg != to.msg, Format("preDeepCopyCheck called from {}:{}: TestStruct1 fields from.msg "
                                          "and to.msg should not be equal before deep copy.", file, line));
        assert(from.msg !is to.msg, Format("preDeepCopyCheck called from {}:{}: TestStruct1 fields from.msg "
                                           "and to.msg should not be identical before deep copy.", file, line));

        assert(from.buffer != to.buffer, Format("preDeepCopyCheck called from {}:{}: TestStruct1 fields from.buffer "
                                                "and to.buffer should not be equal before deep copy.", file, line));
        assert(from.buffer !is to.buffer, Format("preDeepCopyCheck called from {}:{}: TestStruct1 fields from.buffer "
                                                 "and to.buffer should not be identical before deep copy.", file, line));

        assert(from.vals != to.vals, Format("preDeepCopyCheck called from {}:{}: TestStruct1 fields from.vals "
                                            "and to.vals should not be equal before deep copy.", file, line));
        assert(from.vals !is to.vals, Format("preDeepCopyCheck called from {}:{}: TestStruct1 fields from.vals "
                                             "and to.vals should not be identical before deep copy.", file, line));

        assert(from.z != to.z, Format("preDeepCopyCheck called from {}:{}: TestStruct1 fields from.z and to.z "
                                      "should not be equal before deep copy.", file, line));
        assert(from.z !is to.z, Format("preDeepCopyCheck called from {}:{}: TestStruct1 fields from.z and to.z "
                                       "should not be identical before deep copy.", file, line));

        assert(from.nest != to.nest, Format("preDeepCopyCheck called from {}:{}: TestStruct1 fields from.nest "
                                            "and to.nest should not be equal before deep copy.", file, line));
        assert(from.nest !is to.nest, Format("preDeepCopyCheck called from {}:{}: TestStruct1 fields from.nest "
                                             "and to.nest should not be identical before deep copy.", file, line));

        assert(from.nest.b != to.nest.b, Format("preDeepCopyCheck called from {}:{}: Nested struct fields from.nest.b "
                                                "and to.nest.b should not be equal before deep copy.", file, line));
        assert(from.nest.b !is to.nest.b, Format("preDeepCopyCheck called from {}:{}: Nested struct fields from.nest.b "
                                                 "and to.nest.b should not be identical before deep copy.", file, line));

        assert(from.nest.curr != to.nest.curr, Format("preDeepCopyCheck called from {}:{}: Nested struct fields from.nest.curr "
                                                      "and to.nest.curr should not be equal before deep copy.", file, line));
        assert(from.nest.curr !is to.nest.curr, Format("preDeepCopyCheck called from {}:{}: Nested struct fields from.nest.curr "
                                                       "and to.nest.curr should not be identical before deep copy.", file, line));

        assert(from.nest.amt != to.nest.amt, Format("preDeepCopyCheck called from {}:{}: Nested struct fields from.nest.amt "
                                                    "and to.nest.amt should not be equal before deep copy.", file, line));
        assert(from.nest.amt !is to.nest.amt, Format("preDeepCopyCheck called from {}:{}: Nested struct fields from.nest.amt "
                                                     "and to.nest.amt should not be identical before deep copy.", file, line));
    }

    private void postDeepCopyCheck (ref TestStruct1 from, ref TestStruct1 to, char[] file, long line)
    {
        assert(from !is to, Format("postDeepCopyCheck called from {}:{}: TestStruct1 from and to "
                                   "should not be identical after deep copy.", file, line));

        assert(from.a == to.a, Format("postDeepCopyCheck called from {}:{}: TestStruct1 fields from.a and to.a "
                                      "should be equal after deep copy.", file, line));
        assert(from.a is to.a, Format("postDeepCopyCheck called from {}:{}: TestStruct1 fields from.a and to.a "
                                      "should be identical after deep copy.", file, line));

        assert(from.x == to.x, Format("postDeepCopyCheck called from {}:{}: TestStruct1 fields from.x and to.x "
                                      "should be equal after deep copy.", file, line));
        assert(from.x is to.x, Format("postDeepCopyCheck called from {}:{}: TestStruct1 fields from.x and to.x "
                                      "should be identical after deep copy.", file, line));

        assert(from.msg == to.msg, Format("postDeepCopyCheck called from {}:{}: TestStruct1 fields from.msg "
                                          "and to.msg should be equal after deep copy.", file, line));
        assert(from.msg !is to.msg, Format("postDeepCopyCheck called from {}:{}: TestStruct1 fields from.msg "
                                           "and to.msg should not be identical after deep copy.", file, line));

        assert(from.buffer == to.buffer, Format("postDeepCopyCheck called from {}:{}: TestStruct1 fields from.buffer "
                                                "and to.buffer should be equal after deep copy.", file, line));
        assert(from.buffer !is to.buffer, Format("postDeepCopyCheck called from {}:{}: TestStruct1 fields from.buffer "
                                                 "and to.buffer should not be identical after deep copy.", file, line));

        assert(from.vals == to.vals, Format("postDeepCopyCheck called from {}:{}: TestStruct1 fields from.vals "
                                            "and to.vals should be equal after deep copy.", file, line));
        assert(from.vals !is to.vals, Format("postDeepCopyCheck called from {}:{}: TestStruct1 fields from.vals "
                                             "and to.vals should not be identical after deep copy.", file, line));

        assert(from.z == to.z, Format("postDeepCopyCheck called from {}:{}: TestStruct1 fields from.z and to.z "
                                      "should be equal after deep copy.", file, line));
        assert(from.z !is to.z, Format("postDeepCopyCheck called from {}:{}: TestStruct1 fields from.z and to.z "
                                       "should not be identical after deep copy.", file, line));

        assert(from.nest != to.nest, Format("postDeepCopyCheck called from {}:{}: TestStruct1 fields from.nest "
                                            "and to.nest should not be equal after deep copy.", file, line));
        assert(from.nest !is to.nest, Format("postDeepCopyCheck called from {}:{}: TestStruct1 fields from.nest "
                                             "and to.nest should not be identical after deep copy.", file, line));

        assert(from.nest.b == to.nest.b, Format("postDeepCopyCheck called from {}:{}: Nested struct fields from.nest.b "
                                                "and to.nest.b should be equal after deep copy.", file, line));
        assert(from.nest.b is to.nest.b, Format("postDeepCopyCheck called from {}:{}: Nested struct fields from.nest.b "
                                                "and to.nest.b should be identical after deep copy.", file, line));

        assert(from.nest.curr == to.nest.curr, Format("postDeepCopyCheck called from {}:{}: Nested struct fields from.nest.curr "
                                                      "and to.nest.curr should be equal after deep copy.", file, line));
        assert(from.nest.curr !is to.nest.curr, Format("postDeepCopyCheck called from {}:{}: Nested struct fields from.nest.curr "
                                                       "and to.nest.curr should not be identical after deep copy.", file, line));

        assert(from.nest.amt == to.nest.amt, Format("postDeepCopyCheck called from {}:{}: Nested struct fields from.nest.amt "
                                                    "and to.nest.amt should be equal after deep copy.", file, line));
        assert(from.nest.amt !is to.nest.amt, Format("postDeepCopyCheck called from {}:{}: Nested struct fields from.nest.amt "
                                                     "and to.nest.amt should not be identical after deep copy.", file, line));
    }



    private struct TypedefBaseStruct1
    {
        int a;
        char[] msg;
        ubyte[4] ip;
    }

    private mixin(Typedef!(TypedefBaseStruct1, "TypedefStruct1"));

    private void preDeepCopyCheck(ref TypedefStruct1 from, ref TypedefStruct1 to, char[] file, long line)
    {
        assert(from.a != to.a, Format("preDeepCopyCheck called from {}:{}: TypedefStruct1 fields from.a and to.a "
                                      "should not be equal before deep copy.", file, line));
        assert(from.a !is to.a, Format("preDeepCopyCheck called from {}:{}: TypedefStruct1 fields from.a and to.a "
                                       "should not be identical before deep copy.", file, line));

        assert(from.msg != to.msg, Format("preDeepCopyCheck called from {}:{}: TypedefStruct1 fields from.msg "
                                          "and to.msg should not be equal before deep copy.", file, line));
        assert(from.msg !is to.msg, Format("preDeepCopyCheck called from {}:{}: TypedefStruct1 fields from.msg "
                                           "and to.msg should not be identical before deep copy.", file, line));

        assert(from.ip != to.ip, Format("preDeepCopyCheck called from {}:{}: TypedefStruct1 fields from.ip and to.ip "
                                        "should not be equal before deep copy.", file, line));
        assert(from.ip !is to.ip, Format("preDeepCopyCheck called from {}:{}: TypedefStruct1 fields from.ip and to.ip "
                                         "should not be identical before deep copy.", file, line));
    }

    private void postDeepCopyCheck(ref TypedefStruct1 from, ref TypedefStruct1 to, char[] file, long line)
    {
        assert(from.a == to.a, Format("postDeepCopyCheck called from {}:{}: TypedefStruct1 fields from.a and to.a "
                                      "should be equal after deep copy.", file, line));
        assert(from.a is to.a, Format("postDeepCopyCheck called from {}:{}: TypedefStruct1 fields from.a and to.a "
                                      "should be identical after deep copy.", file, line));

        assert(from.msg == to.msg, Format("postDeepCopyCheck called from {}:{}: TypedefStruct1 fields from.msg "
                                          "and to.msg should be equal after deep copy.", file, line));
        assert(from.msg !is to.msg, Format("postDeepCopyCheck called from {}:{}: TypedefStruct1 fields from.msg "
                                           "and to.msg should not be identical after deep copy.", file, line));

        assert(from.ip == to.ip, Format("postDeepCopyCheck called from {}:{}: TypedefStruct1 fields from.ip and to.ip "
                                        "should be equal after deep copy.", file, line));
        assert(from.ip !is to.ip, Format("postDeepCopyCheck called from {}:{}: TypedefStruct1 fields from.ip and to.ip "
                                         "should not be identical after deep copy.", file, line));
    }



    private mixin(Typedef!(char[], "TestName"));
    private mixin(Typedef!(int[4], "TestIP"));

    private struct TypedefBaseStruct2
    {
        TestName name;
        TestIP ip;
    }

    private mixin(Typedef!(TypedefBaseStruct2, "TypedefStruct2"));

    private void preDeepCopyCheck (ref TypedefStruct2 from, ref TypedefStruct2 to, char[] file, long line)
    {
        assert(from.name != to.name, Format("preDeepCopyCheck called from {}:{}: TypedefStruct2 members from.name "
                                            "and to.name should not be equal before deep copy.", file, line));
        assert(from.name !is to.name, Format("preDeepCopyCheck called from {}:{}: TypedefStruct2 members from.name "
                                             "and to.name should not be identical before deep copy.", file, line));

        assert(from.ip != to.ip, Format("preDeepCopyCheck called from {}:{}: TypedefStruct2 members from.ip and to.ip "
                                        "should not be equal before deep copy.", file, line));
        assert(from.ip !is to.ip, Format("preDeepCopyCheck called from {}:{}: TypedefStruct2  members from.ip and to.ip "
                                         "should not be identical before deep copy.", file, line));
    }

    private void postDeepCopyCheck (ref TypedefStruct2 from, ref TypedefStruct2 to, char[] file, long line)
    {
        assert(from.name == to.name, Format("postDeepCopyCheck called from {}:{}: TypedefStruct2 members from.name "
                                            "and to.name should be equal after deep copy.", file, line));
        assert(from.name !is to.name, Format("postDeepCopyCheck called from {}:{}: TypedefStruct2 members from.name "
                                             "and to.name should not be identical after deep copy.", file, line));

        assert(from.ip == to.ip, Format("postDeepCopyCheck called from {}:{}: TypedefStruct2  members from.ip and to.ip "
                                        "should be equal after deep copy.", file, line));
        assert(from.ip !is to.ip, Format("postDeepCopyCheck called from {}:{}: TypedefStruct2 members from.ip and to.ip "
                                         "should not be identical after deep copy.", file, line));
    }



    private class NestedClass1
    {
        int b;
        char[3] curr;
        int[] amt;

        this () {}

        this (int b, char[3] curr, int[] amt)
        {
            this.b = b;
            this.curr[] = curr[];
            this.amt = amt.dup;
        }
    }

    private class TestClass1
    {
        int a;
        double x;
        char[6] msg;
        char[] buffer;
        int[3] vals;
        double[] z;
        NestedClass1 nest;

        this ()
        {
            nest = new NestedClass1;
        }

        this (int a, double x, char[6] msg, char[] buffer,
              int[3] vals, double[] z, NestedClass1 nest)
        {
            this.a = a;
            this.x = x;
            this.msg[] = msg[];
            this.buffer = buffer.dup;
            this.vals[] = vals[];
            this.z = z.dup;
            this.nest = nest;
        }
    }

    private void preDeepCopyCheck (ref TestClass1 from, ref TestClass1 to, char[] file, long line)
    {
        assert(from != to, Format("preDeepCopyCheck called from {}:{}: TestClass1 from and to "
                                  "should not be equal before deep copy.", file, line));
        assert(from !is to, Format("preDeepCopyCheck called from {}:{}: TestClass1 from and to "
                                   "should not be identical before deep copy.", file, line));

        assert(from.a != to.a, Format("preDeepCopyCheck called from {}:{}: TestClass1 fields from.a and to.a "
                                      "should not be equal before deep copy.", file, line));
        assert(from.a !is to.a, Format("preDeepCopyCheck called from {}:{}: TestClass1 fields from.a and to.a "
                                       "should not be identical before deep copy.", file, line));

        assert(from.x != to.x, Format("preDeepCopyCheck called from {}:{}: TestClass1 fields from.x and to.x "
                                      "should not be equal before deep copy.", file, line));
        assert(from.x !is to.x, Format("preDeepCopyCheck called from {}:{}: TestClass1 fields from.x and to.x "
                                       "should not be identical before deep copy.", file, line));

        assert(from.msg != to.msg, Format("preDeepCopyCheck called from {}:{}: TestClass1 fields from.msg and "
                                          "to.msg should not be equal before deep copy.", file, line));
        assert(from.msg !is to.msg, Format("preDeepCopyCheck called from {}:{}: TestClass1 fields from.msg and "
                                           "to.msg should not be identical before deep copy.", file, line));

        assert(from.buffer != to.buffer, Format("preDeepCopyCheck called from {}:{}: TestClass1 fields from.buffer and "
                                                "to.buffer should not be equal before deep copy.", file, line));
        assert(from.buffer !is to.buffer, Format("preDeepCopyCheck called from {}:{}: TestClass1 fields from.buffer and "
                                                 "to.buffer should not be identical before deep copy.", file, line));

        assert(from.vals != to.vals, Format("preDeepCopyCheck called from {}:{}: TestClass1 fields from.vals and "
                                            "to.vals should not be equal before deep copy.", file, line));
        assert(from.vals !is to.vals, Format("preDeepCopyCheck called from {}:{}: TestClass1 fields from.vals and "
                                             "to.vals should not be identical before deep copy.", file, line));

        assert(from.z != to.z, Format("preDeepCopyCheck called from {}:{}: TestClass1 fields from.z and to.z "
                                      "should not be equal before deep copy.", file, line));
        assert(from.z !is to.z, Format("preDeepCopyCheck called from {}:{}: TestClass1 fields from.z and to.z "
                                       "should not be identical before deep copy.", file, line));

        assert(from.nest != to.nest, Format("preDeepCopyCheck called from {}:{}: TestClass1 fields from.nest and "
                                            "to.nest should not be equal before deep copy.", file, line));
        assert(from.nest !is to.nest, Format("preDeepCopyCheck called from {}:{}: TestClass1 fields from.nest and "
                                             "to.nest should not be identical before deep copy.", file, line));

        assert(from.nest.b != to.nest.b, Format("preDeepCopyCheck called from {}:{}: TestClass1 fields from.nest.b and "
                                                "to.nest.b should not be equal before deep copy.", file, line));
        assert(from.nest.b !is to.nest.b, Format("preDeepCopyCheck called from {}:{}: TestClass1 fields from.nest.b and "
                                                 "to.nest.b should not be identical before deep copy.", file, line));

        assert(from.nest.curr != to.nest.curr, Format("preDeepCopyCheck called from {}:{}: TestClass1 fields from.nest.curr and "
                                                      "to.nest.curr should not be equal before deep copy.", file, line));
        assert(from.nest.curr !is to.nest.curr, Format("preDeepCopyCheck called from {}:{}: TestClass1 fields from.nest.curr and "
                                                       "to.nest.curr should not be identical before deep copy.", file, line));

        assert(from.nest.amt != to.nest.amt, Format("preDeepCopyCheck called from {}:{}: TestClass1 fields from.nest.amt and "
                                                    "to.nest.amt should not be equal before deep copy.", file, line));
        assert(from.nest.amt !is to.nest.amt, Format("preDeepCopyCheck called from {}:{}: TestClass1 fields from.nest.amt and "
                                                     "to.nest.amt should not be identical before deep copy.", file, line));
    }

    private void postDeepCopyCheck (ref TestClass1 from, ref TestClass1 to, char[] file, long line)
    {
        assert(from !is to, Format("postDeepCopyCheck called from {}:{}: TestClass1 from and to "
                                   "should not be identical after deep copy.", file, line));

        assert(from.a == to.a, Format("postDeepCopyCheck called from {}:{}: TestClass1 fields from.a and to.a "
                                      "should be equal after deep copy.", file, line));
        assert(from.a is to.a, Format("postDeepCopyCheck called from {}:{}: TestClass1 fields from.a and to.a "
                                      "should be identical after deep copy.", file, line));

        assert(from.x == to.x, Format("postDeepCopyCheck called from {}:{}: TestClass1 fields from.x and to.x "
                                      "should be equal after deep copy.", file, line));
        assert(from.x is to.x, Format("postDeepCopyCheck called from {}:{}: TestClass1 fields from.x and to.x "
                                      "should be identical after deep copy.", file, line));

        assert(from.msg == to.msg, Format("postDeepCopyCheck called from {}:{}: TestClass1 fields from.msg and "
                                          "to.msg should be equal after deep copy.", file, line));
        assert(from.msg !is to.msg, Format("postDeepCopyCheck called from {}:{}: TestClass1 fields from.msg and "
                                           "to.msg should not be identical after deep copy.", file, line));

        assert(from.buffer == to.buffer, Format("postDeepCopyCheck called from {}:{}: TestClass1 fields from.buffer and "
                                                "to.buffer should be equal after deep copy.", file, line));
        assert(from.buffer !is to.buffer, Format("postDeepCopyCheck called from {}:{}: TestClass1 fields from.buffer and "
                                                 "to.buffer should not be identical after deep copy.", file, line));

        assert(from.vals == to.vals, Format("postDeepCopyCheck called from {}:{}: TestClass1 fields from.vals and "
                                            "to.vals should be equal after deep copy.", file, line));
        assert(from.vals !is to.vals, Format("postDeepCopyCheck called from {}:{}: TestClass1 fields from.vals and "
                                             "to.vals should not be identical after deep copy.", file, line));

        assert(from.z == to.z, Format("postDeepCopyCheck called from {}:{}: TestClass1 fields from.z and to.z "
                                      "should be equal after deep copy.", file, line));
        assert(from.z !is to.z, Format("postDeepCopyCheck called from {}:{}: TestClass1 fields from.z and to.z "
                                       "should not be identical after deep copy.", file, line));

        assert(from.nest != to.nest, Format("postDeepCopyCheck called from {}:{}: TestClass1 fields from.nest and "
                                            "to.nest should not be equal after deep copy.", file, line));
        assert(from.nest !is to.nest, Format("postDeepCopyCheck called from {}:{}: TestClass1 fields from.nest and "
                                             "to.nest should not be identical after deep copy.", file, line));

        assert(from.nest.b == to.nest.b, Format("postDeepCopyCheck called from {}:{}: TestClass1 fields from.nest.b and "
                                                "to.nest.b should be equal after deep copy.", file, line));
        assert(from.nest.b is to.nest.b, Format("postDeepCopyCheck called from {}:{}: TestClass1 fields from.nest.b and "
                                                "to.nest.b should be identical after deep copy.", file, line));

        assert(from.nest.curr == to.nest.curr, Format("postDeepCopyCheck called from {}:{}: TestClass1 fields from.nest.curr and "
                                                      "to.nest.curr should be equal after deep copy.", file, line));
        assert(from.nest.curr !is to.nest.curr, Format("postDeepCopyCheck called from {}:{}: TestClass1 fields from.nest.curr and "
                                                       "to.nest.curr should not be identical after deep copy.", file, line));

        assert(from.nest.amt == to.nest.amt, Format("postDeepCopyCheck called from {}:{}: TestClass1 fields from.nest.amt and "
                                                    "to.nest.amt should be equal after deep copy.", file, line));
        assert(from.nest.amt !is to.nest.amt, Format("postDeepCopyCheck called from {}:{}: TestClass1 fields from.nest.amt and "
                                                     "to.nest.amt should not be identical after deep copy.", file, line));
    }



    private struct StructInClass1
    {
        int n;
        double[] x;
    }

    private class TestBaseClass1
    {
        char[] b;
        StructInClass1 s;

        this (char[] b, StructInClass1 s)
        {
            this.b = b.dup;
            this.s.n = s.n;
            this.s.x = s.x.dup;
        }

        this () {}
    }

    private class TestSubclass1a : TestBaseClass1
    {
        char[6] name;
        int a;

        this (char[6] name, int a, char[] b, StructInClass1 s)
        {
            this.name[] = name[];
            this.a = a;
            super(b, s);
        }

        this () {}
    }

    private class TestSubclass1b : TestBaseClass1
    {
        char[6] name;
        int a;

        this (char[6] name, int a, char[] b, StructInClass1 s)
        {
            this.name[] = name[];
            this.a = a;
            super(b, s);
        }

        this () {}
    }

    private void preDeepCopyCheck (ref TestSubclass1a from, ref TestSubclass1a to, char[] file, long line)
    {
        assert(from.name != to.name, Format("preDeepCopyCheck called from {}:{}: TestSubclass1a fields from.name "
                                            "and to.name should not be equal before deep copy.", file, line));
        assert(from.name !is to.name, Format("preDeepCopyCheck called from {}:{}: TestSubclass1a fields from.name "
                                             "and to.name should not be identical before deep copy.", file, line));

        assert(from.a != to.a, Format("preDeepCopyCheck called from {}:{}: TestSubclass1a fields from.a and to.a "
                                      "should not be equal before deep copy.", file, line));
        assert(from.a !is to.a, Format("preDeepCopyCheck called from {}:{}: TestSubclass1a fields from.a and to.a "
                                       "should not be identical before deep copy.", file, line));

        assert(from.b != to.b, Format("preDeepCopyCheck called from {}:{}: TestSubclass1a fields from.b and to.b "
                                      "should not be equal before deep copy.", file, line));
        assert(from.b !is to.b, Format("preDeepCopyCheck called from {}:{}: TestSubclass1a fields from.b and to.b "
                                       "should not be identical before deep copy.", file, line));

        assert(from.s.n != to.s.n, Format("preDeepCopyCheck called from {}:{}: TestSubclass1a fields from.s.n and "
                                          "to.s.n should not be equal before deep copy.", file, line));
        assert(from.s.n !is to.s.n, Format("preDeepCopyCheck called from {}:{}: TestSubclass1a fields from.s.n and "
                                           "to.s.n should not be identical before deep copy.", file, line));

        assert(from.s.x != to.s.x, Format("preDeepCopyCheck called from {}:{}: TestSubclass1a fields from.s.x and "
                                          "to.s.x should not be equal before deep copy.", file, line));
        assert(from.s.x !is to.s.x, Format("preDeepCopyCheck called from {}:{}: TestSubclass1a fields from.s.x and "
                                           "to.s.x should not be identical before deep copy.", file, line));
    }

    private void postDeepCopyCheck (ref TestSubclass1a from, ref TestSubclass1a to, char[] file, long line)
    {
        assert(from.name == to.name,  Format("postDeepCopyCheck called from {}:{}: TestSubclass1a fields from.name "
                                             "and to.name should be equal after deep copy.", file, line));
        assert(from.name !is to.name,  Format("postDeepCopyCheck called from {}:{}: TestSubclass1a fields from.name "
                                              "and to.name should not be identical after deep copy.", file, line));

        assert(from.a == to.a,  Format("postDeepCopyCheck called from {}:{}: TestSubclass1a fields from.a and to.a "
                                       "should be equal after deep copy.", file, line));
        assert(from.a is to.a,  Format("postDeepCopyCheck called from {}:{}: TestSubclass1a fields from.a and to.a "
                                       "should be identical after deep copy.", file, line));

        assert(from.b == to.b,  Format("postDeepCopyCheck called from {}:{}: TestSubclass1a fields from.b and to.b "
                                       "should be equal after deep copy.", file, line));
        assert(from.b !is to.b,  Format("postDeepCopyCheck called from {}:{}: TestSubclass1a fields from.b and to.b "
                                        "should not be identical after deep copy.", file, line));

        assert(from.s.n == to.s.n,  Format("postDeepCopyCheck called from {}:{}: TestSubclass1a fields from.s.n and "
                                           "to.s.n should be equal after deep copy.", file, line));
        assert(from.s.n is to.s.n,  Format("postDeepCopyCheck called from {}:{}: TestSubclass1a fields from.s.n and "
                                           "to.s.n should be identical after deep copy.", file, line));

        assert(from.s.x == to.s.x,  Format("postDeepCopyCheck called from {}:{}: TestSubclass1a fields from.s.x and "
                                           "to.s.x should be equal after deep copy.", file, line));
        assert(from.s.x !is to.s.x,  Format("postDeepCopyCheck called from {}:{}: TestSubclass1a fields from.s.x and "
                                            "to.s.x should not be identical after deep copy.", file, line));
    }

    private void postAggregateDeepCopyCheck(ref TestSubclass1a from, ref TestSubclass1a to, char[] file, long line)
    {
        // Fields belonging to the subclass itself should be identical after AggregateDeepCopy
        assert(from.name == to.name,  Format("postAggregateDeepCopyCheck called from {}:{}: TestSubclass1a fields from.name "
                                             "and to.name should be equal after AggregateDeepCopy.", file, line));
        assert(from.name !is to.name,  Format("postAggregateDeepCopyCheck called from {}:{}: TestSubclass1a fields from.name "
                                              "and to.name should not be identical after AggregateDeepCopy.", file, line));

        assert(from.a == to.a,  Format("postAggregateDeepCopyCheck called from {}:{}: TestSubclass1a fields from.a and to.a "
                                       "should be equal after AggregateDeepCopy.", file, line));
        assert(from.a is to.a,  Format("postAggregateDeepCopyCheck called from {}:{}: TestSubclass1a fields from.a and to.a "
                                       "should be identical after AggregateDeepCopy.", file, line));

        // Fields belonging to the base class should not have been copied by AggregateDeepCopy
        assert(from.b != to.b,  Format("postAggregateDeepCopyCheck called from {}:{}: TestSubclass1a fields from.b and to.b "
                                       "should not be equal after AggregateDeepCopy.", file, line));
        assert(from.b !is to.b,  Format("postAggregateDeepCopyCheck called from {}:{}: TestSubclass1a fields from.b and to.b "
                                        "should not be identical after AggregateDeepCopy.", file, line));

        assert(from.s.n != to.s.n,  Format("postAggregateDeepCopyCheck called from {}:{}: TestSubclass1a fields from.s.n and "
                                           "to.s.n should not be equal after AggregateDeepCopy.", file, line));
        assert(from.s.n !is to.s.n,  Format("postAggregateDeepCopy called from {}:{}: TestSubclass1a fields from.s.n and "
                                            "to.s.n should not be identical after AggregateDeepCopy.", file, line));

        assert(from.s.x != to.s.x,  Format("postAggregateDeepCopyCheck called from {}:{}: TestSubclass1a fields from.s.x and "
                                           "to.s.x should be not equal after AggregateDeepCopy.", file, line));
        assert(from.s.x !is to.s.x,  Format("postAggregateDeepCopyCheck called from {}:{}: TestSubclass1a fields from.s.x and "
                                            "to.s.x should not be identical after AggregateDeepCopy.", file, line));
    }
}


/*******************************************************************************

    Template to determine the correct DeepReset function to call dependent on
    the type given.

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
