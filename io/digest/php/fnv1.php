<?php
/******************************************************************************
        
        Fowler / Noll / Vo (FNV) 1 digest implementation
        
        copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved

        license:        BSD style: $(LICENSE)
        
        version:        Apr 2010: Initial release
                        
        author:         David Eckardt
        
        Reference: L.C. Noll's web page about FNV
        
                    http://www.isthe.com/chongo/tech/comp/fnv/
        
        
        
        Requires: GNU Multi-Precision Library (GMP) for PHP, see
                    
                            http://de3.php.net/gmp
        
        
        
        Notes: Calculation has been done by GMP because PHP would automatically
               do an integer to floating point conversion resulting in incorrect
               digest values due to loss of precision.
        
 ******************************************************************************/

/******************************************************************************

    Constants and test data, taken from L.C. Noll's web page
    
    
    
                   32 bit        64 bit
   
    inital digest: 0x811C9DC5    0xCBF29CE484222325
    prime number:  0x01000193    0x00000100000001B3
  
    test string:   "391581216093391581216093391581216093391581216093391581216093391581216093391581216093391581216093391581216093391581216093"
  
    test result:  0xC5F1D7E9     0x43C94E2C8B277509
    
 ******************************************************************************/


/******************************************************************************
    
    Calculates a 32 bit FNV1 digest from data. Data is interpreted as an octet
    (byte) sequence.
    
    Params:
        data = input data (octet sequence)
        
    Returns:
        string containing hexadecimal representaion of 32 bit FNV1 digest
    
 ******************************************************************************/

function fnv132_hex ( $data )
{
    $PRIME  = gmp_init("0x01000193");
    $digest = gmp_init("0x811C9DC5");
    
    foreach (str_split($data) as $chr)
    {
        $digest = gmp_mul($digest, $PRIME);
        $digest = gmp_xor($digest, gmp_init(ord($chr)));
    }
    
    return substr(gmp_strval($digest, 16), -8, 8);
}

/******************************************************************************
    
    Calculates a 64 bit FNV1 digest from data. Data is interpreted as an octet
    (byte) sequence.
    
    Params:
        data = input data (octet sequence)
        
    Returns:
        string containing hexadecimal representaion of 64 bit FNV1 digest
    
 ******************************************************************************/

function fnv164_hex ( $data )
{
    $PRIME  = gmp_init("0x00000100000001B3");
    $digest = gmp_init("0xCBF29CE484222325");
    
    foreach (str_split($data) as $chr)
    {
        $digest = gmp_mul($digest, $PRIME);
        $digest = gmp_xor($digest, gmp_init(ord($chr)));
    }
    
    return substr(gmp_strval($digest, 16), -16, 16);
}

print "hash = " . fnv132_hex("391581216093391581216093391581216093391581216093391581216093391581216093391581216093391581216093391581216093391581216093") . PHP_EOL;
print "hash = " . fnv164_hex("391581216093391581216093391581216093391581216093391581216093391581216093391581216093391581216093391581216093391581216093") . PHP_EOL;

?>