//
//  SQLiteStructureTableRow.m
//  SQLiteKit
//
//  Created by Pascal Pfiffner on 11.09.10.
//  This sourcecode is released under the Apache License, Version 2.0
//  http://www.apache.org/licenses/LICENSE-2.0.html
//

#import "SQLKColumnStructure.h"
#import "sqlk.h"


@implementation SQLKColumnStructure

@synthesize table;
@synthesize name, type;
@synthesize isPrimaryKey, isUnique;
@synthesize defaultNeedsQuotes, defaultString;


/**
 *	Return a column belonging to the given table
 */
+ (SQLKColumnStructure *)columnForTable:(SQLKTableStructure *)aTable
{
	SQLKColumnStructure *c = [self new];
	c.table = aTable;
	
	return c;
}


/**
 *	Sets the columns properties from its XML node attribute dictionary
 */
- (void)setFromAttributeDictionary:(NSDictionary *)dictionary
{
	if (dictionary) {
		self.name = [dictionary valueForKey:@"name"];
		self.type = [dictionary valueForKey:@"type"];
		self.isPrimaryKey = [[dictionary valueForKey:@"primary"] boolValue];
		self.isUnique = [[dictionary valueForKey:@"unique"] boolValue];
		self.defaultString = [dictionary valueForKey:@"default"];
		self.defaultNeedsQuotes = [[dictionary valueForKey:@"quote_default"] boolValue];
	}
}



#pragma mark - Creating
/**
 *	Returns the SQLite query needed to create a column with the receiver's structure
 */
- (NSString *)creationQuery
{
	NSMutableString *query = [NSMutableString stringWithFormat:@"%@ %@", name, type];
	if (isPrimaryKey) {
		[query appendString:@" PRIMARY KEY"];
	}
	else if (isUnique) {
		[query appendString:@" UNIQUE"];
	}
	
	if (defaultString) {
		if (defaultNeedsQuotes) {
			[query appendFormat:@" DEFAULT \"%@\"", defaultString];
		}
		else {
			[query appendFormat:@" DEFAULT %@", defaultString];
		}
	}
	
	return query;
}



#pragma mark - Comparing
/**
 *	Two columns are considered equal if their name and type are the same
 *	Since SQLite can't update types, default values, uniqueness, primary key status and whatever in existing columns, we don't test for those properties.
 */
- (BOOL)isEqual:(id)object
{
	if (self == object) {
		return YES;
	}
	if ([object isKindOfClass:[self class]]) {
		SQLKColumnStructure *col = (SQLKColumnStructure *)object;
		if ([name isEqualToString:col.name]) {
			return ((!type && !col.type) || [type isEqualToString:col.type]);
		}
	}
	return NO;
}



#pragma mark - KVC
/**
 *	Returns the SQLite type for type variations one might use.
 *	SQLite does not respect lengths of types (e.g. INT(4) or VARCHAR(255)) but permits them in the queries. We strip those so we can compare types between
 *	columns.
 */
- (void)setType:(NSString *)aType
{
	if (aType != type) {
		aType = [aType uppercaseString];
		NSString *intSuffix = ([aType length] > 3) ? [aType substringToIndex:3] : aType;
		if ([@"INT" isEqualToString:intSuffix]) {
			type = @"INTEGER";
		}
		else {
			NSUInteger bracketPosition = [aType rangeOfString:@"("].location;
			if (NSNotFound != bracketPosition) {
				aType = [aType substringToIndex:bracketPosition];
			}
			type = [aType copy];
		}
	}
}



#pragma mark - Utilities
- (NSString *)description
{
	return [NSString stringWithFormat:@"%@ <%p> `%@` %@, primary: %i, unique: %i, default: %@", NSStringFromClass([self class]), self, name, type, isPrimaryKey, isUnique, (defaultNeedsQuotes ? [NSString stringWithFormat:@"\"%@\"", defaultString] : defaultString)];
}


@end
