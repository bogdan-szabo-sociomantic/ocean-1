Dependencies
============

Dependency | Version
-----------|---------
makd       | v1.3.x
tango      | v1.3.x

New Features
============

* `ocean.core.Traits`
  A new symbol, `TemplateInstanceArgs` was introduced.
  It allows to get the arguments of a template instance in a D1-friendly manner.
  It can also be used to check if a type is an instance of a given template.

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

* `ocean.net.server.unix.UnixListener`, `ocean.net.server.unix.UnixConnectionHandler`

  `UnixListener` and `UnixConnectionHandler` classes are added with support for listening on the unix socket
   and responding with the appropriate actions on the given commands. Users can connect to the application on
   the desired unix socket, send a command, and wait for the application to perform the action and/or write
   back the response on the same connection.

Deprecations
============

* `ocean.util.config.ClassFiller`

  Deprecated in favour of the new `ConfigFiller` which provides the
  same interface.
