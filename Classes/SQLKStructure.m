//
//  SQLiteStructure.m
//  SQLiteKit
//
//  Created by Pascal Pfiffner on 11.09.10.
//  Copyright 2010 Pascal Pfiffner. All rights reserved.
//	

#import "SQLKStructure.h"
#import "SQLKTableStructure.h"
#import "SQLKColumnStructure.h"
#import "FMDatabase.h"


@interface SQLKStructure ()

@property (nonatomic, retain) NSMutableString *parsingString;

- (BOOL)_createWithDatabase:(FMDatabase *)aDB error:(NSError **)error;
- (void) parseXMLData:(NSData *)data;

@end


@implementation SQLKStructure

@synthesize tables;
@synthesize path;
@synthesize asyncParsing;
@synthesize parsingTables, parsingTable, parsingTableColumns, parsingTableConstraints, parsingString;


- (void)dealloc
{
	[tables release];
	[path release];
	self.parsingTables = nil;
	self.parsingTable = nil;
	[parsingTableColumns release];
	[parsingTableConstraints release];
	[parsingString release];
	
	[super dealloc];
}


/**
 *	Returns a plain new instance
 */
+ (SQLKStructure *)structure
{
	return [[self new] autorelease];
}

/**
 *	Not yet implemented
 */
+ (SQLKStructure *)structureFromArchive:(NSURL *)archiveUrl
{
	DLog(@"Implement me to load from archive at %@", archiveUrl);
	return [[[self alloc] init] autorelease];
}

/**
 *	Instantiates an object by reading the structure from the SQLite database
 *	@todo Should take an NSError argument
 */
+ (SQLKStructure *)structureFromDatabase:(NSURL *)dbPath
{
	SQLKStructure *s = [[SQLKStructure new] autorelease];
	s.path = dbPath;
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
							[newTables addObject:tblStructure];
						}
					}
					
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
	[encoder encodeObject:tables forKey:@"tables"];
}



#pragma mark - Creating a database
/**
 *	Recreates the receiver's structure in an SQLite database at given URL
 */
- (FMDatabase *)createDatabaseAt:(NSURL *)dbPath error:(NSError **)error
{
	if ([tables count] > 0) {
		
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
					
					NSString *errorString = [NSString stringWithFormat:@"Could not close memory database at: (%d) %@", [db lastErrorCode], [db lastErrorMessage]];
					SQLK_ERR(error, errorString, 0)
				}
				else {
					NSString *errorString = [NSString stringWithFormat:@"Could not open database at %@: (%d) %@", dbPath, [db lastErrorCode], [db lastErrorMessage]];
					SQLK_ERR(error, errorString, 0)
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
		SQLK_ERR(error, @"We first need tables in order to create a database", 0)
	}
	
	return nil;
}

/**
 *	Recreates the receiver's structure in a memory database
 */
- (FMDatabase *)createMemoryDatabaseWithError:(NSError **)error
{
	// open the database in memory
	if ([tables count] > 0) {
		FMDatabase *db = [FMDatabase databaseWithPath:nil];
		if ([db open]) {
			if ([self _createWithDatabase:db error:error]) {
				return db;
			}
		}
		else {
			NSString *errorString = [NSString stringWithFormat:@"Could not open memory database at: (%d) %@", [db lastErrorCode], [db lastErrorMessage]];
			SQLK_ERR(error, errorString, 0)
		}
	}
	else {
		SQLK_ERR(error, @"We first need tables in order to create a database", 0)
	}
	
	return nil;
}

/**
 *	Recreates the receiver's structure in the given database
 */
- (BOOL)_createWithDatabase:(FMDatabase *)aDB error:(NSError **)error
{
	if (!aDB) {
		SQLK_ERR(error, @"No database given", 0)
		return NO;
	}
	if (![aDB open]) {
		SQLK_ERR(error, @"Failed to open the database", 0)
		return NO;
	}
	
	// **** go ahead, make my day errrh... tables!
	NSError *myError = nil;
	[aDB beginTransaction];
	for (SQLKTableStructure *table in tables) {
		if (![table createInDatabase:aDB error:&myError]) {
			[aDB rollback];
			[aDB close];
			
			NSString *errorString = [NSString stringWithFormat:@"Failed to create table \"%@\" in memory database: %@", table.name, [myError userInfo]];
			SQLK_ERR(error, errorString, 667)
			return NO;
		}
	}
	[aDB commit];
	// ****
	
	return YES;
}



#pragma mark - Verifying
/**
 *	Compares a database structure to the receiver's structure. Compares all tables and the tables' structures and reports missing and superfluuous tables.
 */
- (BOOL)isEqualToDb:(SQLKStructure *)otherDB error:(NSError **)error
{
	if (otherDB) {
		NSMutableArray *existingTables = [tables mutableCopy];
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
				}
			}
		}
		
		// superfluuous tables?
		if ([existingTables count] > 0) {
			for (SQLKTableStructure *sup in existingTables) {
				NSString *errorString = [NSString stringWithFormat:@"Superfluuous table: %@", sup.name];
				NSDictionary *userDict = [NSDictionary dictionaryWithObject:errorString forKey:NSLocalizedDescriptionKey];
				NSError *anError = [NSError errorWithDomain:NSCocoaErrorDomain code:670 userInfo:userDict];
				[errors addObject:anError];
			}
		}
		[existingTables release];
		
		// report specific errors
		if ([errors count] > 0) {
			NSString *errorString = [NSString stringWithFormat:@"%d errors occurred while comparing structure to \"%@\". See \"SQLKErrors\" in this errors' userInfo.", [errors count], self.path];
			DLog(@"Error: %@", errorString);
			if (NULL != error) {
				NSDictionary *userDict = [NSDictionary dictionaryWithObjectsAndKeys:errorString, NSLocalizedDescriptionKey, errors, @"SQLKErrors", nil];
				*error = [NSError errorWithDomain:NSCocoaErrorDomain code:671 userInfo:userDict];
			}
			
			return NO;
		}
		else {
			return YES;
		}
	}
	
	// basic error
	else {
		NSString *errorString = [NSString stringWithFormat:@"There is no database at location: %@", self.path];
		DLog(@"Error: %@", errorString);
		if (NULL != error) {
			NSDictionary *userDict = [NSDictionary dictionaryWithObject:errorString forKey:NSLocalizedDescriptionKey];
			*error = [NSError errorWithDomain:NSCocoaErrorDomain code:672 userInfo:userDict];
		}
	}
	
	return NO;
}

/**
 *	Updates the database
 *	@todo implement
 */
- (BOOL)updateDatabaseAt:(NSURL *)dbPath allowToDropColumns:(BOOL)dropCol tables:(BOOL)dropTables error:(NSError **)error
{
	SQLKStructure *otherDB = [SQLKStructure structureFromDatabase:dbPath];
	if (![otherDB isEqualToDb:self error:error]) {
		DLog(@"Should now update database at %@ because it does not meet our structure", dbPath);
		return NO;
	}
	return YES;
}

/**
 *	Returns YES if the database contains a table with this name
 */
- (BOOL)hasTable:(NSString *)tableName
{
	for (SQLKTableStructure *table in tables) {
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
		for (SQLKTableStructure *table in tables) {
			if ([table.name isEqualToString:tableStructure.name]) {
				return [table isEqualToTable:tableStructure error:error];
			}
		}
	}
	
	if (error) {
		NSString *errorString = [NSString stringWithFormat:@"No table named \"%@\"", tableStructure.name];
		NSDictionary *userDict = [NSDictionary dictionaryWithObject:errorString forKey:NSLocalizedDescriptionKey];
		*error = [NSError errorWithDomain:NSCocoaErrorDomain code:675 userInfo:userDict];
	}
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
	
	// see whether we already have the table
	for (SQLKTableStructure *table in tables) {
		if ([table.name isEqualToString:tableName]) {
			return table;
		}
	}
	
	// not yet instantiated, fetch from sqlite
	if (path) {
		NSString *errorString = nil;
		DLog(@"2");
		
		// open the database
		FMDatabase *db = [FMDatabase databaseWithPath:[path path]];
		if ([db open]) {
			
			// fetch table sql
			NSString *tableStructQuery = [NSString stringWithFormat:
										  @"SELECT sql FROM sqlite_master WHERE type = 'table' AND name = '%@'", tableName];
			FMResultSet *masterSet = [db executeQuery:tableStructQuery];
			if (![db hadError]) {
				[masterSet next];
				
				// create a table structure from sql
				NSString *sql = [masterSet stringForColumn:@"sql"];
				SQLKTableStructure *tblStructure = [SQLKTableStructure tableFromQuery:sql];
				if (tblStructure) {
					
					// add to tables
					if ([tables count] > 0) {
						NSMutableArray *newTables = [NSMutableArray arrayWithArray:tables];
						[newTables addObject:tblStructure];
						self.tables = newTables;
					}
					else {
						self.tables = [NSArray arrayWithObject:tblStructure];
					}
				}
				else {
					errorString = [NSString stringWithFormat:@"Failed to parse sql to table structure: %@", sql];
				}
				
				if (![db close]) {
					errorString = [NSString stringWithFormat:@"Could not close database at %@: (%d) %@", path, [db lastErrorCode], [db lastErrorMessage]];
				}
			}
			else {
				errorString = [NSString stringWithFormat:@"SQLite error %d: %@", [db lastErrorCode], [db lastErrorMessage]];
			}
		}
		else {
			errorString = [NSString stringWithFormat:@"Could not open database at %@: (%d) %@", path, [db lastErrorCode], [db lastErrorMessage]];
		}
		
		// Error reporting
		if (errorString) {
			NSLog(@"Error in tableWithName: %@", errorString);
		}
	}
	return nil;
}



#pragma mark - Parsing Structure Descriptions
/**
 *	Parses an XML file at given path to create a database structure
 */
- (void)parseStructureFromXML:(NSURL *)xmlUrl error:(NSError **)error
{
	// read data
	NSError *parseError = nil;
	//NSData *xmlData = [NSData dataWithContentsOfURL:xmlUrl options:NSDataReadingUncached error:&parseError];	// NSDataReadingUncached is iOS 4.+ only
	NSData *xmlData = [NSData dataWithContentsOfURL:xmlUrl options:2 error:&parseError];
	
	// parse
	if (xmlData) {
		self.parsingTables = [NSMutableArray array];
		if (asyncParsing) {
			[self performSelectorInBackground:@selector(parseXMLData:) withObject:xmlData];
		}
		else {
			[self parseXMLData:xmlData];
		}
	}
	else {
		DLog(@"Could not read XML: %@", [parseError userInfo]);
		if (NULL != error) {
			error = &parseError;
		}
	}
}



#pragma mark - XML Parsing
/**
 *	The parsing workhorse
 */
- (void)parseXMLData:(NSData *)data
{	
	NSAutoreleasePool *innerPool = [[NSAutoreleasePool alloc] init];
	
	// create a parser
	NSXMLParser *parser = [[NSXMLParser alloc] initWithData:data];
	[parser setDelegate:self];
	
	[parser setShouldProcessNamespaces:NO];
	[parser setShouldReportNamespacePrefixes:NO];
	[parser setShouldResolveExternalEntities:NO];
	
	// parse
	[parser parse];
	NSError *parseError = [parser parserError];
	[parser release];
	
	// notify us
	[self performSelectorOnMainThread:@selector(didParseData:) withObject:parseError waitUntilDone:YES];
	
	// clean up
	[innerPool release];
}

- (void)didParseData:(NSError *)error
{
	if (error) {
		DLog(@"Parse Error: %@", [error userInfo]);
	}
	
	self.tables = parsingTables;
	self.parsingTables = nil;
	
	//[self log];
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
		if ([self hasTable:[attributeDict valueForKey:@"name"]]) {
			duplicateTable = YES;
			DLog(@"There already is a table named \"%@\" in this structure, skipping", [attributeDict valueForKey:@"name"]);
		}
		else {
			duplicateTable = NO;
			self.parsingTable = [SQLKTableStructure tableForStructure:self];
			parsingTable.name = [attributeDict valueForKey:@"name"];
			self.parsingTableColumns = [NSMutableArray array];
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
			DLog(@"Encountered a column without a table in place. Generate an error!");
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
			self.parsingTableConstraints = nil;
			
			[parsingTables addObject:parsingTable];
			self.parsingTable = nil;
		}
		else {
			DLog(@"Ended a table without beginning one. Interesting. Generate an error!");
		}
	}
	
	// constraint
	else if ([elementName isEqualToString:@"constraint"]) {
		if ([parsingString length] > 0) {
			if (!parsingTableConstraints) {
				self.parsingTableConstraints = [NSMutableArray array];
			}
			if (![@"CONSTRAINT" isEqualToString:[parsingString substringToIndex:MIN([parsingString length], 10)]]) {
				self.parsingString = (NSMutableString *)[@"CONSTRAINT " stringByAppendingString:parsingString];			// We'll throw away the non-mutable string 3 lines later
			}
			[parsingTableConstraints addObject:parsingString];
			self.parsingString = nil;
		}
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
	for (SQLKTableStructure *table in tables) {
		[table log];
	}
}

- (NSString *) description
{
	return [NSString stringWithFormat:@"%@ <0x%x> %i tables", NSStringFromClass([self class]), self, [tables count]];
}


@end
