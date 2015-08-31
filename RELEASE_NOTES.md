Dependencies
============

Dependency | Version
-----------|---------
tango      | v1.2.1

Migration Instructions
======================

Removed Deprecated Modules
--------------------------

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
