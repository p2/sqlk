SQLite Kit
==========

This SQLite kit aims to ease working with SQLite databases in Cocoa by providing :

* An SQLiteObject, distantly related to NSManagedObject for CoreData
* SQLK structures, easing database generation and updating from XML files

The kit tries to complement **[fmdb][]**, the awesome SQLite Cocoa wrapper by Gus Mueller.

[fmdb]: https://github.com/ccgus/fmdb


Using SQLiteObject
------------------

...


Using the kit
-------------

...

- libsqlite3.dylib


To do
-----

### Better column parsing ###

- Correctly parse DEFAULT values (currently regards everything after DEFAULT until the next comma as default)
- Parse ON CONFLICT statements for UNIQUE and PRIMARY KEY statements (are currently ignored)
- Support COLLATE statements
