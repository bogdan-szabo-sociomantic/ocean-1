/**
 * This file is part of the dcrypt project.
 *
 * Copyright: Copyright (C) dcrypt contributors 2008. All rights reserved.
 * License:   MIT
 * Authors:   Thomas Dixon
 */

module ocean.crypt.crypto.errors.InvalidKeyError;

import ocean.crypt.crypto.errors.InvalidParameterError;

class InvalidKeyError : InvalidParameterError {
    this(char[] msg) { super(msg); }
}
