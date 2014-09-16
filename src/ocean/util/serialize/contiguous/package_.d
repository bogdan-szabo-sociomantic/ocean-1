/*******************************************************************************

    Format Explained
    ----------------

    This package implements a binary serialization format useful for efficient
    struct representation in monomorphic environment. All servers are expected to
    have similar enough h/w architecture and software to have identical in-memory
    representation of D structures. It doesn't work as a generic cross-platform
    serialization format.

    Essential idea here is storing all struct instance data (including all data
    transitively accessible via arrays / pointers) in a single contiguous memory
    buffer. Which is exactly the reason why package is named like that. That way
    deserialization is very fast and doesn't need any memory allocation for simple
    cases - all deserializer needs to do is to iterate through the memory chunk and
    update internal pointers.

    ``contiguous.Deserializer`` returns memory buffer wrapped in ``Contiguous!(S)``
    struct. Such wrapper is guarantted to conform contiguity expectation explained
    above. It is recommended to use it in your application instead of plain
    ``void[]`` for added type safety.

    There are certain practical complications with it that are explained as part of
    ``contiguous.Serializer`` and ``contiguous.Deserializer`` API docs. Those should
    not concern most applications and won't be mentioned in the overview.

    Available Decorators
    --------------------

    ``contiguous.VersionDecorator`` adds struct versioning information to the basic
    binary serialization format. It expects struct definitions with additional
    meta-information available at compile-time and prepends version number byte
    before actual data buffer. Upon loading the serialized data, the stored version
    number is compared against the expected one and automatic struct conversion is
    done if needed. It only allows conversion through one version
    increment/decrement at a time.

    ``contiguous.MultiVersionDecorator`` is almost identical to
    plain ``VersionDecorator`` but allows the version increment range to be defined
    in the constructor. Distinct classes are used so that, if incoming data
    accidentally is too old, performance-critical applications will emit an error
    rather than wasting CPU cycles converting through multiple versions.
    For other aplications multi-version implementation should be more convenient.

    Recommended Usage
    -----------------

    The contiguous serialization format and the version decorator are primarily
    designed to be used with krill structs stored in the DHT. It is recommended to
    completely strip the version information with the help of the decorator upon
    initially reading a record from the DHT, and to use the resulting raw contiguous
    buffer internally in the application (i.e. in a cache). That way you can use any
    of the serialization/deserialization utilities in the application without
    thinking about the version meta-data

    Typical code pattern for a cache:

    1) Define a ``Cache`` of ``Contiguous!(S)`` elements.
    2) When receiving data from DHT do
    ``version_decorator.loadCopy!(S)(dht_data, cache_element)``
    3) Use ``contiguous.Deserializer.copy(cache_element, contiguous_instance)`` for
    copying the struct instance if needed
    4) Use ``contiguous_instance.ptr`` to work with deserialized data as if
    it was ``S*``

*******************************************************************************/

module ocean.util.serialize.contiguous.package_;

/******************************************************************************

    Public imports

******************************************************************************/

public import ocean.util.serialize.contiguous.Contiguous,
              ocean.util.serialize.contiguous.Deserializer,
              ocean.util.serialize.contiguous.Serializer;

version(UnitTest):

/******************************************************************************

    Test imports

******************************************************************************/

private import ocean.core.Test,
               ocean.core.DeepCopy;

/******************************************************************************

    Complex data structure used in most tests

    Some test define more specialized structures as nested types for debugging
    simplicity

******************************************************************************/

struct S
{
    struct S_1
    {
        int a;
        double b;
    }

    struct S_2
    {
        int[]   a;
        int[][] b;
    }

    struct S_3
    {
        float[][2] a;
    }

    struct S_4
    {
        char[][] a;
    }

    S_1 s1;

    S_2 s2;
    S_2[1] s2_static_array; 

    S_3 s3;

    S_4[] s4_dynamic_array;

    S[] recursive;

    char[][3] static_of_dynamic;

    union
    {
        int union_a;
        int union_b;
    }
}

/******************************************************************************

    Returns:
        S instance with fields set to some meaningful values

******************************************************************************/

S defaultS()
{
    S s;

    s.s1.a = 42;
    s.s1.b = 42.42;

    s.s2.a = [ 1, 2, 3, 4 ];
    s.s2.b = [ [ 0 ], [ 20, 21 ], [ 22 ] ];

    DeepCopy!(S.S_2)(s.s2, s.s2_static_array[0]);

    s.s3.a[0] = [ 1.0, 2.0 ];
    s.s3.a[1] = [ 100.1, 200.2 ];

    s.s4_dynamic_array = [
        S.S_4([ "aaa", "bbb", "ccc" ]),
        S.S_4([ "a", "bb", "ccc", "dddd" ]),
        S.S_4([ "" ])
    ];

    s.static_of_dynamic[] = [ "a", "b", "c" ];

    s.union_a = 42;

    return s;
}

/******************************************************************************
    
    Does series of tests on `checked` to verify that it is equal to struct 
    returned by `defaultS()`


    Params:
        checked = S instance to check for equality

******************************************************************************/

void testS(NamedTest t, ref S checked)
{
    with (t)
    {
        test!("==")(checked.s1, defaultS().s1);
        test!("==")(checked.s2.a, defaultS().s2.a);
        test!("==")(checked.s2.b, defaultS().s2.b);

        foreach (index, elem; checked.s2_static_array)
        {
            test!("==")(elem.a, defaultS().s2_static_array[index].a);
        }

        foreach (index, elem; checked.s3.a)
        {
            test!("==")(elem, defaultS().s3.a[index]);
        }

        foreach (index, elem; checked.s4_dynamic_array)
        {
            test!("==")(elem.a, defaultS().s4_dynamic_array[index].a);
        }

        test!("==")(checked.static_of_dynamic, defaultS().static_of_dynamic);

        test!("==")(checked.union_a, defaultS().union_b);
    }
}

/******************************************************************************

    Sanity test for helper functions

******************************************************************************/

unittest
{
    auto t = new NamedTest("Sanity");
    auto s = defaultS();
    testS(t, defaultS());
}

/******************************************************************************

    Standard workflow

******************************************************************************/

unittest
{
    auto t = new NamedTest("Basic");
    auto s = defaultS();
    void[] buffer;

    Serializer.serialize(s, buffer);
    auto cont_S = Deserializer.deserialize!(S)(buffer);
    cont_S.enforceIntegrity();
    testS(t, *cont_S.ptr);
}

/******************************************************************************

    Standard workflow, copy version

******************************************************************************/

unittest
{
    auto t = new NamedTest("Basic + Copy");
    auto s = defaultS();
    void[] buffer;

    Serializer.serialize(s, buffer);
    Contiguous!(S) destination;
    auto cont_S = Deserializer.deserialize!(S)(buffer, destination);
    cont_S.enforceIntegrity();

    t.test(cont_S.ptr is destination.ptr);
    testS(t, *cont_S.ptr);
}

/******************************************************************************

    Extra unused bytes in source

******************************************************************************/

unittest
{
    auto t = new NamedTest("Basic + Copy");
    auto s = defaultS();
    void[] buffer;

    Serializer.serialize(s, buffer);

    // emulate left-over bytes from previous deserializations
    buffer.length = buffer.length * 2;

    Contiguous!(S) destination;
    auto cont_S = Deserializer.deserialize!(S)(buffer, destination);
    cont_S.enforceIntegrity();

    t.test(cont_S.ptr is destination.ptr);
    testS(t, *cont_S.ptr);
}

/******************************************************************************

    Some arrays set to null

******************************************************************************/

unittest
{
    auto t = new NamedTest("Null Arrays");
    auto s = defaultS();
    s.s2.a = null;
    void[] buffer;

    Serializer.serialize(s, buffer);
    auto cont_S = Deserializer.deserialize!(S)(buffer);
    cont_S.enforceIntegrity();

    t.test!("==")(cont_S.ptr.s2.a.length, 0);    
    auto s_ = cont_S.ptr;      // hijack the invariant
    s_.s2.a = defaultS().s2.a; // revert the difference
    testS(t, *s_);             // check the rest
}

/******************************************************************************

    Nested arrays set to null

******************************************************************************/

unittest
{
    auto t = new NamedTest("Nested Null Arrays");
    auto s = defaultS();
    s.s2.b[0] = null;
    void[] buffer;

    Serializer.serialize(s, buffer);
    auto cont_S = Deserializer.deserialize!(S)(buffer);
    cont_S.enforceIntegrity();

    t.test!("==")(cont_S.ptr.s2.b[0].length, 0);    
    auto s_ = cont_S.ptr;            // hijack the invariant
    s_.s2.b[0] = defaultS().s2.b[0]; // revert the difference
    testS(t, *s_);                   // check the rest
}

/******************************************************************************

    Recursive definition

******************************************************************************/

unittest
{
    auto t = new NamedTest("Recursive");
    auto s = defaultS();
    s.recursive = new S[5];
    foreach (ref s_rec; s.recursive)
    {
        s_rec = defaultS();
    }
    void[] buffer;

    Serializer.serialize(s, buffer);
    Contiguous!(S) destination;
    auto cont_S = Deserializer.deserialize!(S)(buffer, destination);
    cont_S.enforceIntegrity();

    t.test(cont_S.ptr is destination.ptr);
    testS(t, *cont_S.ptr);
    t.test!("==")(cont_S.ptr.recursive.length, 5);

    foreach (s_rec; cont_S.ptr.recursive)
    {
        testS(t, s_rec);
    }
}

/******************************************************************************
    
    Recursie static arrays

******************************************************************************/

unittest
{
    auto t = new NamedTest("Recursive static");

    struct Outer
    {
        struct Inner
        {
            char[][] a;
        }

        Inner[2][1][1] a;
    }

    Outer s;
    s.a[0][0][0].a = [ "1", "2", "3" ];
    s.a[0][0][1].a = [ "1", "2" ];

    void buffer[];
    Serializer.serialize(s, buffer);
    auto cont = Deserializer.deserialize!(Outer)(buffer);

    test!("==")(cont.ptr.a[0][0][0].a, s.a[0][0][0].a);
    test!("==")(cont.ptr.a[0][0][1].a, s.a[0][0][1].a);
}
