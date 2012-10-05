SQLite Kit
==========

This SQLite kit aims to ease working with SQLite databases in Cocoa by providing :

* An SQLiteObject, distantly related to NSManagedObject for CoreData
* SQLK structures, easing database generation and updating from XML files

The kit tries to complement [fmdb], the awesome SQLite Cocoa wrapper by Gus Mueller. The project uses ARC, so if you haven't yet moved to ARC you're on your own.

### License ###

This project is released under the [Apache 2.0 license][apache], because why not. There is no NOTICE file so you don't need to mention anything when using the kit.

[fmdb]: https://github.com/ccgus/fmdb
[apache]: http://www.apache.org/licenses/LICENSE-2.0.html


Using SQLiteObject
------------------

For each table that you have, you create a subclass of SQLiteObject. You need to do at lest four things:

* Create a subclass
* Add properties
* Override `tableName`
* Override `tableKey`


### Adding Properties ###

You can add as many properties to the subclass as you'd like. To have the object recognize a property as one that is stored in the database, you synthesize it to **have an underscore at the end**, for example:

    @synthesize db_prop = db_prop_;

This makes the object automatically write and read this property from the database on `hydrate:` and `dehydrate`.


### Overriding tableName and tableKey ###

You override these class methods to tell the objects into which tables it belongs, like so:

```objective-c
+ (NSString *)tableName
{
    return @"test_table";
}

+ (NSString *)tableKey
{
    return @"row_id";
}
```


### Using SQLiteObject ###

After these three steps you can now use your objects easily:

#### Writing to the database ####

```objective-c
FMDatabase *db = [FMDatabase databaseWithPath:path-to-sqlite];
MyObject *obj = [MyObject newWithDatabase:db];
obj.db_prop = @"Hello World";

NSError *error = nil
if (![db dehydrate:&error]) {
    NSLog(@"Dehydrate failed: %@", [error localizedDescription]);
}
```

#### Reading from the database ####

```objective-c
FMDatabase *db = [FMDatabase databaseWithPath:path-to-sqlite];
MyObject *obj = [MyObject newWithDatabase:db];
obj.object_id = @1;

if (![db hydrate]) {
    NSLog(@"Hydrate failed");
}
```


Using the kit
-------------

The rest of the kit provides ways to create and update your SQLite database. If you want to use this functionality you can either use it as a subproject in your Xcode workspace or add the files like they were your own. Then link your app with:

* libsqlite3.dylib
* libsqlk.a

The kit can read database structures from an XML file and create a database that represents this schema, and even update existing databases to match the schema, within the constraints of SQLite. Remember, SQLite can not rename or delete table columns.


### XML Schema ###

Here's an example schema:

```xml
<database>
    <table name="objects">
        <column name="object_id" type="varchar" primary="1" />
        <column name="type" type="varchar" />
        <column name="title" type="varchar" default="None" quote_default="1" />
        <column name="year" type="int" />
        <column name="lastedit" type="timestamp" default="CURRENT_TIMESTAMP" />
        <constraint>UNIQUE (title, year) ON CONFLICT REPLACE</constraint>
    </table>
</database>
```

#### database ####

The XML root object, attributes are not parsed.

Children:

* table

#### table ####

Describes one table.

Attributes:

* `name` _mandatory_, any valid SQLite table name
* `old_names` _potentially_. **NOT IMPLEMENTED**; could be a good way to rename tables

Children:

* column
* constraint

#### column ####

Describes one table column, doesn't take child nodes.

Attributes:

* `name` _mandatory_, any valid SQLite column name
* `type` _mandatory_, any valid SQLite data type
* `primary` _optional_, a **bool** indicating whether this is the primary key
* `unique` _optional_, a **bool** indicating whether this column should be unique
* `default` _optional_, the column's default value
* `quote_default` _optional_, a **bool** indicating whether the value in `default` needs to be put in quotes (i.e. is a string, not a SQLite variable)

#### constraint ####

Describes a table constraint. The node takes no attributes and the node content should be a valid SQLite constraint.



To do
-----

A lot! If you like the project and want to help out, fork, fix and send me pull requests.


### SQLiteObject ###

- Support fetching sub-properties of many objects, e.g. for listing purposes. I currently do that with a `+listQuery` object that only fetches a few properties, having this built-in would be nice.


### XML ###

- Write an actual XSD
- Support more SQLite features


### Better column parsing (from .sqlite) ###

- Correctly parse DEFAULT values (currently regards everything after DEFAULT until the next comma as default)
- Parse ON CONFLICT statements for UNIQUE and PRIMARY KEY statements (are currently ignored)
- Support COLLATE statements
