//
//  SQLiteStructure.m
//  SQLiteKit
//
//  Created by Pascal Pfiffner on 11.09.10.
//  Copyright 2010 Institute Of Immunology. All rights reserved.
//	
//	Instances of this class represent one database. You mostly only interact with this class
//

#import "SQLKStructure.h"
#import "SQLKTableStructure.h"
#import "SQLKColumnStructure.h"
#import "FMDatabase.h"


@interface SQLKStructure ()

- (void) parseXMLData:(NSData *)data;

@end


@implementation SQLKStructure

@synthesize tables;
@synthesize path;
@synthesize asyncParsing;
@synthesize parsingTables;
@synthesize parsingTable;
@synthesize parsingTableColumns;


- (void) dealloc
{
	[tables release];
	[path release];
	self.parsingTables = nil;
	self.parsingTable = nil;
	self.parsingTableColumns = nil;
	
	[super dealloc];
}


+ (SQLKStructure *) structure
{
	return [[[self alloc] init] autorelease];
}

+ (SQLKStructure *) structureFromArchive:(NSURL *)archiveUrl
{
	DLog(@"Implement me to load from archive at %@", archiveUrl);
	return [[[self alloc] init] autorelease];
}

+ (SQLKStructure *) structureFromDatabase:(NSURL *)dbPath
{
	SQLKStructure *s = [SQLKStructure new];
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
				FMResultSet *masterSet = [db executeQuery:@"SELECT * FROM `sqlite_master` WHERE `type` = 'table'"];
				if ([db hadError]) {
					errorString = [NSString stringWithFormat:@"SQLite error %d: %@", [db lastErrorCode], [db lastErrorMessage]];
				}
				else {
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
			}
			else {
				errorString = [NSString stringWithFormat:@"Could not open database at %@: (%d) %@", dbPath, [db lastErrorCode], [db lastErrorMessage]];
			}
		}
		else {
			errorString = [NSString stringWithFormat:@"A file does not reside at %@, can't initialize from database", dbPath];
		}
	}
	else {
		errorString = [NSString stringWithFormat:@"Can't access database at %@", dbPath];
	}
	if (errorString) {
		DLog(@"Error: %@", errorString);
	}
	
	return [s autorelease];
}
#pragma mark -



#pragma mark NSCoding
- (id) initWithCoder:(NSCoder *)decoder
{
	if ((self = [super init])) {
		self.tables = [decoder decodeObjectForKey:@"tables"];
	}
	return self;
}

- (void) encodeWithCoder:(NSCoder *)encoder
{
	[encoder encodeObject:tables forKey:@"tables"];
}
#pragma mark -



#pragma mark Creating a database
- (BOOL) createDatabaseAt:(NSURL *)dbPath error:(NSError **)error
{
	NSString *errorString = nil;
	
	// loop tables
	if ([tables count] > 0) {
		
		// can we access the database file?
		if ([self canAccessURL:dbPath]) {
			NSFileManager *fm = [NSFileManager defaultManager];
			if (![fm fileExistsAtPath:[dbPath path]]) {
				
				// should be fine, open the database
				FMDatabase *db = [FMDatabase databaseWithPath:[dbPath path]];
				if ([db open]) {
					NSError *myError = nil;
					
					// **** go ahead, make my day errrh... tables!
					[db beginTransaction];
					for (SQLKTableStructure *table in tables) {
						if (![table createInDatabase:db error:&myError]) {
							[db commit];
							[db close];
							errorString = [NSString stringWithFormat:@"Failed to create table \"%@\" in database %@: %@", table.name, dbPath, [myError userInfo]];
							DLog(@"Error creating db: %@", errorString);
							if (NULL != error) {
								NSDictionary *userDict = [NSDictionary dictionaryWithObject:errorString forKey:NSLocalizedDescriptionKey];
								*error = [NSError errorWithDomain:NSCocoaErrorDomain code:667 userInfo:userDict];
							}
							[db close];
							return NO;
						}
					}
					[db commit];
					// ****
					
					if ([db close]) {
						return YES;
					}
					
					errorString = [NSString stringWithFormat:@"Could not close database at %@: (%d) %@", dbPath, [db lastErrorCode], [db lastErrorMessage]];
				}
				else {
					errorString = [NSString stringWithFormat:@"Could not open database at %@: (%d) %@", dbPath, [db lastErrorCode], [db lastErrorMessage]];
				}
			}
			else {
				errorString = [NSString stringWithFormat:@"A file already resides at %@, can't create a new database", dbPath];
			}
		}
		else {
			errorString = [NSString stringWithFormat:@"Can't access database at %@", dbPath];
		}
	}
	else {
		errorString = @"We first need tables in order to create a database";
	}
	
	if (errorString) {
		DLog(@"Error: %@", errorString);
		if (NULL != error) {
			NSDictionary *userDict = [NSDictionary dictionaryWithObject:errorString forKey:NSLocalizedDescriptionKey];
			*error = [NSError errorWithDomain:NSCocoaErrorDomain code:666 userInfo:userDict];
		}
	}
	
	return NO;
}
#pragma mark -



#pragma mark Verifying
- (BOOL) isEqualToDb:(SQLKStructure *)otherDB error:(NSError **)error
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

- (BOOL) updateDatabaseAt:(NSURL *)dbPath allowToDropColumns:(BOOL)dropCol tables:(BOOL)dropTables error:(NSError **)error
{
	SQLKStructure *otherDB = [SQLKStructure structureFromDatabase:dbPath];
	if (![otherDB isEqualToDb:self error:error]) {
		DLog(@"Should now update database at %@ because it does not meet our structure", dbPath);
		return NO;
	}
	return YES;
}


- (BOOL) hasTable:(NSString *)tableName
{
	for (SQLKTableStructure *table in tables) {
		if ([tableName isEqualToString:table.name]) {
			return YES;
		}
	}
	return NO;
}

- (BOOL) hasTableWithStructure:(SQLKTableStructure *)tableStructure error:(NSError **)error
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
#pragma mark -



#pragma mark Parsing Structure Descriptions
- (void) parseStructureFromXML:(NSURL *)xmlUrl error:(NSError **)error
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
#pragma mark -



#pragma mark XML Parsing
- (void) parseXMLData:(NSData *)data
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

- (void) didParseData:(NSError *)error
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
- (void) parserDidStartDocument:(NSXMLParser *)parser
{
}	//	*/


// starting an element
- (void) parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName attributes:(NSDictionary *)attributeDict
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
}


// the parser ended an element
- (void) parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName
{
	if (qName) {
		elementName = qName;
	}
	
	// table
	if ([elementName isEqualToString:@"table"]) {
		if (parsingTable) {
			parsingTable.columns = parsingTableColumns;
			self.parsingTableColumns = nil;
			
			[parsingTables addObject:parsingTable];
			self.parsingTable = nil;
		}
		else {
			DLog(@"Ended a table without beginning one. Interesting. Generate an error!");
		}
	}
}

/* called when the parser has a string
- (void) parser:(NSXMLParser *)parser foundCharacters:(NSString *)string
{
}	//	*/

/* gets called on error and on abort instead of parserDidEndDocument
- (void) parser:(NSXMLParser *)parser parseErrorOccurred:(NSError *)parseError
{
}	//	*/

/* will NOT be called when we abort!
- (void) parserDidEndDocument:(NSXMLParser *)parser
{
}	//	*/
#pragma mark -



#pragma mark Utilities
- (BOOL) canAccessURL:(NSURL *)dbPath
{
	return [dbPath isFileURL];
}

- (NSURL *) backupDatabaseAt:(NSURL *)dbPath
{
	return dbPath;
}


- (void) log
{
	NSLog(@"%@", self);
	for (SQLKTableStructure *tbl in tables) {
		NSLog(@"--  %@", tbl);
		for (SQLKColumnStructure *col in tbl.columns) {
			NSLog(@"----  %@", col);
		}
	}
}

- (NSString *) description
{
	return [NSString stringWithFormat:@"%@ <0x%x> %i tables", NSStringFromClass([self class]), self, [tables count]];
}


@end
