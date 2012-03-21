/*******************************************************************************

    copyright:      Copyright (c) 2012 sociomantic labs. All rights reserved

    version:        09/03/2012: Initial release

    authors:        Gavin Norman

    TODO: description of module

*******************************************************************************/

module ocean.core.StructIterator;



/*******************************************************************************

    Imports

*******************************************************************************/

private import ocean.core.Traits;



public template StructIterator2 ( T )
{
    /***************************************************************************

        Constant defining the number of fields in the template struct.

    ***************************************************************************/

    private const NumFields = T.tupleof.length;

    private T* inst;


    // Methods named after each member of T, call the appropriate visitor for the field's type
    private template FieldMethod ( size_t field_index )
    {
        const char[] FieldMethod = "protected void " ~ FieldName!(field_index, T)
            ~ "(ref " ~ FieldType!(T, field_index).stringof ~ " v){this.visitor("
            ~ FieldName!(field_index, T).stringof ~ ", v);}";
    }

    private template FieldMethods ( size_t field_index )
    {
        static if ( field_index == NumFields - 1 )
        {
            const char[] FieldMethods = FieldMethod!(field_index);
        }
        else
        {
            const char[] FieldMethods = FieldMethod!(field_index) ~ FieldMethods!(field_index + 1);
        }
    }

    pragma(msg, FieldMethods!(0));
    mixin(FieldMethods!(0));

    private template CallMethod ( size_t field_index )
    {
        const char[] CallMethod = FieldName!(field_index, T)
            ~ "(this.inst." ~ FieldName!(field_index, T) ~ ");";
    }

    private template CallMethods ( size_t field_index )
    {
        static if ( field_index == NumFields - 1 )
        {
            const char[] CallMethods = CallMethod!(field_index);
        }
        else
        {
            const char[] CallMethods = CallMethod!(field_index)
                ~ CallMethods!(field_index + 1);
        }
    }

    public void opCall ( T inst )
    {
        this.inst = &inst;

        mixin(CallMethods!(0));
    }
}



/+
// can safely be instantiated as scope
public class StructIterator ( T, V )
{
    /***************************************************************************

        Constant defining the number of fields in the template struct.

    ***************************************************************************/

    private const NumFields = T.tupleof.length;

    private T* inst;

    private V visitor;


    // Methods named after each member of T, call the appropriate visitor for the field's type
    private template FieldMethod ( size_t field_index )
    {
        const char[] FieldMethod = "protected void " ~ FieldName!(field_index, T)
            ~ "(ref " ~ FieldType!(T, field_index).stringof ~ " v){this.visitor("
            ~ FieldName!(field_index, T).stringof ~ ", v);}";
    }

    private template FieldMethods ( size_t field_index )
    {
        static if ( field_index == NumFields - 1 )
        {
            const char[] FieldMethods = FieldMethod!(field_index);
        }
        else
        {
            const char[] FieldMethods = FieldMethod!(field_index) ~ FieldMethods!(field_index + 1);
        }
    }

    pragma(msg, FieldMethods!(0));
    mixin(FieldMethods!(0));

    private template CallMethod ( size_t field_index )
    {
        const char[] CallMethod = FieldName!(field_index, T)
            ~ "(this.inst." ~ FieldName!(field_index, T) ~ ");";
    }

    private template CallMethods ( size_t field_index )
    {
        static if ( field_index == NumFields - 1 )
        {
            const char[] CallMethods = CallMethod!(field_index);
        }
        else
        {
            const char[] CallMethods = CallMethod!(field_index)
                ~ CallMethods!(field_index + 1);
        }
    }

    public void opCall ( T inst, V visitor )
    {
        this.inst = &inst;
        this.visitor = visitor; // TODO: probably not necessary to store the ref to the visitor, just use it in context, the same as "inst"

//        this.visitor.begin();
        mixin(CallMethods!(0));
//        this.visitor.end();
    }
}
+/
