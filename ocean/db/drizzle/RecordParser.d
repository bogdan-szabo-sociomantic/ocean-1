/*******************************************************************************

    Template, to be used in conjunction with a drizzle Row instance, which
    automatically fills in the members of a record struct from the fields of a
    query row.

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    version:        June 2011: Initial release

    authors:        Gavin Norman

    Automatically reads the fields of a Result.Row and fills in the members of a
    struct. The fields are parsed according to the type of the equivalent struct
    member.

    Note that the struct members are read according to their *order*, so the 
    order of members in the struct must match the order of fields in the query
    result. The name of the struct members is irrelevant, though it's usually
    helpful if they match the names of the query result's fields.

    Basic usage example:

    ---

        struct Record
        {
            hash_t id;
            time_t update_time;
            char[] name;
        }

        void query_callback ( ContextUnion context, Result result )
        {
            foreach ( row; result )
            {
                scope parser = new RecordParser!(Record);
                Record record;

                parser.parseRow(record, row);
                
                // record will now be filled
            }
        }

        drizzle.query("SELECT id, update_time, name FROM a_table", &query_callback);

    ---

    RecordParser classes are also designed so that the methods which parse the
    individual struct members may be overridden, enabling special parsing
    behaviour if needed.

    Advanced usage example:

    ---

        struct Record
        {
            hash_t id;
            time_t update_time;
            char[] name;
        }

        class MyRecordParser : RecordParser!(Record)
        {
            // Override the basic string -> integer behaviour for the id member,
            // hashing the string instead.
            override void id ( ref Record record, char[] field )
            {
                record.id = Fnv1a(field);
            }
        }

        void query_callback ( ContextUnion context, Result result )
        {
            foreach ( row; result )
            {
                scope parser = new RecordParser!(Record);
                Record record;

                parser.parseRow(record, row);
                
                // record will now be filled
            }
        }

        drizzle.query("SELECT id, update_time, name FROM a_table", &query_callback);

    ---

*******************************************************************************/

module ocean.db.drizzle.RecordParser;



/*******************************************************************************

    Imports

*******************************************************************************/

private import ocean.db.drizzle.Result;

private import ocean.core.Array;
private import ocean.core.Traits;

private import tango.core.Traits;

private import Integer = tango.text.convert.Integer;
private import Float = tango.text.convert.Float;



/*******************************************************************************

    RecordParser class template.

    Template params:
        R = type of record struct

*******************************************************************************/

public scope class RecordParser ( R )
{
    /***************************************************************************

        This alias.

    ***************************************************************************/

    private alias typeof(this) This;


    /***************************************************************************

        Assert that the template parameter R is a struct.

    ***************************************************************************/

    static assert(is(R == struct), This.stringof ~ "!(" ~ R.stringof ~ "): " ~ R.stringof ~ " is not a struct");


    /***************************************************************************

        Constant defining the number of fields in the template struct.

    ***************************************************************************/

    private const NumFields = R.tupleof.length;


    /***************************************************************************

        List of setter delegates. This list is initialised in the constructor
        to contain an in-order list of the protected setter methods which are
        mixed in with the Setters template. Thus the setter methods can be
        called over the fields of a result row, in order of the record struct's
        members.

    ***************************************************************************/

    private alias void delegate ( ref R record, char[] val ) SetterDg;

    private SetterDg[NumFields] setters;


    /***************************************************************************

        String mixin template which expands to the code for a method to set one
        of the record struct's members from a string.

        Template params:
            R = type of record struct
            T = type of field
            field_index = index of field in record struct

    ***************************************************************************/

    private template SetMethod ( R, T, size_t field_index ) // R = struct type, T = type of field
    {
        const SetMethod =
            "protected void " ~ FieldName!(field_index, R) ~ "(ref R record, char[] val)"
            "{"
            "setField(&record." ~  FieldName!(field_index, R) ~ ", val);"
            "}";
    }


    /***************************************************************************

        String mixin template which expands to the code for the setter methods
        for all the record struct's members.

        Template params:
            field_index = index of field in record struct
            R = type of record struct
            T = record struct fields type tuple

    ***************************************************************************/

    private template SetterMethods ( size_t field_index, R, T ... )
    {
        static if ( T.length == 1 )
        {
            const SetterMethods = SetMethod!(R, T[0], field_index);
        }
        else
        {
            const SetterMethods = SetMethod!(R, T[0], field_index) ~ SetterMethods!(field_index + 1, R, T[1..$]);
        }
    }

//    pragma(msg, "SetterMethods: " ~ SetterMethods!(0, R, typeof(R.tupleof)));
    mixin(SetterMethods!(0, R, typeof(R.tupleof)));


    /***************************************************************************

        String mixin template which expands to the code to set one of the setter
        methods in the list of setters.

        Template params:
            R = type of record struct
            T = type of field
            field_index = index of field in record struct

    ***************************************************************************/

    private template SetSetter ( R, T, size_t field_index )
    {
        const SetSetter = "this.setters[" ~ ctfe_i2a(field_index) ~ "]=&this." ~ FieldName!(field_index, R) ~ ";";
    }


    /***************************************************************************

        String mixin template which expands to the code to set all of the setter
        methods in the list of setters.

        Template params:
            field_index = index of field in record struct
            R = type of record struct
            T = record struct fields type tuple

    ***************************************************************************/

    private template SetSetters ( size_t field_index, R, T ... )
    {
        static if ( T.length == 1 )
        {
            const SetSetters = SetSetter!(R, T[0], field_index);
        }
        else
        {
            const SetSetters = SetSetter!(R, T[0], field_index) ~ SetSetters!(field_index + 1, R, T[1..$]);
        }
    }


    /***************************************************************************

        String mixin template which expands to the code to append the comma
        seperated names of the record struct fields into a string. The template
        assumes that the following variables exist in the context in which it is
        mixed in:
            output = output string
            prepend = list of strings to be prepended to the member names

        Template params:
            field_index = index of field in record struct
            R = type of record struct
            T = record struct fields type tuple

    ***************************************************************************/

    private template AppendFieldNames ( size_t field_index, R, T ... )
    {
        static if ( T.length == 1 )
        {
            const AppendFieldNames = "output.append(prepend[" ~ ctfe_i2a(field_index) ~ `], "` ~ FieldName!(field_index, R) ~ `");`;
        }
        else
        {
            const AppendFieldNames = "output.append(prepend[" ~ ctfe_i2a(field_index) ~ `], "` ~ FieldName!(field_index, R) ~ `", ", ");`
            ~ AppendFieldNames!(field_index + 1, R, T[1..$]);
        }
    }


    /***************************************************************************

        Constructor. Sets all of the setter methods in the list of setters.

    ***************************************************************************/

    public this ( )
    {
//    pragma(msg, "SetSetters: " ~ SetSetters!(0, R, typeof(R.tupleof)));
        mixin(SetSetters!(0, R, typeof(R.tupleof)));
    }


    /***************************************************************************

        Reads fields from a result row and fills in the members of a struct with
        the parsed values.

        Params:
            record = record struct to fill in
            row = query result row to read fields from

        Throws:
            can throw an out of bounds exception if the result row has more
            fields than the record struct is expecting. In this case you need to
            synchronize your drizzle query with your struct!

    ***************************************************************************/

    public void parseRow ( ref R record, ref Result.Row row )
    {
        foreach ( i, field; row )
        {
            this.setters[i](record, field);
        }
    }


    /***************************************************************************

        Formats the provided string buffer with a comma seperated list of the
        members of the record struct.

        Params:
            output = output string

    ***************************************************************************/

    public void formatFieldNames ( ref char[] output )
    {
        char[][NumFields] prepend;
        this.formatFieldNames(output, prepend);
    }


    /***************************************************************************

        Formats the provided string buffer with a comma seperated list of the
        members of the record struct. Each member name is additionally prepended
        with the provided string.

        This is useful with MySql SELECT commands for specifying which table the
        fields come from (see usage example below).

        Params:
            output = output string
            prepend = string to be prepended to the member names

        Usage example:

            struct Test
            {
                int member1;
                float member2;
            }

            scope parser = new RecordParser!(Test);
            
            char[] output;
            parser.formatFieldNames(output, "a.");

            // output now contains the string:
            // "a.member1, a.member2"

    ***************************************************************************/

    public void formatFieldNames ( ref char[] output, char[] prepend )
    {
        char[][NumFields] prependers;
        foreach ( ref p; prependers )
        {
            p = prepend;
        }

        this.formatFieldNames(output, prependers);
    }


    /***************************************************************************

        Formats the provided string buffer with a comma seperated list of the
        members of the record struct. Each member name is additionally prepended
        with the corresponding sting from the provided list of prependers.

        This is useful for making parameter lists to MySql SELECT commands over
        multiple tables (see usage example below).

        Params:
            output = output string
            prepend = list of strings to be prepended to the member names

        Usage example:

            struct Test
            {
                int member1;
                float member2;
            }

            scope parser = new RecordParser!(Test);
            
            char[] output;
            parser.formatFieldNames(output, ["a.", "b."]);

            // output now contains the string:
            // "a.member1, b.member2"

    ***************************************************************************/

    public void formatFieldNames ( ref char[] output, char[][NumFields] prepend )
    {
//        pragma(msg, AppendFieldNames!(0, R, typeof(R.tupleof)));

        output.length = 0;
        mixin(AppendFieldNames!(0, R, typeof(R.tupleof)));
    }


    /***************************************************************************

        Parses a field from a result row and fills in a member of a record
        struct.

        Template params:
            T = type of struct member being set

        Params:
            field = pointer to the struct member being set
            value = field from result row to parse

    ***************************************************************************/

    static private void setField ( T ) ( T* field, char[] value )
    {
        static assert(!isCompoundType!(T),
                This.stringof ~ "!(" ~ R.stringof ~ "): Recursion into compound member of type " ~ T.stringof ~ " not supported");

        static if ( is ( T : char[] ) )
        {
            (*field).copy(value);
        }
        else static if ( is ( T V == enum ) )
        {
            (*field) = cast(T)Integer.toLong(value);
        }
        else static if ( is(T == bool) )
        {
            (*field) = !(value == "0" || value == "false");
        }
        else static if ( isIntegerType!(T) )
        {
            (*field) = Integer.toLong(value);
        }
        else static if ( isRealType!(T) )
        {
            (*field) = Float.toFloat(value);
        }
        else static if ( is(T == typedef) && is(T : double) && !is( T : int))
        {
            (*field) = Float.toFloat(value);
        }
        else static if ( is(T == typedef) && is( T : int))
        {
            (*field) = cast(T)(Integer.toLong(value));
        }
        else
        {
            static assert(false, This.stringof ~ "!(" ~ R.stringof ~ "): Unhandled type: " ~ T.stringof);
        }
    }
}

