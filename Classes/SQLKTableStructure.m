//
//  SQLiteStructureTable.m
//  SQLiteKit
//
//  Created by Pascal Pfiffner on 11.09.10.
//  This sourcecode is released under the Apache License, Version 2.0
//  http://www.apache.org/licenses/LICENSE-2.0.html
//

#import "SQLKTableStructure.h"
#import "sqlk.h"
#import "SQLKStructure.h"
#import "SQLKColumnStructure.h"
#import "FMDatabase.h"

#define DEBUG_SCANNING 0
#ifndef SLog
# if DEBUG_SCANNING
#  define SLog(fmt, ...) NSLog((@"%s (line %d) " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__);
# else
#  define SLog(...)
# endif
#endif

@implementation SQLKTableStructure

@synthesize structure;
@synthesize name, columns, constraints;
@synthesize originalQuery;



+ (SQLKTableStructure *)tableForStructure:(SQLKStructure *)aStructure
{
	SQLKTableStructure *t = [self new];
	t.structure = aStructure;
	
	return t;
}

/**
 *	Instantiates an object from a given SQLite query
 *	See http://www.sqlite.org/syntaxdiagrams.html for diagrams
 */
+ (SQLKTableStructure *)tableFromQuery:(NSString *)aQuery
{
	SQLKTableStructure *t = [self new];
	if ([aQuery length] > 0) {
		t.originalQuery = aQuery;
		SLog(@"Parsing:  %@", aQuery);
		
		NSString *errorString = nil;
		NSScanner *scanner = [NSScanner scannerWithString:aQuery];
		[scanner setCaseSensitive:NO];
		[scanner setCharactersToBeSkipped:nil];
		
		NSCharacterSet *whiteSpace = [NSCharacterSet whitespaceAndNewlineCharacterSet];
		NSMutableCharacterSet *letterSet = [NSCharacterSet letterCharacterSet];
		NSCharacterSet *closeBracketOrComma = [NSCharacterSet characterSetWithCharactersInString:@"),"];
		
		
		// scan table name
		if ([scanner scanUpToString:@"TABLE" intoString:NULL] && [scanner scanString:@"TABLE" intoString:NULL]) {
			[scanner scanCharactersFromSet:whiteSpace intoString:NULL];
			//[scanner scanString:@"EXISTS" intoString:NULL];				/// @todo skip potential "IF NOT EXISTS"
			
			NSString *tblName = nil;
			[scanner scanUpToCharactersFromSet:whiteSpace intoString:&tblName];
			//[scanner scanUpToString:@"(" intoString:&tblName];
			if ([tblName length] > 0) {
				NSMutableArray *newColumns = [NSMutableArray array];
				NSMutableArray *newConstraints = [NSMutableArray array];
				
				t.name = tblName;
				[scanner scanUpToString:@"(" intoString:NULL];				// check for "AS", this is also a possible encounter here
				[scanner scanString:@"(" intoString:NULL];
				
				// scan columns and table constraints
				BOOL atConstraints = NO;
				BOOL noMoreColumns = NO;
				while (![scanner isAtEnd]) {
					NSString *scanString = nil;
					[scanner scanCharactersFromSet:whiteSpace intoString:NULL];
					if ([scanner scanString:@")" intoString:&scanString]) {
						noMoreColumns = YES;
					}
					
					// separate constraints from columns
					if (!noMoreColumns) {
						[scanner scanUpToCharactersFromSet:whiteSpace intoString:&scanString];
						SLog(@" -->  %@", scanString);
						
						// ** looks like we found a constraint
						if (atConstraints
							|| ([@"CONSTRAINT" isEqualToString:scanString]
								|| [@"UNIQUE" isEqualToString:scanString]
								|| [@"PRIMARY" isEqualToString:scanString]
								|| [@"FOREIGN" isEqualToString:scanString]
								|| [@"CHECK" isEqualToString:scanString]))
						{
							atConstraints = YES;
							SLog(@"==>  Interpreting as constraint");
							
							NSMutableString *constraint = [scanString mutableCopy];
							if ([scanner scanUpToString:@"(" intoString:&scanString]) {
								[constraint appendString:scanString];
								if ([scanner scanUpToString:@")" intoString:&scanString]) {
									[constraint appendString:scanString];
									if ([scanner scanString:@")" intoString:&scanString]) {
										[constraint appendString:scanString];
									}
								}
							}
							
							if ([scanner scanUpToCharactersFromSet:closeBracketOrComma intoString:&scanString]) {
								[constraint appendString:scanString];
							}
							[scanner scanString:@"," intoString:NULL];
							
							[newConstraints addObject:constraint];
						}
						
						// ** we most likely found a column
						else {
							SLog(@"==>  Interpreting as column");
							SQLKColumnStructure *column = [SQLKColumnStructure columnForTable:t];
							column.name = scanString;
							
							// type
							[scanner scanCharactersFromSet:whiteSpace intoString:NULL];
							if ([scanner scanCharactersFromSet:letterSet intoString:&scanString]) {
								[scanner scanCharactersFromSet:whiteSpace intoString:NULL];
								column.type = scanString;
							}
							
							// there might my MySQL-type type lengths, we just ignore them
							if ([scanner scanString:@"(" intoString:NULL]) {
								[scanner scanUpToString:@")" intoString:NULL];
								[scanner scanString:@")" intoString:NULL];
							}
							
							/// @todo Scan column constraints more sophisticated (scan up to either "(" or "," and see what we've got, then decide whether next
							// column is starting or we're in brackets). Not sure if it's worth the effort since this "feature" is only useful if parsing the
							// structure from one sqlite database and wanting to create a blank copy of it, without access to an XML structure.
							
							// scan column constraints and defaults
							if ([scanner scanUpToString:@"," intoString:&scanString]) {
								SLog(@"==>  name: %@  type: %@  constraints/defaults: \"%@\"", column.name, column.type, scanString);
								
								// unique column
								column.isUnique = (NSNotFound != [scanString rangeOfString:@"UNIQUE"].location);
								
								// column is primary key
								column.isPrimaryKey = (NSNotFound != [scanString rangeOfString:@"PRIMARY KEY"].location);
								
								// column has a default defined - for now we assume everything behind DEFAULT is the default value
								if (NSNotFound != [scanString rangeOfString:@"DEFAULT"].location) {
									NSMutableArray *parts = [[scanString componentsSeparatedByCharactersInSet:whiteSpace] mutableCopy];
									NSUInteger defaultIndex = [parts indexOfObject:@"DEFAULT"];
									if ([parts count] > defaultIndex + 1) {
										NSIndexSet *remove = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, defaultIndex + 1)];
										[parts removeObjectsAtIndexes:remove];
										column.defaultString = [parts componentsJoinedByString:@" "];
									}
								}
							}
							
							// remember column and skip to next item
							if ([column.name length] > 0) {
								[newColumns addObject:column];
							}
							
							[scanner scanString:@"," intoString:NULL];
						}
					}
				}
				
				t.columns = newColumns;
				t.constraints = ([newConstraints count] > 0) ? newConstraints : nil;
			}
			else {
				errorString = @"Could not find table name";
			}
		}
		else {
			errorString = @"Could not find CREATE TABLE hook";
		}
		
#if DEBUG_SCANNING
		[t log];
#endif
		
		if (errorString) {
			DLog(@"Error parsing: %@\nSQL: %@", errorString, aQuery);
		}
	}
	else {
		DLog(@"Query was empty");
	}
	
	return t;
}



#pragma mark - Creating
/**
 *	Creates the receiver's structure in the given database
 *	@param database A handle to the database
 *	@param error A pointer to an array object
 */
- (BOOL)createInDatabase:(FMDatabase *)database error:(NSError **)error
{
	if ([database open]) {
		NSString *query = [self creationQuery];
		[database executeUpdate:query];
		
		if (![database hadError]) {
			return YES;
		}
		NSString *errorString = [NSString stringWithFormat:@"Error executing query: (%d) %@\n%@", [database lastErrorCode], [database lastErrorMessage], query];
		SQLK_ERR(error, errorString, 0)
	}
	else {
		NSString *errorString = database ? [NSString stringWithFormat:@"Could not open database: (%d) %@", [database lastErrorCode], [database lastErrorMessage]] : @"No database given";
		SQLK_ERR(error, errorString, 0)
	}
	return NO;
}

/**
 *	Returns the SQLite query needed in order to create a table representing the receiver's structure
 */
- (NSString *)creationQuery
{
	if ([columns count] > 0) {
		NSMutableArray *colStrings = [NSMutableArray arrayWithCapacity:[columns count]];
		
		// collect columns
		for (SQLKColumnStructure *column in columns) {
			NSString *colQuery = [column creationQuery];
			if (colQuery) {
				[colStrings addObject:colQuery];
			}
		}
		
		// collect constraints
		for (NSString *constraint in constraints) {
			if ([constraint length] > 0) {
				[colStrings addObject:constraint];
			}
		}
		
		return [NSString stringWithFormat:@"CREATE TABLE %@ (%@)", name, [colStrings componentsJoinedByString:@", "]];
	}
	
	DLog(@"Can't create a table without columns");
	return nil;
}



#pragma mark - Comparing
/**
 *	Tables are equal if they have the same structure, i.e. "isEqualToTable:error:" also returns YES
 */
- (BOOL)isEqual:(id)object
{
	if (self == object) {
		return YES;
	}
	if ([object isKindOfClass:[self class]] && [name isEqualToString:[object name]]) {
		return [self isEqualToTable:(SQLKTableStructure *)object error:NULL];
	}
	return NO;
}

/**
 *	This method is used by SQLKStructure to compare a table structure described in an XML to a table structure inferred from the
 *	actual SQLite database.
 */
- (BOOL)isEqualToTable:(SQLKTableStructure *)refTable error:(NSError **)error
{
	NSString *errorString = nil;
	NSUInteger errorCode = 0;
	
	if (refTable) {
		
		// check name
		if ([name isEqualToString:refTable.name]) {
			NSMutableArray *existingColumns = [columns mutableCopy];
			
			// compare columns
			if ([existingColumns count] > 0) {
				NSMutableArray *errors = [NSMutableArray array];
				
				// compare existing columns
				for (SQLKColumnStructure *refColumn in refTable.columns) {
					if (![self hasColumnWithStructure:refColumn]) {
						NSError *myError = nil;
						NSString *errorMessage = [NSString stringWithFormat:@"Differring column: %@", refColumn.name];
						SQLK_ERR(&myError, errorMessage, 0)
						[errors addObject:myError];
					}
					else {
						[existingColumns removeObject:refColumn];
					}
				}
				
				// leftover columns?
				if ([existingColumns count] > 0) {
					for (SQLKColumnStructure *sup in existingColumns) {
						NSError *myError = nil;
						NSString *myErrorString = [NSString stringWithFormat:@"Superfluuous column: %@", sup.name];
						SQLK_ERR(&myError, myErrorString, 0)
						[errors addObject:myError];
					}
				}
				
				// report specific errors
				if ([errors count] > 0) {
					errorString = [NSString stringWithFormat:@"%d errors occurred while comparing columns to table \"%@\". See \"SQLKErrors\" in this errors' userInfo.", (unsigned int)[errors count], refTable.name];
					errorCode = 673;
				}
				else {
					return YES;
				}
			}
			else if ([refTable.columns count] > 0) {
				errorString = @"This table is missing all columns";
				errorCode = 641;
			}
			else {
				DLog(@"Note: Both tables don't have any columns");
				return YES;
			}
		}
		//else {
		//	errorString = @"Table names don't match";
		//}
	}
	else {
		errorString = @"No other table given";
		errorCode = 675;
	}
	
	// report generic errors
	if (errorString) {
		SQLK_ERR(error, errorString, errorCode)
	}
	
	return NO;
}


/**
 *	@return The column with the given name
 */
- (SQLKColumnStructure *)columnNamed:(NSString *)columnName
{
	if (columnName) {
		for (SQLKColumnStructure *column in columns) {
			if ([column.name isEqualToString:columnName]) {
				return column;
			}
		}
	}
	return nil;
}

/**
 *	@return YES if the receiver has a column with the given name
 */
- (BOOL)hasColumnNamed:(NSString *)columnName
{
	return (nil != [self columnNamed:columnName]);
}

/**
 *	Returns YES if the receiver has a column with the given structure
 */
- (BOOL)hasColumnWithStructure:(SQLKColumnStructure *)columnStructure
{
	if (columnStructure) {
		for (SQLKColumnStructure *column in columns) {
			if ([column.name isEqualToString:columnStructure.name]) {
				return [column isEqual:columnStructure];
			}
		}
	}
	return NO;
}



#pragma mark - Updating


/**
 *	Updates the table to match the structure given in the reference table.
 *	The receiver's parent structure must have an open handle to the actual database. Remember SQLite can't drop columns, so if you remove them from your schema,
 *	they will still persist in the database.
 *	We don't use transactions within this method as a transaction is openend by updateDatabaseAt:dropTables:error:
 */
- (BOOL)updateTableWith:(SQLKTableStructure *)refTable error:(NSError **)error
{
	FMDatabase *db = structure.database;
	if ([db open]) {
		
		// compare existing columns
		if ([refTable.columns count] > 0) {
			for (SQLKColumnStructure *refColumn in refTable.columns) {
				SQLKColumnStructure *existing = [self columnNamed:refColumn.name];
				
				// column is missing, add it
				if (!existing) {
					
					// TODO: New columns may not: ( http://www.sqlite.org/lang_altertable.html )
					//		- be PRIMARY
					//		- be UNIQUE
					//		- have CURRENT_[TIME|DATE|TIMESTAMP] as default
					//		- if it is NOT NULL, must have a non-null default value
					//		- if it has a REFERENCES clause, must have a null default value
					NSString *query = [NSString stringWithFormat:@"ALTER TABLE %@ ADD COLUMN %@", refTable.name, [refColumn creationQuery]];
					if (![db executeUpdate:query]) {
						NSString *errorString = [NSString stringWithFormat:@"Failed to: %@: (%d) %@", query, [db lastErrorCode], [db lastErrorMessage]];
						SQLK_ERR(error, errorString, 601)
						return NO;
					}
				}
				
				// TODO: To drop columns, we have to recreate the table without the column to be dropped
			}
		}
		
		return YES;
	}
	else if (db) {
		NSString *errorString = [NSString stringWithFormat:@"Could not open database: (%d) %@", [db lastErrorCode], [db lastErrorMessage]];
		SQLK_ERR(error, errorString, 621)
	}
	else if (structure) {
		SQLK_ERR(error, @"We don't have a database handle to update the table", 620)
	}
	else {
		SQLK_ERR(error, @"The table doesn't have a db structure, can't update the table", 640)
	}
	return NO;
}



#pragma mark - Destruction
/**
 *	Drops the receiver's representation from the given database
 */
- (BOOL)dropFromDatabase:(FMDatabase *)database error:(NSError **)error
{
	if ([database open]) {
		NSString *query = [NSString stringWithFormat:@"DROP TABLE \"%@\"", self.name];
		[database executeUpdate:query];
		
		if (![database hadError]) {
			return YES;
		}
		NSString *errorString = [NSString stringWithFormat:@"Error executing query: (%d) %@\n%@", [database lastErrorCode], [database lastErrorMessage], query];
		SQLK_ERR(error, errorString, 0)
	}
	else {
		NSString *errorString = database ? [NSString stringWithFormat:@"Could not open database: (%d) %@", [database lastErrorCode], [database lastErrorMessage]] : @"No database given";
		SQLK_ERR(error, errorString, 0)
	}
	return NO;
}



#pragma mark - Utilities
- (void)log
{
	NSLog(@"--  %@", self);
	for (SQLKColumnStructure *column in self.columns) {
		NSLog(@"----  %@", column);
	}
	for (NSString *constraint in self.constraints) {
		NSLog(@"---|  %@", constraint);
	}
}

- (NSString *) description
{
	return [NSString stringWithFormat:@"%@ <%p> \"%@\", %i columns, %i constraints", NSStringFromClass([self class]), self, name, (unsigned int)[columns count], (unsigned int)[constraints count]];
}


@end
