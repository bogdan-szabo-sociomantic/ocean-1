/**
 * This file is part of the dcrypt project.
 *
 * Copyright:
 *     Copyright (C) dcrypt contributors 2009.
 *     Some parts copyright (c) 2009-2016 Sociomantic Labs GmbH.
 *     All rights reserved.
 *
 * License: Tango 3-Clause BSD License. See LICENSE_BSD.txt for details.
 *
 * Authors: Thomas Dixon
 *
 */

module ocean.util.cipher.misc.Bitwise;

/** Common bitwise operations */
struct Bitwise
{

    static uint rotateLeft(uint x, int y)
    {
        return (x << y) | (x >> (32-y));
    }

    static uint rotateLeft(uint x, uint y)
    {
        return (x << y) | (x >> (32u-y));
    }

    static ulong rotateLeft(ulong x, int y)
    {
        return (x << y) | (x >> (64-y));
    }

    static ulong rotateLeft(ulong x, uint y)
    {
        return (x << y) | (x >> (64u-y));
    }

    static uint rotateRight(uint x, int y)
    {
        return (x >> y) | (x << (32-y));
    }

    static uint rotateRight(uint x, uint y)
    {
        return (x >> y) | (x << (32u-y));
    }

    static ulong rotateRight(ulong x, int y)
    {
        return (x >> y) | (x << (64-y));
    }

    static ulong rotateRight(ulong x, uint y)
    {
        return (x >> y) | (x << (64u-y));
    }
}
