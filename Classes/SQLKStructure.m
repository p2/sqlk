//
//  SQLiteStructure.m
//  SQLiteKit
//
//  Created by Pascal Pfiffner on 11.09.10.
//  Copyright 2010 Pascal Pfiffner. All rights reserved.
//	

#import "SQLKStructure.h"
#import "sqlk.h"
#import "SQLKTableStructure.h"
#import "SQLKColumnStructure.h"
#import "FMDatabase.h"


@interface SQLKStructure ()

@property (nonatomic, readwrite, strong) FMDatabase *database;
@property (nonatomic, strong) NSMutableString *parsingString;

- (BOOL)_createWithDatabase:(FMDatabase *)aDB error:(NSError **)error;
- (void)parseXMLData:(NSData *)data;

@end


@implementation SQLKStructure

@synthesize database = _database;
@synthesize tables = _tables;
@synthesize parsingTables, parsingTable, parsingTableColumns, parsingTableConstraints, parsingString;




/**
 *	Reads an XML file representing a database and instantiates a structure
 *	@return A new instance
 */
+ (SQLKStructure *)structureFromXML:(NSURL *)xmlPath
{
	SQLKStructure *s = [SQLKStructure new];
	
	// database accessible?
	if ([s canAccessURL:xmlPath]) {
		NSError *error = nil;
		if ([s parseStructureFromXML:xmlPath error:&error]) {
			return s;
		}
		DLog(@"%@", [error localizedDescription]);
	}
	
	return nil;
}

/**
 *	@todo Not yet implemented
 */
+ (SQLKStructure *)structureFromArchive:(NSURL *)archiveUrl
{
	DLog(@"Implement me to load from archive at %@", archiveUrl);
	return [self new];
}

/**
 *	Instantiates an object by reading the structure from the SQLite database
 *	@todo Should take an NSError argument
 */
+ (SQLKStructure *)structureFromDatabase:(NSURL *)dbPath
{
	SQLKStructure *s = [SQLKStructure new];
	NSString *errorString = nil;
	
	// database accessible?
	if ([s canAccessURL:dbPath]) {
		NSFileManager *fm = [NSFileManager defaultManager];
		if ([fm fileExistsAtPath:[dbPath path]]) {
			
			// got a file, open the database
			FMDatabase *db = [FMDatabase databaseWithPath:[dbPath path]];
			//db.logsErrors = YES;
			//db.traceExecution = YES;
			if ([db open]) {
				//NSError *myError = nil;
				
				// select tables
				FMResultSet *masterSet = [db executeQuery:@"SELECT sql FROM `sqlite_master` WHERE `type` = 'table'"];
				if (![db hadError]) {
					NSMutableArray *newTables = [NSMutableArray array];
					
					// parse table SQL
					while ([masterSet next]) {
						SQLKTableStructure *tblStructure = [SQLKTableStructure tableFromQuery:[masterSet stringForColumn:@"sql"]];
						if (tblStructure) {
							tblStructure.structure = s;
							[newTables addObject:tblStructure];
						}
					}
					
					s.database = db;
					s.tables = newTables;
					
					if (![db close]) {
						errorString = [NSString stringWithFormat:@"Could not close database at %@: (%d) %@", dbPath, [db lastErrorCode], [db lastErrorMessage]];
					}
				}
				else {
					errorString = [NSString stringWithFormat:@"SQLite error %d: %@", [db lastErrorCode], [db lastErrorMessage]];
				}
			}
			else {
				errorString = [NSString stringWithFormat:@"Could not open database at %@: (%d) %@", dbPath, [db lastErrorCode], [db lastErrorMessage]];
			}
		}
		else {
			errorString = [NSString stringWithFormat:@"There is no file at %@, can't initialize from database", dbPath];
			s = nil;
		}
	}
	else {
		errorString = [NSString stringWithFormat:@"Can't access database at %@", dbPath];
		s = nil;
	}
	
	// error reporting
	if (errorString) {
		DLog(@"Error: %@", errorString);
	}
	
	return s;
}



#pragma mark - NSCoding
- (id)initWithCoder:(NSCoder *)decoder
{
	if ((self = [super init])) {
		self.tables = [decoder decodeObjectForKey:@"tables"];
	}
	return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder
{
	[encoder encodeObject:_tables forKey:@"tables"];
}



#pragma mark - Creating a database
/**
 *	Recreates the receiver's structure in an SQLite database at given URL
 */
- (FMDatabase *)createDatabaseAt:(NSURL *)dbPath error:(NSError **)error
{
	if ([_tables count] > 0) {
		
		// can we access the database file?
		if ([self canAccessURL:dbPath]) {
			NSFileManager *fm = [NSFileManager defaultManager];
			if (![fm fileExistsAtPath:[dbPath path]]) {
				
				// should be fine, open the database
				FMDatabase *db = [FMDatabase databaseWithPath:[dbPath path]];
				if ([db open]) {
					if ([self _createWithDatabase:db error:error]) {
						return db;
					}
					[db close];
				}
				else {
					NSString *errorString = [NSString stringWithFormat:@"Could not open database at %@: (%d) %@", dbPath, [db lastErrorCode], [db lastErrorMessage]];
					SQLK_ERR(error, errorString, 621)
				}
			}
			else {
				NSString *errorString = [NSString stringWithFormat:@"A file already resides at %@, can't create a new database", dbPath];
				SQLK_ERR(error, errorString, 0)
			}
		}
		else {
			NSString *errorString = [NSString stringWithFormat:@"Can't access database at %@", dbPath];
			SQLK_ERR(error, errorString, 0)
		}
	}
	else {
		SQLK_ERR(error, @"We first need tables in order to create a database", 630)
	}
	
	return nil;
}

/**
 *	Recreates the receiver's structure in a memory database
 */
- (FMDatabase *)createMemoryDatabaseWithError:(NSError **)error
{
	// open the database in memory
	if ([_tables count] > 0) {
		FMDatabase *db = [FMDatabase databaseWithPath:nil];
		if ([db open]) {
			if ([self _createWithDatabase:db error:error]) {
				return db;
			}
		}
		else {
			NSString *errorString = [NSString stringWithFormat:@"Could not open memory database at: (%d) %@", [db lastErrorCode], [db lastErrorMessage]];
			SQLK_ERR(error, errorString, 623)
		}
	}
	else {
		SQLK_ERR(error, @"We first need tables in order to create a database", 630)
	}
	
	return nil;
}

/**
 *	Recreates the receiver's structure in the given database
 */
- (BOOL)_createWithDatabase:(FMDatabase *)db error:(NSError **)error
{
	if (!db) {
		SQLK_ERR(error, @"No database given", 0)
		return NO;
	}
	if (![db open]) {
		SQLK_ERR(error, @"Failed to open the database", 0)
		return NO;
	}
	if ([_tables count] < 1) {
		SQLK_ERR(error, @"There are no tables", 0)
		return NO;
	}
	
	// **** go ahead, make my day errrh... tables!
	NSError *myError = nil;
	[db beginTransaction];
	for (SQLKTableStructure *table in _tables) {
		if (![table createInDatabase:db error:&myError]) {
			[db rollback];
			[db close];
			
			NSString *errorString = [NSString stringWithFormat:@"Failed to create table \"%@\" in memory database: %@", table.name, [myError userInfo]];
			SQLK_ERR(error, errorString, 631)
			return NO;
		}
	}
	[db commit];
	// ****
	
	self.database = db;
	
	return YES;
}



#pragma mark - Verifying and Updating
/**
 *	Compares a database structure to the receiver's structure.
 *	Compares all tables and the tables' structures and reports missing and superfluuous tables.
 */
- (BOOL)isEqualTo:(SQLKStructure *)otherDB error:(NSError **)error
{
	if (otherDB) {
		NSMutableArray *existingTables = [_tables mutableCopy];
		NSMutableArray *otherTables = [otherDB.tables mutableCopy];
		NSMutableArray *errors = [NSMutableArray array];
		
		// compare table structures
		if ([existingTables count] > 0) {
			for (SQLKTableStructure *ts in otherDB.tables) {
				NSError *myError = nil;
				if (![self hasTableWithStructure:ts error:&myError]) {
					[errors addObject:myError];
				}
				else {
					[existingTables removeObject:ts];
					[otherTables removeObject:ts];
				}
			}
		}
		
		// superfluuous tables?
		if ([existingTables count] > 0) {
			for (SQLKTableStructure *sup in existingTables) {
				NSError *myError = nil;
				NSString *errorString = [NSString stringWithFormat:@"Superfluuous table: %@", sup.name];
				SQLK_ERR(&myError, errorString, 672)
				[errors addObject:myError];
			}
		}
		
		// missing tables?
		if ([otherTables count] > 0) {
			for (SQLKTableStructure *ts in self.tables) {
				NSError *myError = nil;
				if (![otherDB hasTableWithStructure:ts error:&myError]) {
					[errors addObject:myError];
				}
			}
		}
		
		// report mismatch errors
		if ([errors count] > 0) {
			NSString *errorString = [NSString stringWithFormat:@"%d errors occurred while comparing structure. See \"SQLKErrors\" in this errors' userInfo.", [errors count]];
			DLog(@"Error: %@", errorString);
			if (NULL != error) {
				NSDictionary *userDict = [NSDictionary dictionaryWithObjectsAndKeys:errorString, NSLocalizedDescriptionKey, errors, @"SQLKErrors", nil];
				*error = [NSError errorWithDomain:NSCocoaErrorDomain code:674 userInfo:userDict];
			}
			
			return NO;
		}
		else {
			return YES;
		}
	}
	
	// missing other database
	else {
		SQLK_ERR(error, @"No comparison database structure given", 670);
	}
	
	return NO;
}

/**
 *	Updates the database to the receiver's structure
 *	A structure is created from the existing database and then each table is compared to the receiver's structure. Missing columns are added to tables,
 *	superfluuous tables are deleted if "dropCol" is YES, and the same applies to tables.
 *	@param dbPath A NSURL to an sqlite database
 *	@param dropColumns Whether it is allowed to drop no longer existing columns
 *	@param dropTables Whether it is allowed to drop no longer existing tables
 *	@param error A pointer to an error object
 */
- (BOOL)updateDatabaseAt:(NSURL *)dbPath allowToDropColumns:(BOOL)dropColumns tables:(BOOL)dropTables error:(NSError **)error
{
	SQLKStructure *existingDb = [SQLKStructure structureFromDatabase:dbPath];
	FMDatabase *db = existingDb.database;
	
	if ([db open]) {
		[db beginTransaction];
		NSMutableArray *existingTables = [existingDb.tables mutableCopy];
		
		// add new tables and update existing ones
		if ([_tables count] > 0) {
			for (SQLKTableStructure *myTable in _tables) {
				SQLKTableStructure *existing = [existingDb tableWithName:myTable.name];
				
				// table exists, do update if needed
				if (existing) {
					if (![existing isEqualToTable:myTable error:nil]) {
						if (![existing updateTableWith:myTable dropUnusedColumns:dropColumns error:error]) {
							[db rollback];
							return NO;
						}
					}
					[existingTables removeObject:existing];
				}
				
				// table is missing, create
				else {
					if (![myTable createInDatabase:db error:error]) {
						[db rollback];
						return NO;
					}
				}
			}
		}
		
		// superfluuous tables?
		if ([existingTables count] > 0) {
			if (dropTables) {
				for (SQLKTableStructure *superfluuous in existingTables) {
					if (![superfluuous dropFromDatabase:db error:error]) {
						[db rollback];
						return NO;
					}
				}
			}
			else {
				DLog(@"There are %d superfluuous tables, but we're not allowed to drop them", [existingTables count]);
			}
		}
		
		if (![db commit]) {
			NSString *errorString = [NSString stringWithFormat:@"Failed to commit transaction: (%d) %@", [db lastErrorCode], [db lastErrorMessage]];
			SQLK_ERR(error, errorString, 625)
			return NO;
		}
		return YES;
	}
	
	// missing other database
	else if (db) {
		NSString *errorString = [NSString stringWithFormat:@"Could not open database: (%d) %@", [db lastErrorCode], [db lastErrorMessage]];
		SQLK_ERR(error, errorString, 621)
	}
	else if (existingDb) {
		SQLK_ERR(error, @"Comparison structure does not have a database", 620);
	}
	else {
		SQLK_ERR(error, @"No comparison database structure given", 670);
	}
	
	return NO;
}

/**
 *	@return YES if the database contains a table with this name
 */
- (BOOL)hasTable:(NSString *)tableName
{
	for (SQLKTableStructure *table in _tables) {
		if ([tableName isEqualToString:table.name]) {
			return YES;
		}
	}
	return NO;
}

/**
 *	Checks whether the database has a table of given structure
 */
- (BOOL)hasTableWithStructure:(SQLKTableStructure *)tableStructure error:(NSError **)error
{
	if (tableStructure) {
		for (SQLKTableStructure *table in _tables) {
			if ([table.name isEqualToString:tableStructure.name]) {
				return [table isEqualToTable:tableStructure error:error];
			}
		}
	}
	
	// no such table
	NSString *errorString = [NSString stringWithFormat:@"No table with the structure of table named \"%@\"", tableStructure.name];
	SQLK_ERR(error, errorString, 671)
	
	return NO;
}



#pragma mark - Table Handling
/**
 *	Returns the structure of the table with given name.
 *	Infers the table structure from an SQL query upon first call
 */
- (SQLKTableStructure *)tableWithName:(NSString *)tableName
{
	if ([tableName length] < 1) {
		DLog(@"No tablename given");
		return nil;
	}
	
	// check our table array if we already have it
	if (_tables) {
		for (SQLKTableStructure *table in _tables) {
			if ([table.name isEqualToString:tableName]) {
				return table;
			}
		}
		return nil;
	}
	
	// not yet instantiated, fetch from sqlite
	if (![_database open]) {
		if (_database) {
			DLog(@"Could not open database: (%d) %@", [_database lastErrorCode], [_database lastErrorMessage]);
		}
		else {
			DLog(@"I don't have a handle to a database, can't look for table named \"%@\"", tableName);
		}
		return nil;
	}
	NSString *errorString = nil;
	
	// fetch table sql
	NSString *tableStructQuery = [NSString stringWithFormat:@"SELECT sql FROM sqlite_master WHERE type = 'table' AND name = '%@'", tableName];
	FMResultSet *masterSet = [_database executeQuery:tableStructQuery];
	if (![_database hadError]) {
		[masterSet next];
		
		// create a table structure from sql
		NSString *sql = [masterSet stringForColumn:@"sql"];
		SQLKTableStructure *tblStructure = [SQLKTableStructure tableFromQuery:sql];
		if (tblStructure) {
			tblStructure.structure = self;
			
			// add to tables
			if ([_tables count] > 0) {
				NSMutableArray *newTables = [NSMutableArray arrayWithArray:_tables];
				[newTables addObject:tblStructure];
				self.tables = newTables;
			}
			else {
				self.tables = [NSArray arrayWithObject:tblStructure];
			}
		}
		else {
			errorString = [NSString stringWithFormat:@"Failed to parse sql for table structure: %@", sql];
		}
	}
	else {
		errorString = [NSString stringWithFormat:@"SQLite error %d when fetching table description: %@", [_database lastErrorCode], [_database lastErrorMessage]];
	}
	
	// log errors
	if (errorString) {
		DLog(@"Error in tableWithName: %@", errorString);
	}
	
	return nil;
}



#pragma mark - XML Parsing
/**
 *	Parses an XML file at given path to create a database structure.
 *	This method will NOT perform asynchronous parsing as it can't return YES or NO before parsing ends.
 */
- (BOOL)parseStructureFromXML:(NSURL *)xmlUrl error:(NSError * __autoreleasing*)error
{
	// read data
	__autoreleasing NSError *parseError = nil;
	//NSData *xmlData = [NSData dataWithContentsOfURL:xmlUrl options:NSDataReadingUncached error:&parseError];	// NSDataReadingUncached is iOS 4.+ only
	NSData *xmlData = [NSData dataWithContentsOfURL:xmlUrl options:2 error:&parseError];
	
	// parse
	if (xmlData) {
		self.parsingTables = [NSMutableArray array];
		[self parseXMLData:xmlData];
		
		return YES;			// on asyncParsing, we don't yet know whether we will succeed!
	}
	
	DLog(@"Could not read XML: %@", [parseError userInfo]);
	if (NULL != error) {
		*error = parseError;
	}
	return NO;
}


/**
 *	The parsing workhorse
 */
- (void)parseXMLData:(NSData *)data
{	
	@autoreleasepool {
		
		// create a parser
		NSXMLParser *parser = [[NSXMLParser alloc] initWithData:data];
		[parser setDelegate:self];
		
		[parser setShouldProcessNamespaces:NO];
		[parser setShouldReportNamespacePrefixes:NO];
		[parser setShouldResolveExternalEntities:NO];
		
		// parse
		[parser parse];
		NSError *parseError = [parser parserError];
		
		// notify us
		[self performSelectorOnMainThread:@selector(didParseData:) withObject:parseError waitUntilDone:YES];
	}
}

- (void)didParseData:(NSError *)error
{
	if (error) {
		DLog(@"Parse Error: %@", [error userInfo]);
	}
	
	self.tables = parsingTables;
	self.parsingTables = nil;
}


#pragma mark NSXMLParserDelegate
/*
- (void)parserDidStartDocument:(NSXMLParser *)parser
{
}	//	*/


/// starting an element
- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName attributes:(NSDictionary *)attributeDict
{
	if (qName) {
		elementName = qName;
	}
	
	// table
	if ([elementName isEqualToString:@"table"]) {
		self.parsingTable = nil;
		NSString *tblName = [attributeDict valueForKey:@"name"];
		if ([tblName length] > 0) {
			if ([self hasTable:tblName]) {
				duplicateTable = YES;
				DLog(@"There already is a table named \"%@\" in this structure, skipping", [attributeDict valueForKey:@"name"]);
			}
			else {
				duplicateTable = NO;
				self.parsingTable = [SQLKTableStructure tableForStructure:self];
				parsingTable.name = tblName;
				self.parsingTableColumns = [NSMutableArray array];
			}
		}
		else {
			DLog(@"Encountered a table element without name, skipping");
		}
	}
	
	// column
	else if ([elementName isEqualToString:@"column"]) {
		if (parsingTable) {
			SQLKColumnStructure *column = [SQLKColumnStructure columnForTable:parsingTable];
			column.name = [attributeDict valueForKey:@"name"];
			column.type = [attributeDict valueForKey:@"type"];
			column.isPrimaryKey = [[attributeDict valueForKey:@"primary"] boolValue];
			column.isUnique = [[attributeDict valueForKey:@"unique"] boolValue];
			column.defaultString = [attributeDict valueForKey:@"default"];
			column.defaultNeedsQuotes = [[attributeDict valueForKey:@"quote_default"] boolValue];
			
			[parsingTableColumns addObject:column];
		}
		else if (!duplicateTable) {
			DLog(@"Encountered a column element without a table in place. Generate an error!");
		}
	}
	
	// constraint
	else if ([elementName isEqualToString:@"constraint"]) {
		self.parsingString = [NSMutableString new];
	}
}


/// called when the parser has a string
- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string
{
	[parsingString appendString:string];
}

	
/// the parser ended an element
- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName
{
	if (qName) {
		elementName = qName;
	}
	
	// table
	if ([elementName isEqualToString:@"table"]) {
		if (parsingTable) {
			parsingTable.columns = parsingTableColumns;
			self.parsingTableColumns = nil;
			
			if ([parsingTableConstraints count] > 0) {
				parsingTable.constraints = parsingTableConstraints;
			}
			
			[parsingTables addObject:parsingTable];
			self.parsingTable = nil;
		}
		self.parsingTableConstraints = nil;
	}
	
	// constraint
	else if ([elementName isEqualToString:@"constraint"]) {
		if ([parsingString length] > 0) {
			if (!parsingTableConstraints) {
				self.parsingTableConstraints = [NSMutableArray array];
			}
			[parsingTableConstraints addObject:parsingString];
		}
		self.parsingString = nil;
	}
}


/* gets called on error and on abort instead of parserDidEndDocument
- (void)parser:(NSXMLParser *)parser parseErrorOccurred:(NSError *)parseError
{
}	//	*/

/* will NOT be called when we abort!
- (void)parserDidEndDocument:(NSXMLParser *)parser
{
}	//	*/



#pragma mark - Utilities
/**
 *	Currently only returns YES for file URLs
 */
- (BOOL)canAccessURL:(NSURL *)dbPath
{
	return [dbPath isFileURL];
}

/**
 *	Currently simply returns the argument URL
 */
- (NSURL *)backupDatabaseAt:(NSURL *)dbPath
{
	return dbPath;
}


/**
 *	Logs the database structure
 */
- (void)log
{
	NSLog(@"%@", self);
	for (SQLKTableStructure *table in _tables) {
		[table log];
	}
}

- (NSString *) description
{
	return [NSString stringWithFormat:@"%@ <%p> %i tables", NSStringFromClass([self class]), self, [_tables count]];
}


@end
