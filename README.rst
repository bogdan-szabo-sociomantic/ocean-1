Description
===========

Ocean is a general purpose library, compatible with both D1 and D2, with a focus
on supporting the development of high-performance, real-time applications. This
focus has led to several noteworthy design choices:

* **Ocean is not cross-platform.** The only supported platform is Linux.
* **Ocean assumes a single-threaded environment.** Fiber-based multi-tasking is
  favoured, internally.
* **Ocean aims to minimise use of the D garbage collector.** GC collect cycles
  can be very disruptive to real-time applications, so Ocean favours a model of
  allocating resources once then reusing them, wherever possible.

Ocean began life as an extension of `Tango
<http://www.dsource.org/projects/tango>`_, some elements of which were
eventually merged into Ocean.

Support Guarantees
------------------

* Major branch development period: 6 months
* Maintained minor versions: 2 most recent

Maintained Major Branches
-------------------------

====== ==================== ===============
Major  Initial release date Supported until
====== ==================== ===============
v2.x.x v2.0.0_: 30/06/2016  TBD
====== ==================== ===============
.. _v2.0.0: https://github.com/sociomantic/ocean/releases/tag/v2.0.0

Releases
========

`Latest release notes
<https://github.com/sociomantic/ocean/releases/latest>`_ | `All
releases <https://github.com/sociomantic/ocean/releases>`_

Ocean's release process is based on `SemVer
<https://github.com/sociomantic/ocean/blob/master/VERSIONING.rst>`_. This means
that the major version is increased for breaking changes, the minor version is
increased for feature releases, and the patch version is increased for bug fixes
that don't cause breaking changes.

Releases are handled using GitHub releases. The notes associated with a
major or minor github release are designed to help developers to migrate from
one version to another. The changes listed are the steps you need to take to
move from the previous version to the one listed.

The release notes are structured in 3 sections, a **Migration Instructions**,
which are the mandatory steps that users have to do to update to a new version,
**Deprecated** which contains deprecated functions that are recommended not to
use but will not break any old code, and the **New Features** which are optional
new features available in the new version that users might find interesting.
Using them is optional, but encouraged.
