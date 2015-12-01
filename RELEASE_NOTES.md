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

* `ocean.math.Range`

  - `Range.length()` throws `Exception` for the full range.
  - `Range.overlapAmount()` throws `Exception` called if both ranges are full.

  The preferred way is to use `Range.is_full_range` to check if the range(s)
  is/are full and not call `Range.length()` or `Range.overlapAmount()` then,
  resp.

  This is because these methods return `size_t`, which on x86-64 is an alias of
  `ulong`, the largest integer type. The widely used `hash_t` is an alias of
  `ulong`, too. So on x86-64, if `hash_t`, `size_t` or `ulong` are used as `T`
  then the number of values does not fit in the return type for the full range
  -- the full range contains `size_t.max + 1` values.
  
  * `ocean.io.model.ISuspendableThrottler`

  `ISuspendableThrottler` now contains the method `removeSuspendable` to remove an
  `ISuspendable` from registered suspendables.

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

* `ocean.math.Range`

  - Added `isFullRange()` and `Range.is_full_range`.

* `ocean.util.container.MallocArray`

  A new module which contains collection of functions that aids in creating
  and manipulating malloc based arrays.
