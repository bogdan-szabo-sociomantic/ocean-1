/******************************************************************************

    copyright:      Copyright (c) 2014 sociomantic labs. All rights reserved

    Generic Loader with a struct versioning support. Put specialized alias
    in a package with specific serializers.

*******************************************************************************/

module ocean.util.serialize.model.VersionDecoratorMixins;

/*******************************************************************************

    Imports

*******************************************************************************/

import tango.transition;

import ocean.core.Exception,
       ocean.util.container.ConcatBuffer,
       ocean.core.StructConverter;

import ocean.util.serialize.Version,
       ocean.util.serialize.model.Traits;

import tango.text.convert.Format,
       tango.stdc.string;


version (UnitTest) import ocean.core.Test;

/*******************************************************************************

    Template mixin that implements decorator.store method

    It is completely self-contained and does not expect anything from the host
    class

    Template Params:
        Serializer = serializer implementation to use

*******************************************************************************/

template StoreMethod(Serializer)
{
    /***************************************************************************

        Serializes `input` with This.Serializer and prepends version number
        before struct data in the buffer.

        Params:
            input  = struct instance to serialize
            buffer = destination buffer for serialized data

        Returns:
            full slice of `buffer`

    ***************************************************************************/

    public static void[] store(S)(S input, ref void[] buffer)
    {
        alias Version.Info!(S) VInfo;

        static assert (
            VInfo.exists,
            "Trying to use " ~ This.stringof ~ " with unversioned struct "
                ~ S.stringof
        );

        buffer.length = Serializer.countRequiredSize(input)
            + Version.Type.sizeof;
        auto unversioned = Version.inject(buffer, VInfo.number);
        Serializer.serialize!(S)(input, unversioned);

        assert(unversioned.ptr is (buffer.ptr + Version.Type.sizeof));

        return buffer;
    }
}

/*******************************************************************************

    Template mixin that implements decorator.load method

    This implementation extracts the version and calls `this.handleVersion`
    on remaining buffer which is supposed to take care of converting between
    versions.

    Template Params:
        Deserializer = deserializer implementation to use
        exception_field = host exception object that has `enforceInputLength`
            method

*******************************************************************************/

template LoadMethod (Deserializer, alias exception_field)
{
    /***************************************************************************

        Loads versioned struct from `buffer` in-place

        If deserialized struct is of different version than requested one,
        converts it iteratively, one version increment/decrement at time.

        Params:
            buffer = data previously generated by `store` method, contains both
                version data and serialized struct. Will be extended if needed
                and modified in-place, version bytes removed

        Returns:
            part of `buffer` after deserialization and version stripping, may be
            wrapped in deserializer-specific struct

    ***************************************************************************/

    public DeserializerReturnType!(Deserializer, S) load(S)(ref void[] buffer)
    {
        static assert (
            Version.Info!(S).exists,
            "Trying to use " ~ This.stringof ~ " with unversioned struct "
                ~ S.stringof
        );

        exception_field.enforceInputLength!(S)(buffer.length);

        Version.Type input_version;
        auto unversioned = Version.extract(buffer, input_version);
        // can't just do `buffer = unversioned` because it will create new
        // gc root and slowly leak memory with each load
        memmove(buffer.ptr, unversioned.ptr, unversioned.length);

        return this.handleVersion!(S)(buffer, input_version);
    }
}

/*******************************************************************************

    Template mixin that implements decorator.handleVersion method

    This implementation allows conversion only within one version increment or
    decrement and calls `this.convert` to proceed with actual struct conversion
    for two deduced types.

    Template Params:
        Deserializer = deserializer implementation to use
        exception_field = host exception object that has `throwCantConvert`
            method

*******************************************************************************/

template HandleVersionMethod(Deserializer, alias exception_field)
{
    /***************************************************************************

        Utility method to convert struct contained in input buffer to needed
        struct version. Converted struct will be stored in the same buffer
        replacing old data.

        Template Params:
            S = final struct version to get

        Params:
            buffer = input buffer after version bytes have been stripped off,
                will contain resulting struct data after this method exits
            input_version = version that was extracted from buffer

        Returns:
            deserialize() result for the last struct conversion

        Throws:
            VersionHandlingException if can't convert between provided versions

    ***************************************************************************/

    private DeserializerReturnType!(Deserializer, S) handleVersion(S)
        (ref void[] buffer, Version.Type input_version)
    body
    {
        alias Version.Info!(S) VInfo;

        if (input_version == VInfo.number)
        {
            // no conversion is necessary
            return Deserializer.deserialize!(S)(buffer);
        }

        switch (input_version)
        {
            static if (VInfo.next.exists && (VInfo.next.number == VInfo.number + 1))
            {
                // input is of higher version, need to convert down
                case VInfo.next.number:
                    return this.convert!(S, VInfo.next.type)(buffer);
            }

            static if (VInfo.prev.exists && (VInfo.prev.number == VInfo.number - 1))
            {
                // input is of lower version, need to convert up
                case VInfo.prev.number:
                    return this.convert!(S, VInfo.prev.type)(buffer);
            }

            default:
                exception_field.throwCantConvert!(S)(input_version);
        }

        assert(0);
    }
}

template ConvertMethod(Serializer, Deserializer)
{
    /***************************************************************************

        Persistent buffer reused for temporary allocations needed for struct
        conversions between different versions

    ***************************************************************************/

    private ConcatBuffer!(void) convert_buffer;

    /***************************************************************************

        Struct buffer for copy of deserialized data needed for in-place
        deserialization with conversion

    ***************************************************************************/

    private void[] struct_buffer;

    /***************************************************************************

        Helper method that takes care of actual conversion routine between
        two struct types (those are assumed to be of compatible versions)

        Uses this.convert_buffer for temporary allocations

        Template Params:
            S = needed struct type
            Source = struct type seralized into buffer

        Params:
            buffer = contains serialized Source instance, will be modified to
                store deserialized S instance instead.

    ***************************************************************************/

    private DeserializerReturnType!(Deserializer, S) convert(S, Source)
        (ref void[] buffer)
    {
        scope(exit)
        {
            this.convert_buffer.clear();
        }

        if (this.struct_buffer.length < buffer.length)
            this.struct_buffer.length = buffer.length;
        this.struct_buffer[0 .. buffer.length] = buffer[];

        auto tmp_struct = Deserializer.deserialize!(Source)(this.struct_buffer);
        S result_struct;
        structCopy!(Source, S)(
            *tmp_struct.ptr,
            result_struct,
            &this.convert_buffer.add
        );
        Serializer.serialize(result_struct, buffer);
        return Deserializer.deserialize!(S)(buffer);
    }
}

/*******************************************************************************

    Generic implementation of Loader with versioning support. It does not
    conform to `isLoader` trait because of missing `loadCopy` method (see
    ocean.util.serialize.Traits for details). "Real" implementation must
    add it too.

    Reason why `loadCopy` is not implemented here is that it requires knowledge
    of serializer specifics to be done efficiently and in a DRY manner as it
    can have a destination argument type of arbitrary type.

    This class serves exclusively as example of usage of mixins defines in this
    module. It is not intended to be used or derived from.

    Template Params:
        Srlz  = Serializer to use
        Dsrlz = Deserializer to use

*******************************************************************************/

private class VersionDecoratorExample(Srlz, Dsrlz)
{
    /***************************************************************************

        Convenience shortcut

    ***************************************************************************/

    public alias VersionDecoratorExample This;

    /***************************************************************************

        Aliases for used Serializer / Deserializer implementations as demanded
        by `isLoader` trait.

    ***************************************************************************/

    public alias Srlz  Serializer;

    /***************************************************************************

        ditto

    ***************************************************************************/

    public alias Dsrlz Deserializer;

    /***************************************************************************

        Reused exception instance

    ***************************************************************************/

    protected VersionHandlingException e;

    /***************************************************************************

        Constructor

        Params:
            buffer_size = starting this of convert_buffer, does not really
                matter much in practice because it will quickly grow to the
                maximum required size and stay there

    ***************************************************************************/

    public this (size_t buffer_size = 512)
    {
        this.e = new VersionHandlingException;
        this.convert_buffer = new ConcatBuffer!(void)(buffer_size);
    }

    mixin StoreMethod!(Serializer);
    mixin LoadMethod!(Deserializer, This.e);
    mixin HandleVersionMethod!(Deserializer, This.e);
    mixin ConvertMethod!(Serializer, Deserializer);
}

/***************************************************************************

    Can't declare these structs inside unittest block because of templated
    methods.

***************************************************************************/

version(UnitTest)
{
    struct DummyDeserializer
    {
        static void[] deserialize(S)(void[] buffer)
        {
            return null;
        }

        static void[] deserialize(S)(void[] buffer, void[] copy_buffer)
        {
            return null;
        }

        static size_t countRequiredSize(S)(void[] buffer)
        {
            return 0;
        }
    }

    struct DummySerializer
    {
        static void[] serialize(S)(S input, ref void[] buffer)
        {
            return buffer;
        }

        static size_t countRequiredSize(S)(S input)
        {
            return 0;
        }
    }
}

unittest
{
    // simply check that instantiation compiles
    // more meaningful tests belong to modules with decorators specialized
    // for certain (de)serializer

    auto decorator = new VersionDecoratorExample!(DummySerializer, DummyDeserializer);

    try
    {
        struct Test { const StructVersion = 1; }
        void[] buffer;
        decorator.load!(Test)(buffer);
    }
    catch (Exception) { }
}

/***************************************************************************

    Exception thrown when the loaded encounters any issues with version
    support

***************************************************************************/

class VersionHandlingException : Exception
{
    /***************************************************************************

        No-op constructor, all actual data gets set up by throwing methods

    ***************************************************************************/

    this()
    {
        super(null);
    }

    /***************************************************************************

        Used to enforce that input is large enough to store version
        bytes and some offset.

        Params:
            input_length = size of input buffer
            file = inferred
            line = inferred

        Template Params:
            S = struct type that was attempted to be loaded

    ***************************************************************************/

    void enforceInputLength(S)(size_t input_length,
        istring file = __FILE__, int line = __LINE__)
    {
        if (input_length <= Version.Type.sizeof)
        {
            this.msg = Format(
                "Loading {} has failed, input buffer too short " ~
                    "(length {}, need {})",
                S.stringof,
                input_length,
                Version.Type.sizeof
            );
            this.line = line;
            this.file = file;

            throw this;
        }
    }

    /***************************************************************************

        Used in case of version mismatch between requested struct and incoming
        buffer

        Params:
            input_version = version found in input buffer
            file = inferred
            line = inferred

        Template Params:
            S = struct type that was attempted to be loaded

    ***************************************************************************/

    void throwCantConvert(S)(Version.Type input_version, istring file = __FILE__,
        int line = __LINE__)
    {
        this.msg = Format(
            "Got version {} for struct {}, expected {}. Can't convert between these",
            input_version,
            S.stringof,
            Version.Info!(S).number
        );
        this.line = line;
        this.file = file;

        throw this;
    }
}
