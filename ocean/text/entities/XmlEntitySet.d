/*******************************************************************************

    copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved

    version:        July 2010: Initial release

    author:         David Eckardt, Gavin Norman

    Xml entities.

*******************************************************************************/

module ocean.text.entities.XmlEntitySet;


/*******************************************************************************

    Imports

*******************************************************************************/

private import ocean.core.Array;

private import ocean.text.entities.model.IEntitySet;



/*******************************************************************************

    Xml entity set class.

*******************************************************************************/

public class XmlEntitySet : IEntitySet
{
    /***************************************************************************

        This alias.

    ***************************************************************************/

    public alias typeof(this) This;


    /***************************************************************************

        Xml character entities

    ***************************************************************************/

    public static const Entity[] xml_entities =
    [
        {"amp",    0x0026}, // '&'
        {"quot",   0x0022}, // '"'
        {"lt",     0x003C}, // '<'
        {"gt",     0x003E}, // '>'
        {"apos",   0x0027}, // '''
    ];


    /***************************************************************************

        Returns the list of entities.

    ***************************************************************************/

    public Entity[] entities ( )
    {
        return This.xml_entities;
    }


    /***************************************************************************

        Gets the fully encoded form of an entity.

        Params:
            unicode = unicode of entity to encode

        Returns:
            the fully encoded form of the entity, or "" if the unicode value
            passed is not an encodable entity

    ***************************************************************************/

    public char[] getEncodedEntity ( dchar unicode, ref char[] output )
    {
        auto name = this.getName(unicode);
        if ( name.length )
        {
            output.concat("&", name, ";");
        }
        else
        {
            output.length = 0;
        }

        return output;
    }
}

