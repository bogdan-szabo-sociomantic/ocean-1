Dependencies
============

Dependency | Version
-----------|---------
makd       | v1.3.x
tango      | v1.3.x

New Features
============

* `ocean.util.config.ConfigFiller`

  Provides the same functionality as the old `ClassFiller`, but it's
  extended to support `struct`s too.

* `ocean.util.container.queue.LinkedListQueue`

  Added the ability to walk over a `LinkedListQueue` with a foreach statement.
  It will walk in order from head to tail.

* `ocean.util.encode.Base64`

  - the encode and decode tables used by `encode`, `encodeChunk` and `decode` have been rewritten in a readable way,
    and made accessible to user (`public`) under the `defaultEncodeTable` and `defaultDecodeTable` names, respectively;
  - encode and decode table for url-safe base64 (according to RFC4648) have been added under the `urlSafeEncodeTable`
    and `urlSafeDecodeTable`, respectively;
  - `encode` and `decode` now accepts their table as template argument: this means one can provide which characters are
    used for base64 encoding / decoding. By default `default{Encode,Decode}Table` are used to keep the old behavior.
  - `encode` now takes a 3rd argument, `bool pad` which defaults to `true`, to tell the encoder whether to pad or not.


Deprecations
============

* `ocean.util.config.ClassFiller`

  Deprecated in favour of the new `ConfigFiller` which provides the
  same interface.
