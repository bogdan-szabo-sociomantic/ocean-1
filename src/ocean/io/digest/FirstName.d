module ocean.io.digest.FirstName;

import ocean.io.digest.Fnv1;


static class FirstName
{
    static private char[][] names =
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

    static char[] opCall ( T ) ( T value )
    {
        return names[Fnv1a64(value) % names.length];
    }
}

