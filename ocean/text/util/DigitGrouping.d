/*******************************************************************************

    Functions for generating thousands separated string representations of a
    number.

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    version:        April 2011: Initial release

    authors:        Gavin Norman

    Usage:
    
    ---
    
        import ocean.text.util.DigitGrouping;

        // Number to convert
        const number = 12345678;

        // Generating a thousands separated string.
        char[] number_as_string;
        DigitGrouping.format(number, number_as_string);

        // Checking how many characters would be required for a thousands
        // separated number.
        cont max_len = 10;
        assert(DigitGrouping.length(number) <= max_len);

    ---

*******************************************************************************/

module ocean.text.util.DigitGrouping;



/*******************************************************************************

    Imports

*******************************************************************************/

private import ocean.core.Array;

private import ocean.text.util.MetricPrefix;

private import Ocean = ocean.text.convert.Layout;

private import tango.text.convert.Layout;

private import tango.core.Traits;

debug private import tango.util.log.Trace;



/*******************************************************************************

    Digit grouping class -- just a container for static functions.

*******************************************************************************/

public class DigitGrouping
{
    private alias typeof(this) This;


    /***************************************************************************

        Calculates the number of characters in the string representation of a
        thousands separated number.

        Note: this method is faster than generating the string then checking its
        .length property.

        Template params:
            T = type of number

        Params:
            num = number to work out length of

        Returns:
            number of characters in the string representation of the thousands
            separated number

    ***************************************************************************/

    public static size_t length ( T ) ( T num )
    {
        static assert(isIntegerType!(T), This.stringof ~ ".length - only works with integer types");

        bool negative = num < 0;
        if ( negative ) num = -num;

        // Calculate the number of digits in the number.
        size_t len = 1; // every number has at least 1 digit
        do
        {
            num /= 10;
            if ( num > 0 )
            {
                len++;
            }
        }
        while ( num > 0);

        // Extra characters for any thousands separating commas required.
        if ( len > 3 )
        {
            len += (len - 1) / 3;
        }

        // An extra character for a minus sign.
        if ( negative ) len++;

        return len;
    }


    /***************************************************************************

        Formats a number to a string, with comma separation every 3 digits

        Template params:
            T = type of number

        Params:
            num = number to work out length of
            output = string to format number into

        Returns:
            formatted string

    ***************************************************************************/

    public static char[] format ( T ) ( T num, ref char[] output )
    {
        static assert(isIntegerType!(T), This.stringof ~ ".format - only works with integer types");

        output.length = 0;

        char[20] string_buf; // 20 characters is enough to store ulong.max
        size_t layout_pos;

        size_t layoutSink ( char[] s )
        {
            string_buf[layout_pos .. layout_pos + s.length] = s[];
            layout_pos += s.length;
            return s.length;
        }

        // Format number into a string
        Layout!(char).instance().convert(&layoutSink, "{}", num);
        char[] num_as_string = string_buf[0.. layout_pos];

        bool comma;
        size_t left = 0;
        size_t right = left + 3;
        size_t first_comma;

        // Handle negative numbers
        if ( num_as_string[0] == '-' )
        {
            output.append("-");
            num_as_string = num_as_string[1..$];
        }

        // Find position of first comma
        if ( num_as_string.length > 3 )
        {
            comma = true;
            first_comma = num_as_string.length % 3;

            if ( first_comma > 0 )
            {
                right = first_comma;
            }
        }

        // Copy chunks of the formatted number into the destination string, with commas
        do
        {
            if ( right >= num_as_string.length )
            {
                right = num_as_string.length;
                comma = false;
            }
            
            char[] digits = num_as_string[left..right];
            if ( comma )
            {
                output.append(digits, ",");
            }
            else
            {
                output.append(digits);
            }

            left = right;
            right = left + 3;
        }
        while( left < num_as_string.length );

        return output;
    }
}



/*******************************************************************************

    Binary digit grouping class -- just a container for static functions.

*******************************************************************************/

public class BitGrouping
{
    /***************************************************************************

        Formats a number to a string, with binary prefix (K, M, T, etc) every
        10 bits.

        Params:
            num = number to work out length of
            output = string to format number into
            unit = string, describing the type of unit represented by the
                number, to be appended after each binary prefix

        Returns:
            formatted string

    ***************************************************************************/

    public static char[] format ( ulong num, ref char[] output, char[] unit = null )
    {
        output.length = 0;

        if ( num == 0 )
        {
            Ocean.Layout!(char).print(output, "0{}", unit);
        }
        else
        {
            void format ( char prefix, uint order, ulong order_val )
            {
                if ( order_val > 0 )
                {
                    if ( order == 0 )
                    {
                        Ocean.Layout!(char).print(output, "{}{}", order_val, unit);
                    }
                    else
                    {
                        Ocean.Layout!(char).print(output, "{}{}{} ", order_val, prefix, unit);
                    }
                }
            }
    
            splitBinaryPrefix(num, &format);
        }

        return output;
    }
}

