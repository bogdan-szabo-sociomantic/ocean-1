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

* `ocean.io.serialize.SimpleSerializer`

  Upon EOF, `SimpleSerializer` now throws a new exception type, `EofException`.
  It previously threw `IOException`, making it impossible to distinguish between
  EOF and other I/O errors.

* `ocean.util.config.ClassFiller`

   Both `fill` overloads and `iterate` will now trigger an assertion failure
   if `null` is provided as the `config` parameter.
   The default parameter (which was `null`) has also been removed.

Removed Deprecated Modules
--------------------------

* `ocean.util.container.cache.PriorityCache`

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

* `ocean.text.util.StringSearch`

   Two overload of `split` and `splitCollapse` which created arrays of slices
   and have been deprecated since late 2011 have been removed.

Removed Symbols
---------------

* `ocean.db.tokyocabinet.util.TokyoCabinetException`,
  `ocean.io.serialize.JsonStructDeserializer`,
  `ocean.io.serialize.StructSerializer`,
  `ocean.util.cipher.HMAC`,
  `ocean.util.config.ConfigParser`

   The following static opCall which trivially wrapped the exception constructor
   have been removed:
   - `ocean.db.tokyocabinet.util.TokyoCabinetException.TokyoCabinetException`
   - `ocean.db.tokyocabinet.util.TokyoCabinetException.TokyoCabinetException.Cursor`
   - `ocean.io.serialize.JsonStructDeserializer.JsonException`
   - `ocean.io.serialize.StructSerializer.SerializerException`
   - `ocean.util.cipher.HMAC.HMACException`
   - `ocean.util.config.ConfigParser.ConfigException`

   They can be replaced in a backward-compatible way by calling the constructor
   directly (prepend a `new`).

Deprecations
============

* `ocean.io.serialize.StructSerializer`

  The binary serialization facilities of this module have been deprecated. Any
  code which is still using this should be adjusted to use the new serializer in
  `ocean.util.serialize`. (The stream and plugin serialization facilities of
  `StructSerializer` remain unchanged.)

* `ocean.core.StructConverter.structCopy`

  The function has been renamed. See Migration Instructions.

* `ocean.util.Config`

   The module and it's globally-available `ConfigParser Config` member have been
   deprecated.  The app framework (`ConfigExt`, `ConfiguredApp` and `ConfiguredCliApp`)
   have been updated to instantiate it itself instead of relying on this global instance.
   This change is mostly transparent for applications, with the exception of the part
   mentioned in the Migrations Instructions.

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

* `ocean.core.Exception`

   A new `DefaultExceptionCtor` mixin template has been introduced.
   Similar to `DefaultExceptionImpl`, you can mix it in to get the usual
   constructor for exceptions.
