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


Removed Deprecated Modules
--------------------------

* `ocean.core.TwoWayMap`

* `ocean.core.UniStruct`

Deprecations
============

* `ocean.sys.SignalHandler`

  This old module was quite a mess. Applications using it should be updated to
  use `ocean.util.app.ext.SignalExt` instead.

* `ocean.util.serialize.model.Version`

  Renamed to `ocean.util.serialize.Version` because placing it in model package
  discourage developers from using it in application code casually (which was never
  the intention)

New Features
============

* `ocean.util.cipher.HMAC.hexDigest` and `ocean.util.cipher.ByteConverter.hexEncode`

  These methods now both support taking a reusable buffer as their second
  arguments so that memory allocation can be avoided.
