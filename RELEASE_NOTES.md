Dependencies
============

Dependency | Version
-----------|---------
tango      | v1.2.1
dmd1       | v1.077.s14

Migration Instructions
======================


Removed Deprecated Modules
--------------------------

* `ocean.core.TwoWayMap`

* `ocean.core.UniStruct`

Deprecations
============

* `ocean.sys.SignalHandler`

  This old module was quite a mess. Applications using it should be updated to
  use `ocean.util.app.ext.SignalExt` instead.

New Features
============

* `ocean.util.cipher.HMAC.hexDigest` and `ocean.util.cipher.ByteConverter.hexEncode`

  These methods now both support taking a reusable buffer as their second
  arguments so that memory allocation can be avoided.
