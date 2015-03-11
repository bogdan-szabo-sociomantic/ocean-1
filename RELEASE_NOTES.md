Dependencies
============

Dependency | Version
-----------|---------
tango      | v1.1
dmd1       | v1.076.s2

Migration Instructions
======================

`ocean.core.ArrayMap`
`ocean.util.OceanException`
`ocean.util.TraceLog`
`ocean.util.log.MessageLogger`
`ocean.util.log.Trace`
  These modules have been deprecated for a long time and are completely
  removed now. Please refer to original deprecation instructions if your
  application is still using them.

`ocean.core.Exception`
  All deprecated `assertEx` function have been completely removed. Please
  use `enforce` instead.

Deprecations
============


New Features
============

``ocean.text.json.JsonExtractor``
  GetObject can now skip null values
