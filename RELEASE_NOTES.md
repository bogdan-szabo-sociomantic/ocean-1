Dependencies
============

Dependency | Version
-----------|---------
tango      | v1.0.4
dmd1       | v1.076.s2

Migration Instructions
======================

* Makd

  Now the `test/` directory is expected to have some particular structure.
  Please refer to the *New Features* section for details on how this new
  expected structure is.

  If you were specifying flags to the unittest program, you need to add a `%`
  to the rule before `unittest`. For example: `$O/%unittest: override LDFLAGS
  += -lm`.

* `ocean.util.config.ConfigParser`

  ConfigParser used to earlier expose public functions `resetParser` and
  `parseLine`, both of which have now been made private. Applications using the
  ConfigParser do not need to call these functions.

* `ocean.util.serialize.contiguous.Deserializer.copy`

  `copy` was moved from `Deserializer` module to new `Util` module. Update your
  imports unless you use `package_.d`

Deprecations
============

* `ocean.util.config.ConfigParser`

  The function `parse` used for parsing config files is now deprecated.
  Applications should henceforth use the `parseFile` function for this. The
  function signature remains unchanged.

New Features
============

* Makd

  Makd learned how to automatically build and run integration tests. If the
  `test/` directory exists, it is expected to be populated by subdirectories,
  each holding individual tests programs that provide a top-level `main.d`
  file, used to compile the test program.

  The *unittest* target was also split to be able to run fast and slow unit
  tests separately. To run just the fast unit tests use the *fastunittest*
  target. The plain *unittest* target is now an alias for the more specific
  *allunittest* target, which run both fast and slow tests. All tests are
  assumed to be fast unless they are separated to another file with the pattern
  `<MODULE>_slowtest.d`. These modules should live in the `src/` directory and
  are not built or run by the *fastunittest* target.

  Also, the shorter *fasttest* target is now provided, which is just an alias
  for *fastunittest*, but can be expanded by adding targets to the special
  `$(fasttest)` variable.

  Please take a look at the [Makd README](https://github.com/sociomantic/ocean/blob/master/script/Makd.README.rst#testing)
  and the [Projects Directory Structure](https://github.com/sociomantic/backend/wiki/Projects-Directory-Structure#test)
  documents for details.

* `ocean.util.config.ConfigParser`

  The ConfigParser is now capable of repeatedly parsing an unchanged
  configuration without any additional memory allocation, and a different
  configuration with only minimal extra allocation as needed. This enhancement
  does not require any changes to applications using the ConfigParser module.

* `ocean.io.device.DirectIO`

  `BufferedDirectReadFile` has a new protected method, `newFile()`, just like
  `BufferedDirectWriteFile`, so subclasses can change what `File` subclass to use.

* `ocean.util.serialize.contiguous.Util`

  New module that contains utilities built on top of (de)serializer. New `copy`
  overload was added here that can copy any "normal" structure `S` to
  `Contiguous!(S)`
