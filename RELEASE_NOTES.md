Dependencies
============

Dependency | Version
-----------|---------
tango      | v1.2.1
dmd1       | v1.077.s14

Migration Instructions
======================

* `ocean.core.Array`

  It was impossible to exactly preserve API of `removeSuffix`, `removePrefix`, `startsWith`
  and `endsWith` functions during D2 migration and those are now more restrictive : `null`
  is no longer a valid argument (use `""` or `[]` instead), explicit template parameter
  may not work (but should be never needed)

* `ocean.core.ErrnoIOException`

  In most cases it should be possible to simply replace all mentions of `ErrnoIOException`
  with `ocean.sys.ErrnoException` and all usage of `assertEx` / `opCall` with
  `enforce` / `useGlobalErrno()` respectively. In cases where manually setting error number
  is necessary, `set` method can be used.
  If there is a custom exception class that
  inherited `ErrnoIOException`, detailed examination of docs may be unavoidable.

* `ocean.util.app.ext.ConfigExt`

  Handling of the old argument format for overriding config values from the command line
  (`[cat]key=value`) has been removed. Use the simpler `cat.key=value` format instead.

* `ocean.util.config.ConfigParser`

  The parser will no longer warn on spaces in the category name.

Removed Deprecated Modules
--------------------------

* `ocean.core.TwoWayMap`

* `ocean.core.UniStruct`

* `ocean.io.compress.Zlib`

  This module wasn't used anywhere nor tested, and date from 2009.

Deprecations
============

* `ocean.core.ErrnoIOException`

  This module has been deprecated in favor of new `ocean.sys.ErrnoException` because functionality
  of the old one was lacking and exception hierarchy it forced was too narrow-minded. See documentation
  of new module for more details.

* `ocean.sys.SignalHandler`

  This old module was quite a mess. Applications using it should be updated to
  use `ocean.util.app.ext.SignalExt` instead.

* `ocean.util.serialize.model.Version`

  Renamed to `ocean.util.serialize.Version` because placing it in model package
  discourage developers from using it in application code casually (which was never
  the intention)

* `ocean.util.log.StatsLog`

  * `addSuffix` (and the protected `formatValue(cstring name, V value, bool add_separator, cstring suffix = null)`,
    which it uses internally) is deprecated: This method allowed building a custom hierarchy.
    Please use `addObject` instead.
  * Passing individual values and associative arrays to `add` is deprecated.
    All values must be encapsulated in a struct.
  * Logging of structs containing non-numeric types issues a warning. This behaviour will soon be removed.

* `ocean.util.ReusableException`

  `assertEx` is renamed to `enforce` to match `ocean.core.Exception`

* `ocean.core.DeepCopy`

  This module was proved to be very hard to port to D2 with no semantic changes and all
  existing use cases are already covered by `ocean.core.StructConverter`.

* `ocean.sys.SignalMask`

  - The static global functions `getSignalMask()` and `setSignalMask()` were
    replaced with the `SignalSet` struct methods `getCurrent()` and `mask()`,
    respectively.
  - The static global function `maskSignals()` is obsolete, use the `SignalSet`
    struct methods `add()`, `block()` and `callBlocked()` instead.

New Features
============

* `ocean.core.Exception`

  Now provides `ReusableExceptionImplementation` template mixin that allows to quickly create new
  exception classes with reusability semantics : it adds new mutable string field to be used
  for formatting instead of `Exception.msg` and overrides `toString` to use that mutable field
  if not empty.

* `ocean.core.Traits`

  New utility `identifier!(alias Sym)` returns name of any symbol as string, including function
  symbols

* `ocean.sys.ErrnoException`

  New module that provides `ErrnoException` class which is capable of automatic capturing of last
  global `errno` and formatting it into exception error message. It also optionally can remember
  name of extern function that failed.

  Please refer to documented unittests of each `ErrnoException` method for more details.

* `ocean.io.FileException`

  Inherits `ErrnoException` and provides additional utility method for handling error conditions
  of C file I/O. Suggested as standard replacement of many similar `FileException` implementations
  in different projects.

* `ocean.util.cipher.HMAC.hexDigest` and `ocean.util.cipher.ByteConverter.hexEncode`

  These methods now both support taking a reusable buffer as their second
  arguments so that memory allocation can be avoided.

* `ocean.util.log.StatsLog`

  A new method, `addObject(istring category, T)(cstring instance, ref T values)`, was added, which allows
  users to log multiple instances of a named "object" of a named "category" containing values as defined in
  a given struct instance. (Note that all data types (i.e. struct instances) for a given category should be the same.)

  An example of a situation where this feature is helpful is when you need to log stats per adpan.
  For example, you may be tracking the number of views and the number of clicks on a per-adpan basis.
  Calling `addObject!("adpan")("zalando", zalando_stats);` would then add the following to the stats log:
  `adpan/zalando/clicks: 4 adpan/zalando/views: 400`

  If you plan to use this feature, check with Infrastructure team to get your scripts updated.

* `ocean.util.ReusableException`

  `ReusableException` class has been reimplemented to have semantics compatible with D2
  and `ocean.core.Exception.enforce`. Now it uses different member field for reusable
  mutable buffer and thus allows to set `.msg` to immutable literal (as `enforce` does).
  Usage of member `enforce` method is still necessary for non-literal messages.

* `ocean.core.StructConverter`

  `structCopy` now uses default delegate argument which allocates GC memory if no
  explicit delegate agument was specified. That will make it more convenient to use
  it in tests.
