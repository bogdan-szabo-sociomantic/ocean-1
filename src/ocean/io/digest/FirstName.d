/******************************************************************************

    Map numbers to easier distinguishable names

    copyright: Copyright (c) 2014 sociomantic labs. All rights reserved

    author:    Mathias L. Baumann

*******************************************************************************/

module ocean.io.digest.FirstName;


/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.io.digest.Fnv1;


/*******************************************************************************

    Class to provide number -> name translation

    This class is useful for when you want to display a lot of numbers that
    don't have an immediate meaning for a person (pointers, hashes, etc) but
    where it still is helpful or important to easily see whether a number is
    different from the other.

    Usage Example:
    ---

    import ocean.io.digest.FirstName;

    MyClass myArray[] = ... ;


    foreach ( c; myArray )
    {
        Stdout.formatln("{}.property = {}", FirstName(cast(void*) c, c.property);
    }
    ---

*******************************************************************************/

static class FirstName
{
    /***************************************************************************

        Static list of strings (preferably names) that a number can be mapped to

    ***************************************************************************/

    static private istring[] names =
            ["Sarah",
            "David",
            "Gavin",
            "Mathias",
            "Hans",
            "Ben",
            "Tom",
            "Hatem",
            "Donald",
            "Luca",
            "Lautaro",
            "Anja",
            "Marine",
            "Coco",
            "Robert",
            "Federico",
            "Lars",
            "Julia",
            "Sanne",
            "Aylin",
            "Tomsen",
            "Dylan",
            "Margit",
            "Daniel",
            "Diana",
            "Jessica",
            "Francisco",
            "Josh",
            "Karin",
            "Anke",
            "Linus",
            "BillGates",
            "Superman",
            "Batman",
            "Joker",
            "Katniss",
            "Spiderman",
            "Storm",
            "Walter",
            "Fawfzi"];

    /***************************************************************************

        Function to map an abitrary integer to a string for easier distinction

        Template Params:
            T = integer type, should be Fnv1a compatible

        Params:
            value = an integer value to map

        Returns:
            a string matching the hash of the given number

    ***************************************************************************/

    static istring opCall ( T ) ( T value )
    {
        return names[Fnv1a64(value) % names.length];
    }
}

