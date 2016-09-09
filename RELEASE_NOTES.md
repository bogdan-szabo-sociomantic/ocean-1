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
