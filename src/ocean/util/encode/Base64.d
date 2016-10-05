/*******************************************************************************

    This module is used to decode and encode base64 `cstring` / `ubyte[]` arrays

    ---
    istring blah = "Hello there, my name is Jeff.";
    scope encodebuf = new char[allocateEncodeSize(blah.length)];
    mstring encoded = encode(cast(Const!(ubyte)[])blah, encodebuf);

    scope decodebuf = new ubyte[encoded.length];
    if (cast(cstring)decode(encoded, decodebuf) == "Hello there, my name is Jeff.")
      Stdout("yay").newline;
    ---

    copyright:      Copyright (c) 2008 Jeff Davey. All rights reserved

    license:        BSD style: $(LICENSE)

    author:         Jeff Davey

    standards:      rfc4648, rfc2045

    Since:          0.99.7

*******************************************************************************/

module ocean.util.encode.Base64;

import ocean.transition;

version (UnitTest) import ocean.core.Test;

/*******************************************************************************

    Provide the size of the data once base64 encoded

    When data is encoded in Base64, it is packed in groups of 3 bytes, which
    are then encoded in 4 bytes (by groups of 6 bytes).
    In case length is not a multiple of 3, we add padding.
    It means we need `length / 3 * 4` + `length % 3 ? 4 : 0`.

    Params:
      data = An array that will be encoded

    Returns:
      The size needed to encode `data` in base64

*******************************************************************************/


public size_t allocateEncodeSize (in ubyte[] data)
{
    return allocateEncodeSize(data.length);
}

/*******************************************************************************

    Provide the size of the data once base64 encoded

    When data is encoded in Base64, it is packed in groups of 3 bytes, which
    are then encoded in 4 bytes (by groups of 6 bytes).
    In case length is not a multiple of 3, we add padding.
    It means we need `length / 3 * 4` + `length % 3 ? 4 : 0`.

    Params:
      length = Number of bytes to be encoded

    Returns:
      The size needed to encode a data of the provided length

*******************************************************************************/

public size_t allocateEncodeSize (size_t length)
{
    size_t tripletCount = length / 3;
    size_t tripletFraction = length % 3;
    return (tripletCount + (tripletFraction ? 1 : 0)) * 4;
}


/*******************************************************************************

    Encodes `data` into `buff` and returns the number of bytes encoded.
    This will not terminate and pad any "leftover" bytes, and will instead
    only encode up to the highest number of bytes divisible by three.

    Params:
      data = what is to be encoded
      buff = buffer large enough to hold encoded data
      bytesEncoded = ref that returns how much of the buffer was filled

    Returns:
      The number of bytes left to encode

*******************************************************************************/

public int encodeChunk (in ubyte[] data, mstring buff, ref int bytesEncoded)
{
    size_t tripletCount = data.length / 3;
    int rtn = 0;
    char *rtnPtr = buff.ptr;
    Const!(ubyte) *dataPtr = data.ptr;

    if (data.length > 0)
    {
        rtn = cast(int) tripletCount * 3;
        bytesEncoded = cast(int) tripletCount * 4;
        for (size_t i; i < tripletCount; i++)
        {
            *rtnPtr++ = _encodeTable[((dataPtr[0] & 0xFC) >> 2)];
            *rtnPtr++ = _encodeTable[(((dataPtr[0] & 0x03) << 4) | ((dataPtr[1] & 0xF0) >> 4))];
            *rtnPtr++ = _encodeTable[(((dataPtr[1] & 0x0F) << 2) | ((dataPtr[2] & 0xC0) >> 6))];
            *rtnPtr++ = _encodeTable[(dataPtr[2] & 0x3F)];
            dataPtr += 3;
        }
    }

    return rtn;
}

/*******************************************************************************

    Encodes data and returns as an ASCII base64 string.

    Params:
      data = what is to be encoded
      buff = buffer large enough to hold encoded data

    Example:
    ---
    char[512] encodebuf;
    mstring myEncodedString = encode(cast(Const!(ubyte)[])"Hello, how are you today?", encodebuf);
    Stdout(myEncodedString).newline; // SGVsbG8sIGhvdyBhcmUgeW91IHRvZGF5Pw==
    ---

*******************************************************************************/

public mstring encode (in ubyte[] data, mstring buff)
in
{
    assert(data);
    assert(buff.length >= allocateEncodeSize(data));
}
body
{
    mstring rtn = null;

    if (data.length > 0)
    {
        int bytesEncoded = 0;
        int numBytes = encodeChunk(data, buff, bytesEncoded);
        char *rtnPtr = buff.ptr + bytesEncoded;
        Const!(ubyte)* dataPtr = data.ptr + numBytes;
        auto tripletFraction = data.length - (dataPtr - data.ptr);

        switch (tripletFraction)
        {
            case 2:
                *rtnPtr++ = _encodeTable[((dataPtr[0] & 0xFC) >> 2)];
                *rtnPtr++ = _encodeTable[(((dataPtr[0] & 0x03) << 4) | ((dataPtr[1] & 0xF0) >> 4))];
                *rtnPtr++ = _encodeTable[((dataPtr[1] & 0x0F) << 2)];
                *rtnPtr++ = '=';
                break;
            case 1:
                *rtnPtr++ = _encodeTable[((dataPtr[0] & 0xFC) >> 2)];
                *rtnPtr++ = _encodeTable[((dataPtr[0] & 0x03) << 4)];
                *rtnPtr++ = '=';
                *rtnPtr++ = '=';
                break;
            default:
                break;
        }
        rtn = buff[0..(rtnPtr - buff.ptr)];
    }

    return rtn;
}


/*******************************************************************************

    Encodes data and returns as an ASCII base64 string

    Params:
      data = what is to be encoded

    Example:
    ---
    mstring myEncodedString = encode(cast(ubyte[])"Hello, how are you today?");
    Stdout(myEncodedString).newline; // SGVsbG8sIGhvdyBhcmUgeW91IHRvZGF5Pw==
    ---

*******************************************************************************/

public mstring encode (in ubyte[] data)
in
{
    assert(data);
}
body
{
    auto rtn = new char[allocateEncodeSize(data)];
    return encode(data, rtn);
}


/*******************************************************************************

    Decodes an ASCII base64 string and returns it as ubyte[] data.
    Allocates the size of the array.

    This decoder will ignore non-base64 characters, so for example data with
    newline in it is valid.

    Params:
      data = what is to be decoded

    Example:
    ---
    mstring myDecodedString = cast(mstring)decode("SGVsbG8sIGhvdyBhcmUgeW91IHRvZGF5Pw==");
    Stdout(myDecodedString).newline; // Hello, how are you today?
    ---

*******************************************************************************/

public ubyte[] decode (cstring data)
in
{
    assert(data);
}
body
{
    auto rtn = new ubyte[data.length];
    return decode(data, rtn);
}

/*******************************************************************************

    Decodes an ASCCI base64 string and returns it as ubyte[] data.

    This decoder will ignore non-base64 characters, so for example data with
    newline in it is valid.

    Params:
      data = what is to be decoded
      buff = a big enough array to hold the decoded data

    Example:
    ---
    ubyte[512] decodebuf;
    mstring myDecodedString = cast(mstring)decode("SGVsbG8sIGhvdyBhcmUgeW91IHRvZGF5Pw==", decodebuf);
    Stdout(myDecodedString).newline; // Hello, how are you today?
    ---

*******************************************************************************/

public ubyte[] decode (cstring data, ubyte[] buff)
in
{
    assert(data);
}
body
{
    ubyte[] rtn;

    if (data.length > 0)
    {
        ubyte[4] base64Quad;
        ubyte *quadPtr = base64Quad.ptr;
        ubyte *endPtr = base64Quad.ptr + 4;
        ubyte *rtnPt = buff.ptr;
        size_t encodedLength = 0;

        ubyte padCount = 0;
        ubyte endCount = 0;
        ubyte paddedPos = 0;
        foreach_reverse(char piece; data)
        {
            paddedPos++;
            ubyte current = _decodeTable[piece];
            if (current || piece == 'A')
            {
                endCount++;
                if (current == BASE64_PAD)
                    padCount++;
            }
            if (endCount == 4)
                break;
        }

        if (padCount > 2)
            throw new Exception("Improperly terminated base64 string. Base64 pad character (=) found where there shouldn't be one.");
        if (padCount == 0)
            paddedPos = 0;

        auto nonPadded = data[0..($ - paddedPos)];
        foreach(piece; nonPadded)
        {
            ubyte next = _decodeTable[piece];
            if (next || piece == 'A')
                *quadPtr++ = next;
            if (quadPtr is endPtr)
            {
                rtnPt[0] = cast(ubyte) ((base64Quad[0] << 2) | (base64Quad[1] >> 4));
                rtnPt[1] = cast(ubyte) ((base64Quad[1] << 4) | (base64Quad[2] >> 2));
                rtnPt[2] = cast(ubyte) ((base64Quad[2] << 6) | base64Quad[3]);
                encodedLength += 3;
                quadPtr = base64Quad.ptr;
                rtnPt += 3;
            }
        }

        // this will try and decode whatever is left, even if it isn't terminated properly (ie: missing last one or two =)
        if (paddedPos)
        {
            auto padded = data[($ - paddedPos) .. $];
            foreach(char piece; padded)
            {
                ubyte next = _decodeTable[piece];
                if (next || piece == 'A')
                    *quadPtr++ = next;
                if (quadPtr is endPtr)
                {
                    *rtnPt++ = cast(ubyte) (((base64Quad[0] << 2) | (base64Quad[1]) >> 4));
                    if (base64Quad[2] != BASE64_PAD)
                    {
                        *rtnPt++ = cast(ubyte) (((base64Quad[1] << 4) | (base64Quad[2] >> 2)));
                        encodedLength += 2;
                        break;
                    }
                    else
                    {
                        encodedLength++;
                        break;
                    }
                }
            }
        }

        rtn = buff[0..encodedLength];
    }

    return rtn;
}


unittest
{
    istring str = "Hello, how are you today?";
    Const!(ubyte)[] payload = cast(Const!(ubyte)[]) str;

    // encodeChunktest
    {
        mstring encoded = new char[allocateEncodeSize(payload)];
        int bytesEncoded = 0;
        int numBytesLeft = encodeChunk(payload, encoded, bytesEncoded);
        cstring result = encoded[0..bytesEncoded] ~ encode(payload[numBytesLeft..$], encoded[bytesEncoded..$]);
        test!("==")(result, "SGVsbG8sIGhvdyBhcmUgeW91IHRvZGF5Pw==");
    }

    // encodeTest
    {
        mstring encoded = new char[allocateEncodeSize(payload)];
        cstring result = encode(payload, encoded);
        test!("==")(result, "SGVsbG8sIGhvdyBhcmUgeW91IHRvZGF5Pw==");

        cstring result2 = encode(payload);
        test!("==")(result, "SGVsbG8sIGhvdyBhcmUgeW91IHRvZGF5Pw==");
    }

    // decodeTest
    {
        ubyte[1024] decoded;
        ubyte[] result = decode("SGVsbG8sIGhvdyBhcmUgeW91IHRvZGF5Pw==", decoded);
        test!("==")(result, payload);
        result = decode("SGVsbG8sIGhvdyBhcmUgeW91IHRvZGF5Pw==");
        test!("==")(result, payload);
    }
}


private:

/*
    Static immutable tables used for fast lookups to
    encode and decode data.
*/
const ubyte BASE64_PAD = 64;
static istring _encodeTable = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=";

static Const!(ubyte)[] _decodeTable = [
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    0,0,0,62,0,0,0,63,52,53,54,55,56,57,58,
    59,60,61,0,0,0,BASE64_PAD,0,0,0,0,1,2,3,
    4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,
    19,20,21,22,23,24,25,0,0,0,0,0,0,26,27,
    28,29,30,31,32,33,34,35,36,37,38,39,40,
    41,42,43,44,45,46,47,48,49,50,51,
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,0
];
