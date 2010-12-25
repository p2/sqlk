//
//  SQLiteStructureTable.m
//  SQLiteKit
//
//  Created by Pascal Pfiffner on 11.09.10.
//	
//	Instances of this class represent tables belonging to a SQLKStructure
//

#import "SQLKTableStructure.h"
#import "SQLKColumnStructure.h"
#import "FMDatabase.h"


@implementation SQLKTableStructure

@synthesize structure;
@synthesize name;
@synthesize columns;
@synthesize originalQuery;

- (void) dealloc
{
	[name release];
	[columns release];
	[originalQuery release];

	[super dealloc];
}

+ (SQLKTableStructure *) tableForStructure:(SQLKStructure *)aStructure
{
	SQLKTableStructure *t = [self new];
	t.structure = aStructure;
	
	return [t autorelease];
}

+ (SQLKTableStructure *) tableFromQuery:(NSString *)aQuery
{
	SQLKTableStructure *t = [self new];
	if ([aQuery length] > 0) {
		t.originalQuery = aQuery;
		//DLog(@"Parsing:  %@", aQuery);
		
		NSString *errorString = nil;
		NSScanner *scanner = [NSScanner scannerWithString:aQuery];
		[scanner setCaseSensitive:NO];
		NSCharacterSet *whiteSpace = [NSCharacterSet whitespaceCharacterSet];
		
		// CREATE TABLE characteristics (characteristic_id int(6) PRIMARY KEY, study_id int(5), type varchar(63), key varchar(255), value varchar(255), lastedit timestamp DEFAULT CURRENT_TIMESTAMP, lastedit_by int(6), added timestamp DEFAULT CURRENT_TIMESTAMP, added_by int(6));
		
		// scan table name
		if ([scanner scanUpToString:@"TABLE" intoString:NULL] && [scanner scanString:@"TABLE" intoString:NULL]) {
			//[scanner scanString:@"EXISTS" intoString:NULL];			// TODO: skip potential "IF NOT EXISTS"
			
			NSString *tblName = nil;
			[scanner scanUpToCharactersFromSet:whiteSpace intoString:&tblName];
			//[scanner scanUpToString:@"(" intoString:&tblName];
			if ([tblName length] > 0) {
				t.name = tblName;
				[scanner scanUpToString:@"(" intoString:NULL];				// check for "AS", this is also a possible encounter here
				[scanner scanString:@"(" intoString:NULL];
				
				// get columns
				NSRange colRange = NSMakeRange([scanner scanLocation], [aQuery length] - [scanner scanLocation] - 1);
				NSString *columnsString = [aQuery substringWithRange:colRange];
				NSArray *colStrings = [columnsString componentsSeparatedByString:@","];
				
				// loop column strings
				if ([colStrings count] > 0) {
					NSMutableArray *newColumns = [NSMutableArray array];
					
					for (NSString *colString in colStrings) {
						NSScanner *colScanner = [NSScanner scannerWithString:colString];
						NSString *colName = nil;
						NSString *colType = nil;
						[colScanner scanCharactersFromSet:whiteSpace intoString:NULL];
						[colScanner scanUpToCharactersFromSet:whiteSpace intoString:&colName];
						[colScanner scanCharactersFromSet:whiteSpace intoString:NULL];
						[colScanner scanUpToCharactersFromSet:whiteSpace intoString:&colType];		// what happens with "int (6)"?
						
						SQLKColumnStructure *column = [SQLKColumnStructure columnForTable:t];
						column.name = colName;
						column.type = colType;
						column.isUnique = ([colString rangeOfString:@"UNIQUE"].location != NSNotFound);
						column.isPrimaryKey = ([colString rangeOfString:@"PRIMARY KEY"].location != NSNotFound);
						// TODO: Parse default values
						
						if ([colName length] > 0) {
							[newColumns addObject:column];
						}
					}
					
					t.columns = newColumns;
				}
				else {
					errorString = @"No column strings found";
				}
			}
			else {
				errorString = @"Could not find table name";
			}
		}
		else {
			errorString = @"Could not find CREATE TABLE hook";
		}
		
		if (errorString) {
			DLog(@"Error parsing: %@\nSQL: %@", errorString, aQuery);
		}
	}
	else {
		DLog(@"Query was empty");
	}
	
	return [t autorelease];
}
#pragma mark -



#pragma mark Creating
- (BOOL) createInDatabase:(FMDatabase *)database error:(NSError **)error
{
	if (database) {				// if ([database goodConnection])
		NSString *query = [self creationQuery];
		[database executeUpdate:query];
		
		if (![database hadError]) {
			return YES;
		}
		DLog(@"Error executing query: (%d) %@\n%@", [database lastErrorCode], [database lastErrorMessage], query);
	}
	return NO;
}

- (NSString *) creationQuery
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
		
		return [NSString stringWithFormat:@"CREATE TABLE %@ (%@)", name, [colStrings componentsJoinedByString:@", "]];
	}
	
	DLog(@"Can't create a table without columns");
	return nil;
}
#pragma mark -



#pragma mark Comparing
- (BOOL) isEqual:(id)object
{
	if ([object isKindOfClass:[self class]]) {
		return [self isEqualToTable:(SQLKTableStructure *)object error:NULL];
	}
	return NO;
}

- (BOOL) isEqualToTable:(SQLKTableStructure *)ot error:(NSError **)error
{
	NSString *errorString = nil;
	if (ot) {
		
		// check name
		if ([name isEqualToString:ot.name]) {
			
			// compare columns
			NSMutableArray *existingColumns = [columns mutableCopy];
			if ([existingColumns count] > 0) {
				NSMutableArray *errors = [NSMutableArray array];
				
				// compare existing columns
				for (SQLKColumnStructure *cs in columns) {
					NSError *myError = nil;
					if (![self hasColumnWithStructure:cs error:&myError]) {
						[errors addObject:myError];
					}
					else {
						[existingColumns removeObject:cs];
					}
				}
				
				// leftover columns?
				if ([existingColumns count] > 0) {
					for (SQLKColumnStructure *sup in existingColumns) {
						NSString *errorString = [NSString stringWithFormat:@"Superfluuous column: %@", sup.name];
						NSDictionary *userDict = [NSDictionary dictionaryWithObject:errorString forKey:NSLocalizedDescriptionKey];
						NSError *anError = [NSError errorWithDomain:NSCocoaErrorDomain code:672 userInfo:userDict];
						[errors addObject:anError];
					}
				}
				[existingColumns release];
				
				// report specific errors
				if ([errors count] > 0) {
					NSString *errorString = [NSString stringWithFormat:@"%d errors occurred while comparing columns to table \"%@\". See \"SQLKErrors\" in this errors' userInfo.", [errors count], ot.name];
					DLog(@"Not equal: %@", errorString);
					if (NULL != error) {
						NSDictionary *userDict = [NSDictionary dictionaryWithObjectsAndKeys:errorString, NSLocalizedDescriptionKey, errors, @"SQLKErrors", nil];
						*error = [NSError errorWithDomain:NSCocoaErrorDomain code:673 userInfo:userDict];
					}
					
					return NO;
				}
				else {
					return YES;
				}
			}
			else if ([ot.columns count] > 0) {
				errorString = @"This table is missing all columns";
			}
			else {
				DLog(@"Note: These tables don't have any columns");
				return YES;
			}
		}
		//else {
		//	errorString = @"Table names don't match";
		//}
	}
	else {
		errorString = @"No other table given";
	}
	
	// report generic errors
	if (errorString) {
		DLog(@"Not equal: %@", errorString);
		if (NULL != error) {
			NSDictionary *userDict = [NSDictionary dictionaryWithObject:errorString forKey:NSLocalizedDescriptionKey];
			*error = [NSError errorWithDomain:NSCocoaErrorDomain code:674 userInfo:userDict];
		}
	}
	
	return NO;
}

- (BOOL) updateTableAccordingTo:(NSString *)tableDesc dropUnused:(BOOL)drop error:(NSError **)error
{
	return NO;
}

- (BOOL) hasColumnNamed:(NSString *)columnName
{
	if (columnName) {
		for (SQLKColumnStructure *column in columns) {
			if ([column.name isEqualToString:columnName]) {
				return YES;
			}
		}
	}
	return NO;
}

- (BOOL) hasColumnWithStructure:(SQLKColumnStructure *)columnStructure error:(NSError **)error
{
	if (columnStructure) {
		for (SQLKColumnStructure *column in columns) {
			if ([column.name isEqualToString:columnStructure.name]) {
				return [column isEqualToColumn:columnStructure error:error];
			}
		}
	}
	return NO;
}
#pragma mark -



#pragma mark Utilities
- (NSString *) description
{
	return [NSString stringWithFormat:@"%@ <0x%x> \"%@\", %i columns", NSStringFromClass([self class]), self, name, [columns count]];
}


@end
