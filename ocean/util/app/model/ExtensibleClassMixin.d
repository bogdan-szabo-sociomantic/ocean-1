/*******************************************************************************

    Mixin for classes that support extensions.

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    authors:        Leandro Lucarella

*******************************************************************************/

module ocean.util.app.model.ExtensibleClassMixin;



/*******************************************************************************

    Imports

*******************************************************************************/

// TODO: private import ocean.util.app.model.IExtension;

private import tango.core.Array : sort;


/*******************************************************************************

    Mixin for classes that support extensions.

    It just provides a simple container for extensions (ordered in the order
    provided by BaseExtension.order()) registering of extensions, and getting an
    extension based on its type.

    Typical usage:

    ---

    interface ISomeExtension : IExtension
    {
        void someMethod ( );
    }

    class SomeExtensibleClass
    {
        mixin ExtensibleClassMixin!(ISomeExtension);

        void something ( )
        {
            foreach (ext; this.extensions)
            {
                ext.someMethod();
            }
        }
    }

    ---

    TODO: Assert that ExtensionClass is derived from IExtension

*******************************************************************************/

template ExtensibleClassMixin ( ExtensionClass )
{

    /***************************************************************************

        List of extensions. Will be kept sorted by extension order when using
        the registerExtension() method.

    ***************************************************************************/

    ExtensionClass[] extensions;


    /***************************************************************************

        Register a new extension, keeping extensions list sorted.

        Extensions are considered unique by type, so is invalid to register
        2 extensions with the exact same type.

        Params:
            ext = new extension to register

    ***************************************************************************/

    public void registerExtension ( ExtensionClass ext )
    {
        // TODO: Assert that we don't already have an extension of the same type

        this.extensions ~= ext;
        sort(this.extensions,
            ( ExtensionClass e1, ExtensionClass e2 )
            {
                return e1.order < e2.order;
            });
    }


    /***************************************************************************

        Get an extension based on its type.

        Returns:
            the instance of the extension of the type Ext, or null if not found

    ***************************************************************************/

    public Ext getExtension ( Ext ) ( )
    {
        // TODO: Assert that Ext is derived from ExtensionClass
        foreach (e; this.extensions)
        {
            Ext ext = cast(Ext) e;
            if ( ext !is null )
            {
                return ext;
            }
        }

        return null;
    }

}

