Dependencies
============

Dependency | Version
-----------|---------
tango      | v1.3.x

Migration Instructions
======================

* `tango.io.device.File`

  `File.get` was expanding a slice without taking it by `ref`, which might cause one
  to believe it was reusing buffer when it wasn't. The method was split in two overloads,
  one without buffer which would allocate and the other with a `ref` buffer. This change
  is not expected to have any effect downstream are all users seemed to be using the default
  argument.

Removed Symbols
---------------

Deprecations
============

New Features
============

* `tango.*`

  Tango sources are now hosted and maintained as part of ocean repository.
  It requires tango 1.3 runtime installed in the system to compile without
  any issues.
