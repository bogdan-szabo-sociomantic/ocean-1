/**
 * This file is part of the dcrypt project.
 *
 * Copyright: Copyright (C) dcrypt contributors 2009. All rights reserved.
 * License:   MIT
 * Authors:   Thomas Dixon
 */

module ocean.crypt.misc.ByteConverter;

/** Converts between integral types and unsigned byte arrays */
struct ByteConverter
{
    private static char[] hexits = "0123456789abcdef";

    /** Conversions between little endian integrals and bytes */
    struct LittleEndian
    {
        /**
         * Converts the supplied array to integral type T
         *
         * Params:
         *     x_ = The supplied array of bytes (ubytes, bytes, chars, whatever)
         *
         * Returns:
         *     A integral of type T created with the supplied bytes placed
         *     in the specified byte order.
         */
        static T to(T)(void[] x_)
        {
            ubyte[] x = cast(ubyte[])x_;

            T result = ((x[0] & 0xff)       |
                       ((x[1] & 0xff) << 8));

            static if (T.sizeof >= int.sizeof)
            {
                result |= ((x[2] & 0xff) << 16) |
                          ((x[3] & 0xff) << 24);
            }

            static if (T.sizeof >= long.sizeof)
            {
                result |= (cast(T)(x[4] & 0xff) << 32) |
                          (cast(T)(x[5] & 0xff) << 40) |
                          (cast(T)(x[6] & 0xff) << 48) |
                          (cast(T)(x[7] & 0xff) << 56);
            }

            return result;
        }

        /**
         * Converts the supplied integral to an array of unsigned bytes.
         *
         * Params:
         *     input = Integral to convert to bytes
         *
         * Returns:
         *     Integral input of type T split into its respective bytes
         *     with the bytes placed in the specified byte order.
         */
        static ubyte[] from(T)(T input)
        {
            ubyte[] output = new ubyte[T.sizeof];

            output[0] = cast(ubyte)(input);
            output[1] = cast(ubyte)(input >> 8);

            static if (T.sizeof >= int.sizeof)
            {
                output[2] = cast(ubyte)(input >> 16);
                output[3] = cast(ubyte)(input >> 24);
            }

            static if (T.sizeof >= long.sizeof)
            {
                output[4] = cast(ubyte)(input >> 32);
                output[5] = cast(ubyte)(input >> 40);
                output[6] = cast(ubyte)(input >> 48);
                output[7] = cast(ubyte)(input >> 56);
            }

            return output;
        }
    }

    /** Conversions between big endian integrals and bytes */
    struct BigEndian
    {

        static T to(T)(void[] x_)
        {
            ubyte[] x = cast(ubyte[])x_;

            static if (is(T == ushort) || is(T == short))
            {
                return cast(T) (((x[0] & 0xff) << 8) |
                                 (x[1] & 0xff));
            }
            else static if (is(T == uint) || is(T == int))
            {
                return cast(T) (((x[0] & 0xff) << 24) |
                                ((x[1] & 0xff) << 16) |
                                ((x[2] & 0xff) << 8)  |
                                 (x[3] & 0xff));
            }
            else static if (is(T == ulong) || is(T == long))
            {
                return cast(T) ((cast(T)(x[0] & 0xff) << 56) |
                                (cast(T)(x[1] & 0xff) << 48) |
                                (cast(T)(x[2] & 0xff) << 40) |
                                (cast(T)(x[3] & 0xff) << 32) |
                                ((x[4] & 0xff) << 24) |
                                ((x[5] & 0xff) << 16) |
                                ((x[6] & 0xff) << 8)  |
                                 (x[7] & 0xff));
            }
        }

        static ubyte[] from(T)(T input)
        {
            ubyte[] output = new ubyte[T.sizeof];

            static if (T.sizeof == long.sizeof)
            {
                output[0] = cast(ubyte)(input >> 56);
                output[1] = cast(ubyte)(input >> 48);
                output[2] = cast(ubyte)(input >> 40);
                output[3] = cast(ubyte)(input >> 32);
                output[4] = cast(ubyte)(input >> 24);
                output[5] = cast(ubyte)(input >> 16);
                output[6] = cast(ubyte)(input >> 8);
                output[7] = cast(ubyte)(input);
            }
            else static if (T.sizeof == int.sizeof)
            {
                output[0] = cast(ubyte)(input >> 24);
                output[1] = cast(ubyte)(input >> 16);
                output[2] = cast(ubyte)(input >> 8);
                output[3] = cast(ubyte)(input);
            }
            else static if (T.sizeof == short.sizeof)
            {
                output[0] = cast(ubyte)(input >> 8);
                output[1] = cast(ubyte)(input);
            }

            return output;
        }
    }

    static char[] hexEncode(void[] input_)
    {
        ubyte[] input = cast(ubyte[])input_;
        char[] output = new char[input.length<<1];

        int i = 0;
        foreach (ubyte j; input)
        {
            output[i++] = hexits[j>>4];
            output[i++] = hexits[j&0xf];
        }

        return cast(char[])output;
    }

    /** Play nice with D2's idea of const. */
    version (D_Version2)
    {
        static char[] hexEncode(char[] input_)
        {
            return hexEncode(cast(ubyte[])input_);
        }
    }

    static ubyte[] hexDecode(char[] input)
    {
        char[] inputAsLower = stringToLower(input);
        ubyte[] output = new ubyte[input.length>>1];

        static ubyte[char] hexitIndex;
        for (int i = 0; i < hexits.length; i++)
            hexitIndex[hexits[i]] = i;

        for (int i = 0, j = 0; i < output.length; i++)
        {
            output[i] = hexitIndex[inputAsLower[j++]] << 4;
            output[i] |= hexitIndex[inputAsLower[j++]];
        }

        return output;
    }

    private static char[] stringToLower(char[] input)
    {
        char[] output = new char[input.length];

        foreach (int i, char c; input)
            output[i] = ((c >= 'A' && c <= 'Z') ? c+32 : c);

        return cast(char[])output;
    }
}
