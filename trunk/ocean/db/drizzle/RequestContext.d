/*******************************************************************************

    Structure holding the user-specified context for a dht request. The
    specified request context is passed back to the calling code when the i/o
    delegate is called.

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    version:        January 2011: Initial release

    authors:        Gavin Norman

    Note: This module was written as a custom struct rather than using UniStruct
    for the sake of the simplicity of the end-user interface.

    For example, compare the UniStruct usage:
    
        context.get!(RequestContext.TypeId.Uint)

    with the interface this module provides:

        context.integer

*******************************************************************************/

module ocean.db.drizzle.RequestContext;



/*******************************************************************************

    Request context.

*******************************************************************************/

public struct RequestContext
{
    /***************************************************************************

        Union holding the three possible types of request context.
    
    ***************************************************************************/

    private union Context
    {
        hash_t  integer;
        Object  object;
        void*   pointer;
    }
    
    private Context context;


    /***************************************************************************

        Enum defining the states of this struct: the three possible types of 
        request context, plus the uninitialised state.

    ***************************************************************************/

    private enum SetType
    {
        None,
        Integer,
        Object,
        Pointer
    }

    private SetType set_type;

    
    /***************************************************************************

        Stores an integer.
    
    ***************************************************************************/

    public void set ( uint i )
    {
        this.context.integer = i;
        this.set_type = SetType.Integer;
    }


    /***************************************************************************

        Stores an object reference.
    
    ***************************************************************************/

    public void set ( Object o )
    {
        this.context.object = o;
        this.set_type = SetType.Object;
    }


    /***************************************************************************

        Stores a pointer.
    
    ***************************************************************************/

    public void set ( void* p )
    {
        this.context.pointer = p;
        this.set_type = SetType.Pointer;
    }


    /***************************************************************************

        Gets a previously set integer.
    
    ***************************************************************************/

    public uint integer ( )
    in
    {
        assert(this.set_type == SetType.Integer, typeof(this).stringof ~ ".integer - integer value not set");
    }
    body
    {
        return this.context.integer;
    }


    /***************************************************************************

        Gets a previously set  hash (integer).
        (Just provided for calling convenience.)
    
    ***************************************************************************/

    public hash_t hash ( )
    {
        return this.integer();
    }
    

    /***************************************************************************

        Gets a previously set object reference.
    
    ***************************************************************************/

    public Object object ( )
    in
    {
        assert(this.set_type == SetType.Object, typeof(this).stringof ~ ".object - object value not set");
    }
    body
    {
        return this.context.object;
    }


    /***************************************************************************

        Gets a previously set pointer.
    
    ***************************************************************************/

    public void* pointer ( )
    in
    {
        assert(this.set_type == SetType.Pointer, typeof(this).stringof ~ ".pointer - pointer value not set");
    }
    body
    {
        return this.context.pointer;
    }


    /***************************************************************************

        Tells if a value has been set.
    
    ***************************************************************************/

    public bool isSet ( )
    {
        return this.set_type != SetType.None;
    }


    /***************************************************************************

        Tells if an integer has been set.
    
    ***************************************************************************/

    public bool isInteger ( )
    {
        return this.set_type == SetType.Integer;
    }

    /***************************************************************************

        Tells if an object reference has been set.
    
    ***************************************************************************/

    public bool isObject ( )
    {
        return this.set_type == SetType.Object;
    }


    /***************************************************************************

        Tells if a pointer has been set.
    
    ***************************************************************************/

    public bool isPointer ( )
    {
        return this.set_type == SetType.Pointer;
    }


    /***************************************************************************

        Static opCall method to create an uninitialised request context.
    
    ***************************************************************************/

    static public typeof(*this) opCall ( )
    {
        typeof(*this) rc;
        return rc;
    }


    /***************************************************************************

        Static opCall method to create a request context storing an integer.
    
    ***************************************************************************/

    static public typeof(*this) opCall ( uint i )
    {
        typeof(*this) rc;
        rc.set(i);
        return rc;
    }


    /***************************************************************************

        Static opCall method to create a request context storing an object
        reference.
    
    ***************************************************************************/

    static public typeof(*this) opCall ( Object o )
    {
        typeof(*this) rc;
        rc.set(o);
        return rc;
    }


    /***************************************************************************

        Static opCall method to create a request context storing a pointer.
    
    ***************************************************************************/

    static public typeof(*this) opCall ( void* p )
    {
        typeof(*this) rc;
        rc.set(p);
        return rc;
    }
}

