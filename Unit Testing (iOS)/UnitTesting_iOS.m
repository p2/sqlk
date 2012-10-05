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
	NSString *xmlPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"database1" ofType:@"xml"];
	STAssertNotNil(xmlPath, @"Did not find database1.xml");
	SQLKStructure *structure = [SQLKStructure structureFromXML:xmlPath];
	STAssertNotNil(structure, @"Structure from database1.xml failed");
	
	// is database1 correct?
	STAssertTrue([structure hasTable:@"test_table"], @"test_table does not exist");
	STAssertFalse([structure hasTable:@"vader_table"], @"vader_table miraculously exists");
	STAssertTrue([[structure tableWithName:@"test_table"] hasColumnNamed:@"lastedit_by"], @"test_table does not have lastedit_by");
	
	// create it
	NSArray *libraryPaths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
	STAssertTrue(([libraryPaths count] > 0), @"Library directory not found");
	NSString *dbPath = [[libraryPaths objectAtIndex:0] stringByAppendingPathComponent:@"database.sqlite"];
	STAssertNotNil(dbPath, @"No library to write to");
	
	NSFileManager *fm = [NSFileManager new];
	[fm removeItemAtPath:dbPath error:nil];				// will be removed at the end of this method, but this makes it easier to debug and no harm is done
	BOOL didCreate = NO;
	FMDatabase *db = [structure createDatabaseAt:dbPath useBundleDbIfMissing:nil wasMissing:&didCreate updateStructure:NO error:nil];
	STAssertNotNil(db, @"Failed to create sqlite database");
	STAssertTrue(didCreate, @"Thinks it did not create a database");
	STAssertTrue([db open], @"Failed to open the database");
	
	// first row
	STAssertTrue([db executeUpdate:@"INSERT INTO test_table (group_id, type_id, value) VALUES ('abc', 'def', 666)"], @"Failed to insert row: %@", [db.lastError localizedDescription]);
	FMResultSet *res = [db executeQuery:@"SELECT * FROM test_table WHERE row_id = 1"];
	STAssertNotNil(res, @"No first row");
	[res next];
	STAssertEqualObjects(@"abc", [res stringForColumn:@"group_id"], @"Wrong group_id");
	STAssertEquals(666, [res intForColumn:@"value"], @"Wrong value");
	[res close];
	
	// trigger constraint
	STAssertTrue([db executeUpdate:@"INSERT INTO test_table (group_id, type_id, value) VALUES ('abc', 'def', 777)"], @"Failed to insert row: %@", [db.lastError localizedDescription]);
	res = [db executeQuery:@"SELECT * FROM test_table WHERE row_id = 1"];
	STAssertFalse([res next], @"Row 1 is still present");
	res = [db executeQuery:@"SELECT * FROM test_table WHERE row_id = 2"];
	STAssertNotNil(res, @"No new first row");
	[res next];
	STAssertEqualObjects(@"def", [res stringForColumn:@"type_id"], @"Wrong type_id");
	STAssertEquals(777, [res intForColumn:@"value"], @"Wrong value");
	[res close];
	
	// compare to database2 (new column and a new table)
	NSString *xmlPath2 = [[NSBundle bundleForClass:[self class]] pathForResource:@"database2" ofType:@"xml"];
	STAssertNotNil(xmlPath2, @"Did not find database2.xml");
	SQLKStructure *structure2 = [SQLKStructure structureFromXML:xmlPath2];
	STAssertNotNil(structure2, @"Structure from database2.xml failed");
	STAssertFalse([structure2 isEqualTo:structure error:nil], @"Structure thinks it's the same as the old one");
	
	// update structure
	STAssertTrue([structure2 updateDatabaseAt:dbPath dropTables:NO error:nil], @"Failed to update db structure");
	STAssertTrue([db executeUpdate:@"UPDATE test_table SET description = \"Oh hell yes\" WHERE row_id = 2"], @"Failed to insert description");
	res = [db executeQuery:@"SELECT description FROM test_table WHERE row_id = 2"];
	[res next];
	STAssertEqualObjects(@"Oh hell yes", [res stringForColumnIndex:0], @"Wrong description");
	[res close];
	
	// clean up
	[db close];
	NSLog(@"-->  %@", dbPath);
	[fm removeItemAtPath:dbPath error:nil];
}


- (void)testObject
{
	// SQLKTestObject has 2 database variables
	STAssertTrue(2 == [[SQLKTestObject dbVariables] count], @"Incorrect number of database-based variables");
	STAssertFalse(3 == [[SQLKTestObject dbVariables] count], @"Incorrect number of database-based variables");
}


@end
