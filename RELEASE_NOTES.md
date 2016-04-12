Dependencies
============

Based on v1.27.1

Dependency | Version
-----------|---------
makd       | v1.3.x
tango      | v1.3.x

Migration Instructions
======================

* `ocean.*`

  All modules have been stripped of any mentions of mutexes and
  `synchronized`. This shouldn't affect any of our projects as those
  are exclusively single-threaded and any synchronization is thus
  wasted time.

* `tango.*`

  Completely removed, use modules from ocean package.

* `ocean.util.app.ext.LogExt`,
  `ocean.util.app.ext.StatsExt`,
  `ocean.util.log.Stats`,
  `ocean.util.log.Config`

  The `LogExt` and `StatsExt`, the `configureLoggers()` function in
  `ocean.util.log.Config`, and the constructor of `StatsLog` no longer configure
  the application's log files to automatically rotate themselves (via the
  `AppendSyslog` appender in tango). Instead, it is expected that logs will be
  rotated via the `logrotate` system facility in conjunction with the
  `ReopenableFilesExt`. Programs which make use of loggers should be based on
  ocean's `DaemonApp`, which provides all the facilities required for rotated
  log files (see the [v1.26.0 release notes](https://github.com/sociomantic/ocean/releases/tag/v1.26.0)
  for migration instructions).

  The file-rotation-related fields or `StatsLog.Config` (that is,
  `max_file_size`, `file_count`, `start_compress`) have been removed, along with
  the corresponding `default_` constants in `StatsLog`.

Deprecations
============

* `ocean.*`

  All symbols deprecated in ocean v1.x.x have been completely removed

New Features
============
