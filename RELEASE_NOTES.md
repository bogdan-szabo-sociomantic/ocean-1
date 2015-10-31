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

* `ocean.util.container.pool.model.IPool`

  All index / length methods now operate in terms of `size_t` instead of `uint`.
  Any overriden method needs to be changed accordinly. This is done for cleaner D2
  migration because otherwise it requires casts each time when assigned from
  array length and/or similar entities.

* `ocean.util.container.pool.model.IAggregatePool`

  Expected `object_pool_index` field can now be of both `size_t` and `uint`
  types. Encountering `uint object_pool_index` will result in pragma printed
  suggesting to change it to `size_t` (but not deprecation).

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
