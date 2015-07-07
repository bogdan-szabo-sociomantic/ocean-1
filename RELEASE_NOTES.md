Dependencies
============

Dependency | Version
-----------|---------
tango      | v1.2.1

Migration Instructions
======================

* `ocean.util.container.map.utils.MapSerializer`

  If you change your key or value structs from non-versioned to versioned, you
  should first load the map before applying any change of the structs and dump
  the map again so it is saved in the new format. After that you can just add
  version-information as desired.

* `ocean.core.StructConverter`

  `structCopy()` was frequently mistaken for an equivalent of `deepCopy()`, however
  it doesn't do a true deep copy as it avoids copying memory when possible. To
  make this more clear the function was renamed to `structConvert()`.

Removed Deprecated Modules
--------------------------
* `ocean.util.container.cache.PriorityCache

  `droppingItem()` method has been replaced with `itemDropped()`. Also the
  notifier is now called after the item has already been removed from the
  cache. The refactored method passes the key as well as a reference to the
  dropped item as parameters. The default implementation of the method is
  to set the item to its init value.

Removed Deprecated Symbols
--------------------------

* `ocean.util.config.ConfigParser`

  `parse` has been taken out of the ConfigParser API. `parse` used to be an
  alias for the `parseFile` method, and has been deprecated since Oct 2014.

Deprecations
============

* `ocean.io.serialize.StructSerializer`

  The binary serialization facilities of this module have been deprecated. Any
  code which is still using this should be adjusted to use the new serializer in
  `ocean.util.serialize`. (The stream and plugin serialization facilities of
  `StructSerializer` remain unchanged.)

* `ocean.core.StructConverter.structCopy`

  The function has been renamed. See Migration Instructions.

New Features
============

* `ocean.util.container.map.utils.MapSerializer`

   `MapSerializer` now provides an easier path to update from maps using
   non-versioned keys or values to maps that start using a version for either.
   Additionally, the map now also always does a struct hash validation in case
   the versioning code was wrong.

* `ocean.core.Test`

  New test helper, `testNoAlloc`, which checks GC usage stats before and after
  calling given expression and ensures no allocations happen.
