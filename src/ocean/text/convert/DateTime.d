/*******************************************************************************

    copyright:      Copyright (c) 2013 sociomantic labs. All rights reserved

    version:        9/3/2013: Initial release

    authors:        Ben Palmer

    Module provides a method to convert from a date time formatted as a string
    to a UNIX timestamp value.

*******************************************************************************/

module ocean.text.convert.DateTime;



/*******************************************************************************

    Imports

*******************************************************************************/

import tango.transition;

import tango.stdc.stdio : sscanf;

import tango.stdc.posix.sys.stat;

import tango.stdc.posix.time;

import tango.text.Unicode;

import tango.text.convert.Format;

import tango.core.Array : contains;

import tango.time.chrono.Gregorian;



/*******************************************************************************

    Type of date conversion that has been applied

*******************************************************************************/

public enum DateConversion : uint
{
    None,
    DateTime,               // 2010-08-14 17:29:06
    DateTimeT,              // 2010-08-14T17:29:06
    YearMonthDay,           // 20100814
    YearMonthDayWithHyphen, // 2010-08-14
    YearMonth,              // 201008
    YearMonthWithHyphen     // 2010-08
}


/*******************************************************************************

    Given a timestamp, if it is in one of a set of allowable formats, return
    the equivalent unix timestamp. Allowable formats are 2010-08-14 17:29:06,
    2010-08-14T17:29:06, 2010-08, 2010-08-14, 201008, or 20100814. These
    formats are some of the formats supported by ISO 8601 but not all of them.

    This method makes use of the C sscanf() function. To use sscanf safely,
    str needs to be null-terminated. Fortunately the format is clearly defined,
    so we can copy it into a fixed-length buffer.

    Params:
        str = string contain timestamp
        time = a time_t that is filled with the result of the conversion
        conversion_type = if the timestamp was converted from an allowable
                    format set what type of conversion was used

    Returns:
        true if the timestamp has been successfully converted

*******************************************************************************/

public bool timeToUnixTime ( cstring str, ref time_t time,
    out DateConversion conversion_type )
{
    tm datetime;
    char separator;
    char [("2000-12-12T23:59:59:59Z".length+1)] buff;

    auto len = str.length;
    if ( str.length > buff.length - 1 )
        len = buff.length - 1;

    buff[0..len] = str[0..len];
    buff[len+1] = '\0';

    // Initialise the time and the day of the month to 0 and 1 respectively
    datetime.tm_hour = datetime.tm_min = datetime.tm_sec = 0;
    datetime.tm_mday = 1;

    // try the date format with 2010-08-14T17:29:06 or 2010-08-14 17:29:06
    int num_matched = sscanf(buff.ptr, "%d-%d-%d%c%d:%d:%d".ptr, &datetime.tm_year,
        &datetime.tm_mon, &datetime.tm_mday, &separator, &datetime.tm_hour,
        &datetime.tm_min, &datetime.tm_sec);

    Converted: switch ( num_matched )
    {
        case 1:
            if ( validCharacters(str, "") )
            {
                switch ( str.length )
                {
                    case 6: // 201008
                        sscanf(buff.ptr, "%04d%02d".ptr, &datetime.tm_year,
                            &datetime.tm_mon);
                        conversion_type = DateConversion.YearMonth;
                        break Converted;

                    case 8: // 20100814
                        sscanf(buff.ptr, "%04d%02d%02d".ptr, &datetime.tm_year,
                            &datetime.tm_mon, &datetime.tm_mday);
                        conversion_type = DateConversion.YearMonthDay;
                        break Converted;

                    default:
                        return false;
                }
            }
            return false;

        case 2:
            if ( validCharacters(str, "-") ) // 2010-08
            {
                conversion_type = DateConversion.YearMonthWithHyphen;
                break;
            }
            return false;

        case 4: // 2013-10-01 matches 4 items and the character matched is 255
            if ( validCharacters(str, "-") && separator == 255 )
            {
                conversion_type = DateConversion.YearMonthDayWithHyphen;
                break;
            }
            return false;

        case 7:
            switch ( separator )
            {
                case 'T': // 2010-08-14T17:29:06
                    conversion_type = DateConversion.DateTimeT;
                    break Converted;

                case ' ': // 2010-08-14 17:29:06
                    conversion_type = DateConversion.DateTime;
                    break Converted;

                default:
                    return false;
            }
            assert(false);

        default:
            return false;
    }

    if ( !validDate(datetime.tm_mday, datetime.tm_mon, datetime.tm_year) )
    {
        return false;
    }

    if ( !validTime(datetime.tm_hour, datetime.tm_min, datetime.tm_sec) )
    {
        return false;
    }

    datetime.tm_year -= 1900;
    datetime.tm_mon--;
    datetime.tm_isdst = false;

    time = timegm(&datetime);

    return true;
}


/*******************************************************************************

    Check for valid characters in the date string. Valid characters are digits
    and any characters in the extra paramter.

    Params:
        str = string to check for valid characters
        extra = string containing characters other than digits that are valid

    Returns:
        true if the string only contains valid characters

*******************************************************************************/

private bool validCharacters ( cstring str, cstring extra )
{
    foreach ( chr; str )
    {
        if ( !isDigit(chr) && !extra.contains(chr) )
        {
            return false;
        }
    }
    return true;
}


/*******************************************************************************

    Check that the date has valid values for days, months, and years.

    Params:
        day = the day of the month to check
        month = the month of the year to check
        year = the year to check

    Returns:
        true if the date is valid

*******************************************************************************/

private bool validDate ( uint day, uint month, uint year )
{
    if ( year < 1900 )
    {
        return false;
    }
    if ( month < 1 || month > 12 )
    {
        return false;
    }
    if ( day < 1 || day > Gregorian.generic.
        getDaysInMonth(year, month, Gregorian.AD_ERA) )
    {
        return false;
    }
    return true;
}


/*******************************************************************************

    Check that the time has valid values for hour, minute, and second.

    Params:
        hour = the hour of the day to check
        minute = the minute of the hour to check
        second = the second to check

    Returns:
        true if the time is valid

*******************************************************************************/

private bool validTime ( int hour, int minute, int second )
{
    if ( hour < 0 || hour > 23 )
    {
        return false;
    }
    if ( minute < 0 || minute > 59 )
    {
        return false;
    }
    if ( second < 0 || second > 59 )
    {
        return false;
    }
    return true;
}


/*******************************************************************************

    unittest for the date conversion

*******************************************************************************/

unittest
{
    void testConversion ( int test_number, cstring datetime,
        time_t expected_time, DateConversion expected_conversion,
        bool should_pass = true )
    {
        mstring test_name;
        time_t timestamp;
        auto conversion_type = DateConversion.None;

        // format the test name
        Format.format(test_name, "Date conversion test {}: ", test_number);

        // check the conversion works if it should or fails if it should not
        auto success = timeToUnixTime(datetime, timestamp, conversion_type);
        assert(should_pass == success, test_name ~ "Failed");

        // only check the datetime and type if the initial test passes
        if ( should_pass )
        {
            assert(timestamp == expected_time, test_name ~ "Incorrect DateTime");
            assert(conversion_type == expected_conversion,
                test_name ~ "Incorrect Type");
        }
    }

    testConversion(1, "2013-09-05 14:44:01", 1378392241, DateConversion.DateTime);

    testConversion(2, "2013-09-05T14:55:17", 1378392917, DateConversion.DateTimeT);

    testConversion(3, "20130930", 1380499200, DateConversion.YearMonthDay);

    testConversion(4, "2013-03-13", 1363132800, DateConversion.YearMonthDayWithHyphen);

    testConversion(5, "201309", 1377993600, DateConversion.YearMonth);

    testConversion(6, "2013-03", 1362096000, DateConversion.YearMonthWithHyphen);

    testConversion(7, "10000101", 0, DateConversion.None, false);

    testConversion(8, "2013-09-31 14:44:01", 0, DateConversion.None, false);

    testConversion(9, "2013-11-32", 0, DateConversion.None, false);

    testConversion(10, "2013-13", 0, DateConversion.None, false);

    testConversion(11, "2013-12-01-", 0, DateConversion.None, false);

    testConversion(12, "2013-09-05 24:44:01", 0, DateConversion.DateTime, false);

    testConversion(13, "2013-09-05T14:61:17", 0, DateConversion.DateTimeT, false);

    testConversion(14, "2013-09-05 24:44:80", 0, DateConversion.DateTime, false);
}
