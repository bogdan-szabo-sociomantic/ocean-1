Dependencies
============

Dependency | Version
-----------|---------
makd       | v1.3.x
tango      | v1.3.x

Deprecations
============

New Features
============

* `ocean.util.cipher.gcrypt.AES`

  Aliases for AES-CBC ciphers have been added.

* `ocean.text.utf.UtfUtil`

  Add `truncateAtN` method which truncates a string at the last space before
  the n-th character or, if the resulting string is too short, at the n-th
  character.

* `ocean.util.cipher.gcrypt.c.kdf`

  Bindings to gcrypt's C functions for key derivation have been added.

* `ocean.util.cipher.gcrypt.core.KeyDerivationCore`

  A wrapper class for gcrypt's key derivation functions has been added.

* `ocean.util.cipher.gcrypt.PBKDF2`

  An alias for key derivation using the PBKDF2 algorithm has been added.

* `ocean.util.cipher.misc.Padding`

  New module with cryptographic padding functions, currently contains functions
  for PKCS#7 and PKCS#5 padding.
