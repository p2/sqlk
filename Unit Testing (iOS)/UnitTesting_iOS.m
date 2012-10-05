//
//  UnitTesting_iOS.m
//  Unit Testing (iOS)
//
//  Created by Pascal Pfiffner on 7/8/12.
//
//

#import "UnitTesting_iOS.h"
#import "sqlk.h"
#import "SQLKTestObject.h"
#import "SQLKStructure.h"
#import "SQLKTableStructure.h"
#import "FMDatabase.h"
#import "FMResultSet.h"


@implementation UnitTesting_iOS


- (void)setUp
{
    [super setUp];
}

- (void)tearDown
{
    [super tearDown];
}


- (void)testStructures
{
	SQLKStructure *structure = [self structureFromXMLNamed:@"database1"];
	
	// is database1 correct?
	STAssertTrue([structure hasTable:@"test_table"], @"test_table does not exist");
	STAssertFalse([structure hasTable:@"vader_table"], @"vader_table miraculously exists");
	STAssertTrue([[structure tableWithName:@"test_table"] hasColumnNamed:@"lastedit_by"], @"test_table does not have lastedit_by");
	
	// create it
	NSString *dbPath = nil;
	FMDatabase *db = [self databaseFromStructure:structure path:&dbPath];
	
	// first row
	STAssertTrue([db executeUpdate:@"INSERT INTO test_table (group_id, type_id, db_number) VALUES ('abc', 'def', 666)"], @"Failed to insert row: %@", [db.lastError localizedDescription]);
	FMResultSet *res = [db executeQuery:@"SELECT * FROM test_table WHERE row_id = 1"];
	STAssertNotNil(res, @"No first row");
	[res next];
	STAssertEqualObjects(@"abc", [res stringForColumn:@"group_id"], @"Wrong group_id");
	STAssertEquals(666, [res intForColumn:@"db_number"], @"Wrong db_number");
	[res close];
	
	// trigger constraint
	STAssertTrue([db executeUpdate:@"INSERT INTO test_table (group_id, type_id, db_number) VALUES ('abc', 'def', 777)"], @"Failed to insert row: %@", [db.lastError localizedDescription]);
	res = [db executeQuery:@"SELECT * FROM test_table WHERE row_id = 1"];
	STAssertFalse([res next], @"Row 1 is still present");
	res = [db executeQuery:@"SELECT * FROM test_table WHERE row_id = 2"];
	STAssertNotNil(res, @"No new first row");
	[res next];
	STAssertEqualObjects(@"def", [res stringForColumn:@"type_id"], @"Wrong type_id");
	STAssertEquals(777, [res intForColumn:@"db_number"], @"Wrong db_number");
	[res close];
	
	// compare to database2 (new column and a new table)
	SQLKStructure *structure2 = [self structureFromXMLNamed:@"database2"];
	STAssertFalse([structure2 isEqualTo:structure error:nil], @"Structure thinks it's the same as the old one");
	
	// update structure
	NSError *error = nil;
	STAssertTrue([structure2 updateDatabaseAt:dbPath dropTables:NO error:&error], @"Failed to update db structure: %@", [error localizedDescription]);
	STAssertTrue([db executeUpdate:@"UPDATE test_table SET db_string = \"Oh hell yes\" WHERE row_id = 2"], @"Failed to insert db_string");
	
	// select an item
	res = [db executeQuery:@"SELECT db_string FROM test_table WHERE row_id = 2"];
	[res next];
	STAssertEqualObjects(@"Oh hell yes", [res stringForColumnIndex:0], @"Wrong db_string");
	[res close];
	
	// clean up
	[db close];
	//NSLog(@"-->  %@", dbPath);
}


- (void)testObject
{
	// SQLKTestObject has 2 database variables
	STAssertTrue(2 == [[SQLKTestObject dbVariables] count], @"Incorrect number of database-based variables");
	STAssertFalse(3 == [[SQLKTestObject dbVariables] count], @"Incorrect number of database-based variables");
}


- (void)testHydration
{
	SQLKStructure *structure = [self structureFromXMLNamed:@"database2"];
	FMDatabase *db = [self databaseFromStructure:structure path:nil];
	
	// create a new object
	SQLKTestObject *row1 = [SQLKTestObject newWithDatabase:db];
	STAssertNotNil(row1, @"Failed to init new object");
	row1.db_number = @28;
	row1.db_string = @"Why so serious?";
	
	// dehydrate
	NSError *error = nil;
	STAssertTrue([row1 dehydrate:&error], @"Failed to dehydrate: %@", [error localizedDescription]);
	
	// update one value
	NSString *theForce = @"The force is with you, always.";
	row1.db_number = @3;
	row1.db_string = theForce;
	STAssertTrue([row1 dehydratePropertiesNamed:[NSSet setWithObject:@"db_string"] error:&error], @"Failed to update db_string: %@", [error localizedDescription]);
	
	// check if we really only updated the string
	FMResultSet *res = [db executeQuery:@"SELECT db_number FROM test_table WHERE row_id = 1"];
	STAssertTrue([res next], @"Failed to execute manual query");
	STAssertEqualObjects(@28, [res objectForColumnIndex:0], @"Should have gotten 28, but got %@", [res objectForColumnIndex:0]);
	
	// hydrate new
	SQLKTestObject *row = [SQLKTestObject newWithDatabase:db];
	STAssertFalse([row hydrate], @"Hydrated despite not having an id");
	row.object_id = @1;
	STAssertTrue([row hydrate], @"Failed to hydrate");
	STAssertEqualObjects(@28, row.db_number, @"Should have gotten 28, but got %@", row.db_number);
	STAssertEqualObjects(theForce, row.db_string, @"Should have gotten \"%@\", but got %@", theForce, row.db_string);
}



#pragma mark - Utilities
/**
 *  Creates a structure from the given XML.
 *  @return A structure created from the given XML
 */
- (SQLKStructure *)structureFromXMLNamed:(NSString *)xmlName
{
	// get the XML
	NSString *xmlPath = [[NSBundle bundleForClass:[self class]] pathForResource:xmlName ofType:@"xml"];
	STAssertNotNil(xmlPath, @"Did not find %@.xml", xmlName);
	SQLKStructure *structure = [SQLKStructure structureFromXML:xmlPath];
	STAssertNotNil(structure, @"Structure from %@.xml failed", xmlName);
	
	return structure;
}

/**
 *  Creates a database from the given structure.
 *  @return A database handle to the database created from the given XML
 */
- (FMDatabase *)databaseFromStructure:(SQLKStructure *)structure path:(NSString * __autoreleasing *)dbPath
{
	// get the cache directory
	NSArray *libraryPaths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
	STAssertTrue(([libraryPaths count] > 0), @"Cache directory not found");
	NSString *path = [[libraryPaths objectAtIndex:0] stringByAppendingPathComponent:@"database.sqlite"];
	STAssertNotNil(path, @"No file to write to");
	
	// create it
	NSFileManager *fm = [NSFileManager new];
	[fm removeItemAtPath:path error:nil];				// we always want to start blank
	BOOL didCreate = NO;
	FMDatabase *db = [structure createDatabaseAt:path useBundleDbIfMissing:nil wasMissing:&didCreate updateStructure:NO error:nil];
	STAssertNotNil(db, @"Failed to create sqlite database");
	STAssertTrue(didCreate, @"Thinks it did not create a database");
	STAssertTrue([db open], @"Failed to open the database");
	
	// return
	if (dbPath) {
		*dbPath = path;
	}
	return db;
}


@end
