Dependencies
============

Dependency | Version
-----------|---------
tango      | v1.1
dmd1       | v1.076.s2

Migration Instructions
======================

* `ocean.core.ArrayMap` `ocean.util.OceanException` `ocean.util.TraceLog`
`ocean.util.log.MessageLogger` `ocean.util.log.Trace`

  These modules have been deprecated for a long time and are completely
  removed now. Please refer to original deprecation instructions if your
  application is still using them.

* `ocean.core.Exception`

  All deprecated `assertEx` function have been completely removed. Please
  use `enforce` instead.

* `ocean.io.serialize.StructLoader` `ocean.io.serialize.StructDumper`

  Those deprecated modules and their deprecated dependencies have been
  completely removed.

* `ocean.net.http.message.HttpHeaderParser` `ocean.util.container.pool.model.IPool`
`ocean.util.container.queue.FlexibleFileQueue`

  All methods that return length now return value of `size_t` type instead
  of `uint`. You may need to update the type of variables / fields it gets
  assigned to accordingly.

Deprecations
============

* `ocean.net.http.*`

  Deprecated `*Uint` methods in HTTP modules (`readUint` / `writeUint` / etc).
  All methods in question were designed around storing `uint` values but are
  actually used to store data that can be in `ulong` range.  Matching
  `*Unsigned` method have been added to be used instead.

New Features
============

* ``ocean.text.json.JsonExtractor``

  GetObject can now skip null values

* ``ocean.io.console.AppStatus``

  The foreground and background colours as well as the boldness of both static
  and streaming lines can now be controlled.
  For example:

  ```d
  app_status.red.bold.formatStaticLine(0, "bold red static line");
  // ...
  app_status.blue.displayStreamingLine("normal blue streaming line");
  ```

  Consult the module documentation for further details about the supported
  colours and how to apply them.

* ``mkversion.sh``

  Previosly, build time was appearing in version string with
  date quoted in the double quotes. ``mkversion.sh`` now uses ``date``
  format string to generate build time stamp without quotes around time.
  Also, the build time is changed to UTC with a clear indicator that
  displayed build time is in UTC.

