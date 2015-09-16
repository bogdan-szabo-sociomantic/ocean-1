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

* `ocean.text.url.PercentEncoding`

  Deprecated as it was empty in v1.23

* `ocean.util.Config`

  Deprecated in v1.23

* `ocean.util.container.queue.SimplifiedFlexibleRingQueue`

  Deprecated in favor of `ocean.util.container.queue.FlexibleRingQueue` in v1.23

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
