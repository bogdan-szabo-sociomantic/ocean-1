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

Releases
========

`Latest release notes
<https://github.com/sociomantic/ocean/releases/latest>`_ | `Current, in
development, release notes
<https://github.com/sociomantic/ocean/blob/master/RELEASE_NOTES.md>`_ | `All
releases <https://github.com/sociomantic/ocean/releases>`_

Ocean's release process is based on `SemVer
<https://github.com/sociomantic/ocean/blob/master/VERSIONING.rst>`_. This means
that the major version is increased for breaking changes, the minor version is
increased for feature releases, and the patch version is increased for bug fixes
that don't cause breaking changes.

Any major version branch is maintained for 6 months from the point when the
first release from the next major version branch happens. For example, if there
is a `v2.x.x` branch, it will get new features and bug fixes for 6 months
starting with the release of `v3.0.0` and will then be dropped out of support.

Releases are handled using `GitHub releases
<https://github.com/sociomantic/ocean/releases>`_. The release notes provided
there are usually structured in 3 sections: **Migration Instructions**, which
are the mandatory steps a user must do to update to the new version,
**Deprecated**, which contains deprecated functions which are not recommended to
be used but will not break any old code, and **New Features** which are new
features available in the new version that users might find interesting.

These instructions should help developers to migrate from one minor version to
another. The changes listed are the steps you need to take to move from the\
previous version to the one being listed. For example, all the steps described
in version **v2.5.0** are the steps required to move from **v2.4.x** to
**v2.5.x**.

If you need to jump several versions at once, you should read all the steps from
all the intermediate versions. For example, to jump from **v2.1.1** to **v2.4.3**,
you need to first follow the steps in version **v2.2.0**, then the steps in
version **v2.3.0** and finally the steps in version **v2.4.0**.

When there are *patch-level* (point) releases it always means there are no
breaking changes or new features, just bug fixes. Because of that, the release
notes will only contain a simple list of fixed issues.
