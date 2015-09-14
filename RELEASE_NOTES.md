Dependencies
============

Dependency | Version
-----------|---------
tango      | v1.2.1

Migration Instructions
======================

Removed Deprecated Modules
--------------------------

* `ocean.core.DeepCopy`

  Deprecated in favor of `ocean.util.serialize.contiguos.Util.copy` in v1.22

* `ocean.core.ErrnoIOException`

  Deprecated in favor of `ocean.sys.ErrnoException` in v1.22

Removed Deprecated Symbols
--------------------------

Removed Symbols
---------------

Deprecations
============

* `TokyoCabinetExtString.toString`

  Deprecated in favor of `TokyoCabinetExtString.toMString` because D2 runtime
  requires `toString` to return immutable strings which was not intended in
  this case.

New Features
============
