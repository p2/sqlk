//
//  SQLiteStructureTableRow.m
//  SQLiteKit
//
//  Created by Pascal Pfiffner on 11.09.10.
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
 *	Two columns are considered equal if their name, type, default values, uniqueness and primary key status are all the same
 */
- (BOOL)isEqual:(id)object
{
	if (self == object) {
		return YES;
	}
	if ([object isKindOfClass:[self class]]) {
		if ([name isEqualToString:[object name]]) {
			NSString *oType = [object type];
			if ((!type && !oType) || [type isEqualToString:oType]) {
				NSString *oDefault = [object defaultString];
				if ((!defaultString && !oDefault) || [defaultString isEqualToString:oDefault]) {
					if (isUnique == [object isUnique]) {
						return (isPrimaryKey == [object isPrimaryKey]);
					}
				}
			}
		}
	}
	return NO;
}



#pragma mark - KVC
/**
 *	Returns the SQLite type for type variations one might use
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
