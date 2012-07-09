//
//  SQLiteStructureTable.m
//  SQLiteKit
//
//  Created by Pascal Pfiffner on 11.09.10.
//	

#import "SQLKTableStructure.h"
#import "sqlk.h"
#import "SQLKStructure.h"
#import "SQLKColumnStructure.h"
#import "FMDatabase.h"


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
		//DLog(@"Parsing:  %@", aQuery);
		
		NSString *errorString = nil;
		NSScanner *scanner = [NSScanner scannerWithString:aQuery];
		[scanner setCaseSensitive:NO];
		NSCharacterSet *whiteSpace = [NSCharacterSet whitespaceCharacterSet];
		NSMutableCharacterSet *wsOrComma = [whiteSpace mutableCopy];
		[wsOrComma addCharactersInString:@","];
		NSCharacterSet *closeBracketOrComma = [NSCharacterSet characterSetWithCharactersInString:@"),"];
		
		
		// scan table name
		if ([scanner scanUpToString:@"TABLE" intoString:NULL] && [scanner scanString:@"TABLE" intoString:NULL]) {
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
					//[scanner scanCharactersFromSet:whiteSpace intoString:NULL];		// are in characters to be ignored anyway
					if ([scanner scanString:@")" intoString:&scanString]) {
						noMoreColumns = YES;
					}
					
					// separate constraints from columns
					if (!noMoreColumns) {
						[scanner scanUpToCharactersFromSet:whiteSpace intoString:&scanString];
						//DLog(@" -->  %@", scanString);
						
						// looks like we found a constraint
						if (atConstraints
							|| ([@"CONSTRAINT" isEqualToString:scanString]
								|| [@"UNIQUE" isEqualToString:scanString]
								|| [@"PRIMARY" isEqualToString:scanString]
								|| [@"FOREIGN" isEqualToString:scanString]
								|| [@"CHECK" isEqualToString:scanString]))
						{
							atConstraints = YES;
							
							NSCharacterSet *skipSet = [scanner charactersToBeSkipped];
							[scanner setCharactersToBeSkipped:nil];
							
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
							[scanner setCharactersToBeSkipped:skipSet];
							[scanner scanString:@"," intoString:NULL];
							
							[newConstraints addObject:constraint];
						}
						
						// most likely a column
						else {
							SQLKColumnStructure *column = [SQLKColumnStructure columnForTable:t];
							column.name = scanString;
							
							[scanner scanCharactersFromSet:whiteSpace intoString:NULL];
							if ([scanner scanUpToCharactersFromSet:wsOrComma intoString:&scanString]) {			// what happens with "int (6)"? For now, this won't work
								column.type = scanString;
							}
							
							/// @todo Scan column constraints more sophisticated (scan up to either "(" or "," and see what we've got, then decide whether next column is starting or we're in brackets)
							
							if ([scanner scanUpToString:@"," intoString:&scanString]) {
								//DLog(@"==>  %@  \"%@\"", column.name, scanString);
								column.isUnique = ([scanString rangeOfString:@"UNIQUE"].location != NSNotFound);
								column.isPrimaryKey = ([scanString rangeOfString:@"PRIMARY KEY"].location != NSNotFound);
							}
							
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
		
		//[t log];
		
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
					NSError *myError = nil;
					if (![self hasColumnWithStructure:refColumn error:&myError]) {
						[errors addObject:myError];
					}
					else {
						[existingColumns removeObject:refColumn];
					}
				}
				
				// leftover columns?
				if ([existingColumns count] > 0) {
					for (SQLKColumnStructure *sup in existingColumns) {
						NSString *errorString = [NSString stringWithFormat:@"Superfluuous column: %@", sup.name];
						NSDictionary *userDict = [NSDictionary dictionaryWithObject:errorString forKey:NSLocalizedDescriptionKey];
						NSError *anError = [NSError errorWithDomain:NSCocoaErrorDomain code:0 userInfo:userDict];
						[errors addObject:anError];
					}
				}
				
				// report specific errors
				if ([errors count] > 0) {
					errorString = [NSString stringWithFormat:@"%d errors occurred while comparing columns to table \"%@\". See \"SQLKErrors\" in this errors' userInfo.", [errors count], refTable.name];
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
- (BOOL)hasColumnWithStructure:(SQLKColumnStructure *)columnStructure error:(NSError **)error
{
	if (columnStructure) {
		for (SQLKColumnStructure *column in columns) {
			if ([column.name isEqualToString:columnStructure.name]) {
				return [column isEqualToColumn:columnStructure error:error];
			}
		}
	}
	SQLK_ERR(error, @"No comparison column given", 0)
	return NO;
}



#pragma mark - Updating


/**
 *	Updates the table to match the structure given in the reference table.
 *	The receiver's parent structure must have an open handle to the actual database
 */
- (BOOL)updateTableWith:(SQLKTableStructure *)refTable dropUnusedColumns:(BOOL)dropColumns error:(NSError **)error
{
	FMDatabase *db = structure.database;
	if ([db open]) {
		NSMutableArray *existingColumns = [columns mutableCopy];
		
		// compare existing columns
		if ([refTable.columns count] > 0) {
			for (SQLKColumnStructure *refColumn in refTable.columns) {
				SQLKColumnStructure *existing = [self columnNamed:refColumn.name];
				
				// existing column, but is the structure still valid?
				if (existing) {
					if (![existing isEqual:refColumn]) {
						DLog(@"MUST UPDATE COLUMN %@", refColumn.name);
					}
					[existingColumns removeObject:existing];
				}
				
				// new column, create
				else {
					DLog(@"MUST CREATE COLUMN %@", refColumn.name);
				}
			}
		}
		
		// leftover columns?
		if ([existingColumns count] > 0) {
			if (dropColumns) {
				for (SQLKColumnStructure *superfluuous in existingColumns) {
					DLog(@"MUST DROP COLUMN %@", superfluuous.name);
				}
			}
			else {
				DLog(@"There are %d superfluuous columns, but we're not allowed to drop them", [existingColumns count]);
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
	return [NSString stringWithFormat:@"%@ <%p> \"%@\", %i columns, %i constraints", NSStringFromClass([self class]), self, name, [columns count], [constraints count]];
}


@end
