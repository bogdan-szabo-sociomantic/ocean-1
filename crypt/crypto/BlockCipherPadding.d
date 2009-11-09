/**
 * This file is part of the dcrypt project.
 *
 * Copyright: Copyright (C) dcrypt contributors 2008. All rights reserved.
 * License:   MIT
 * Authors:   Thomas Dixon
 */
 
 module ocean.crypt.crypto.BlockCipherPadding;
 
 public import ocean.crypt.crypto.errors.InvalidPaddingError;
 
 /** Base padding class for implementing block padding schemes. */
 abstract class BlockCipherPadding
 {
    /** Returns: The name of the padding scheme implemented. */
    char[] name();

    /**
    * Generate padding to a specific length.
    *
    * Params:
    *     len = Length of padding to generate
    *
    * Returns: The padding bytes to be added.
    */ 
    ubyte[] pad(uint len);

    /**
    * Return the number of pad bytes in the block.
    *
    * Params:
    *     input_ = Padded block of which to count the pad bytes.
    *
    * Returns: The number of pad bytes in the block.
    *
    * Throws: dcrypt.crypto.errors.InvalidPaddingError if 
    *         pad length cannot be discerned.
    */
    uint unpad(void[] input_);
    
 }
