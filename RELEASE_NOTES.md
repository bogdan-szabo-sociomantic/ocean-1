Dependencies
============

Dependency | Version
-----------|---------
tango      | v1.1
dmd1       | v1.077.s14

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

* `ocean.util.app.ext.VersionInfo`

  `VersionInfo` is now an alias for `istring[istring]` (before it was a class).
  Applications normally shouldn't need use the actual type, only pass it around,
  so they shouldn't notice this change.

* `script/common.mk`

  This long deprecated file was completely removed.

* `ocean.util.serialize.contiguous.Serializer`

  The `Serializer` accepts the struct to serialize by reference. Hence rvalues
  cannot be passed to the 'serialize' method anymore.

* `ocean.io.console.AppStatus`
  `AppStatus` will no longer inserts a newline after the last row of the output
  when deleted. Applications that wish to keep the behaviour should call
  `Stdout.endrow.newline.flush` directly.

* `ocean.math.Range`

  The `opEquals()` method which compares a range against a set of ranges no
  longer takes empty ranges in the list bein compared into account. (The old
  behaviour -- including empty ranges in the comparison -- caused the function
  to always return false in the presence of empty ranges.)

Deprecations
============

* `ocean.net.http.*`

  Deprecated `*Uint` methods in HTTP modules (`readUint` / `writeUint` / etc).
  All methods in question were designed around storing `uint` values but are
  actually used to store data that can be in `ulong` range.  Matching
  `*Unsigned` method have been added to be used instead.

* *Makd*

  Ocean's copy of Makd is now deprecated, as Makd becase a standalone project.
  The current copy of Makd.mak is brought up to date with the Makd project but
  it shouldn't be used anymore, so it will issue a warning if it is used.

  Projects should move to use the [Makd](https://github.com/sociomantic/makd/)
  as a submodule instead. The `Version.d` file is now generated in the `build/`
  directory, so projects having `src/Version.d` in `.gitignore` are encourage to
  remove it after the switch. Also, don't forget to update the location where to
  read `Makd.mak` to `submodules/makd/Makd.mak` when you switch to the Makd
  repository!

  The files `script/Makd.mak`, `script/Makd.README.rst` and
  `script/mkversion.sh` were updated, while `script/appVersion.d.tpl` was
  renamed to `script/Version.tpl.d` to match the one in the Makd repo (although
  project shouldn't use that file directly anyway).

  The generated `Version.d` also now stores an associative array
  `istring[istring]` instead of being a class, this is to avoid a dependency in
  Makd to Ocean.

New Features
============

* ``ocean.sys.socket.UnixSocket.d``

  A new UnixSocket class was added, enabling communication via
  Unix Sockets.

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

* ``ocean.math.IrregularMovingAverage``

  Struct implementation of a moving average designed to handle irregularly
  spaced data (i.e. data where the time intervals between successive values
  are not the same).

* `ocean.util.container.queue.LinkedListQueue`

  A new Queue structure is introduced. In addition to implementing the
  `ITypedQueue` interface, it also allows finding a value in the queue
  and removing specified value(s) from the queue.

* `ocean.core.Array`

  New functions:

  * `findDuplicates`: find and iterate over duplicate elements in an
     array
  * `containsDuplicate`: check if duplicates exist in an array

