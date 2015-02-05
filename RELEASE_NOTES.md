Dependencies
============

Dependency | Version
-----------|---------
tango      | v1.1
dmd1       | v1.076.s2

Migration Instructions
======================


Deprecations
============

* `ocean.crypt`

  The whole package has been moved to `ocean.util.cipher` to adhere more to the
  tango structure

New Features
============

* `ocean.db.tokyocabinet.TokyoCabinetM`

  A new `get()` method has been added which allows a record to be got via a
  delegate, rather than copying into a buffer. This can be useful in situations
  where the user doesn't need to store the value.
