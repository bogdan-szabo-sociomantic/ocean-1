Dependencies
============

Dependency | Version
-----------|---------
makd       | v1.3.x
tango      | v1.3.x

Migration Instructions
======================

* `tango.util.log.AppendSyslog`

  **WARNING:** This module is currently used by all applications which write log
  files (including stats logs). It handles the automatic rotation of log files.
  It is, however, buggy and scheduled to be replaced by the system `logrotate`
  facility. Introducing a workable deprecation path has proven troublesome, so
  this module is going to be **completely removed** in the upcoming ocean v2.0.0
  release.

  This appender is used internally in ocean in the `StatsExt` and `LogExt`,
  which will be adapted to no longer perform any log rotation. These extensions
  are used by all applications (as far as is known). This means that, if you do
  nothing before updating to ocean v2.0.0, your log files **will no longer be
  rotated**.

  All applications which rely on the log rotation facility provided by
  `AppendSyslog` should be adapted to rely on the system `logrotate` facility to
  rotate their log files, instead. The most convenient way of doing this is to
  use the facilities present in `DaemonApp`. See the
  [v1.26.0 release notes](https://github.com/sociomantic/ocean/releases/tag/v1.26.0)
  for full instructions on how to use these facilities.

* `ocean.util.app.ext.StatsExt`

  StatsLog instances created by `newStatsLog` will be named according to the file to which
  they write.  This means that the name of the default `StatsLog` instance will change from
  "Stats" to (by default) "log/stats.log".

Deprecations
============

* `tango.*`

  Tango package has been deprecated. Most of modules have been moved to `ocean`
  package with no changes. If this would result in a module name clash, then a
  _tango suffix is added. To quickly adjust majority of imports run this shell
  script:

  ```Bash
    # exceptions with _tango suffix first:
    find ./src -type f -name *.d | xargs sed -i 's|import tango.core.Exception|import ocean.core.Exception_tango|g'
    find ./src -type f -name *.d | xargs sed -i 's|import tango.core.Array|import ocean.core.Array_tango|g'
    find ./src -type f -name *.d | xargs sed -i 's|import tango.text.convert.Layout|import ocean.text.convert.Layout_tango|g'
    find ./src -type f -name *.d | xargs sed -i 's|import tango.text.convert.Integer|import ocean.text.convert.Integer_tango|g'
    find ./src -type f -name *.d | xargs sed -i 's|import tango.text.convert.DateTime|import ocean.text.convert.DateTime_tango|g'
    find ./src -type f -name *.d | xargs sed -i 's|import tango.io.Stdout|import ocean.io.Stdout_tango|g'
    find ./src -type f -name *.d | xargs sed -i 's|import tango.io.FilePath|import ocean.io.FilePath_tango|g'
    find ./src -type f -name *.d | xargs sed -i 's|import tango.util.log.Config|import ocean.util.log.Config_tango|g'
    # rest of imports
    find ./src -type f -name *.d | xargs sed -i 's|import\s\+tango\.\([.a-zA-Z]\+\)|import ocean.\1|g'
  ```
* `ocean.text.convert.Layout_tango` `ocean.text.convert.Integer_tango` `ocean.text.convert.DateTime_tango` `ocean.io.Stdout_tango` `ocean.io.FilePath_tango`

  These modules are not yet deprecated but are schedule to in next release.
  It is recommended to start switching to ocean counter-parts as early
  as possible if feasible.

* `ocean.core.Exception`

  Using `ocean.core.Exception` as a way to access symbols from
  `ocean.core.Enforce` is deprecated to avoid cyclic dependencies. Please
  import `ocean.core.Enforce` directly.

* `ocean.text.util.StringReplace`

  This unmaintained and untested module was only used by nautica. It can
  be replaced by functionality from other array/text util modules which
  are more up to date.

* `ocean.text.utf.UtfConvert`

  Completely unused and unmaintained module.

New Features
============

* `ocean.util.app.ext.StatsExt`

  A new method, `newStatsLog()` has been added. This method allows the user to
  create `StatsLog` instances in addition to the one which is created
  automatically by the `StatsExt` and stored in its `stats_log` member. The new
  stats logger is configured according to the default settings and will be
  registered with the application's `ReopenableFilesExt`, if present, for log
  rotation. (The ability to create multiple stats loggers is desired by some
  applications, so this method has been added to enable them to easily create
  properly configured instances.)
