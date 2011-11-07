//
//  SQLiteStructureTableRow.m
//  SQLiteKit
//
//  Created by Pascal Pfiffner on 11.09.10.
//	

#import "SQLKColumnStructure.h"


@implementation SQLKColumnStructure

@synthesize table;
@synthesize name, type;
@synthesize isPrimaryKey, isUnique;
@synthesize defaultNeedsQuotes, defaultString;

- (void)dealloc
{
	[name release];
	[type release];
	[defaultString release];
	
	[super dealloc];
}

/**
 *	Return a column belonging to the given table
 */
+ (SQLKColumnStructure *)columnForTable:(SQLKTableStructure *)aTable
{
	SQLKColumnStructure *c = [self new];
	c.table = aTable;
	
	return [c autorelease];
}



#pragma mark - Creating and Verifying
/**
 *	Returns the SQLite query needed to create a column with the receiver's structure
 */
- (NSString *)creationQuery
{
	NSMutableString *query = [NSMutableString stringWithFormat:@"%@ %@", name, [self fullType]];
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


/**
 *	Two columns are considered equal if they have the same name and "isEqualToColumn:error:" returns YES
 */
- (BOOL)isEqual:(id)object
{
	if ([object isKindOfClass:[self class]] && [name isEqualToString:[object name]]) {
		return [self isEqualToColumn:(SQLKColumnStructure *)object error:NULL];
	}
	return NO;
}

/**
 *	Two columns are considered equal if their creation query strings are the same
 *	@todo Improve
 */
- (BOOL)isEqualToColumn:(SQLKColumnStructure *)oc error:(NSError **)error
{
	BOOL equal = NO;
	if (oc) {
		equal = [[self creationQuery] isEqualToString:[oc creationQuery]];
		if (!equal) {
			NSString *errorString = [NSString stringWithFormat:@"Columns are not equal (%@  --  %@)", [self creationQuery], [oc creationQuery]];
			SQLK_ERR(error, errorString, 669)
		}
	}
	return equal;
}



#pragma mark - Utilities
/**
 *	Returns the SQLite type for type variations one might use
 */
- (NSString *)fullType
{
	if ([@"int" isEqualToString:type] || [@"INT" isEqualToString:type]) {
		self.type = @"INTEGER";
	}
	return type;
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"%@ <0x%x> `%@` %@, primary: %i, unique: %i, default: %@", NSStringFromClass([self class]), self, name, type, isPrimaryKey, isUnique, (defaultNeedsQuotes ? [NSString stringWithFormat:@"\"%@\"", defaultString] : defaultString)];
}


@end
