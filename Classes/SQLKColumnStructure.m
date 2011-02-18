//
//  SQLiteStructureTableRow.m
//  SQLiteKit
//
//  Created by Pascal Pfiffner on 11.09.10.
//	
//	Instances of this class represent columns belonging to a SQLKTableStructure
//

#import "SQLKColumnStructure.h"


@implementation SQLKColumnStructure

@synthesize table;
@synthesize name;
@synthesize type;
@synthesize isPrimaryKey;
@synthesize isUnique;
@synthesize defaultNeedsQuotes;
@synthesize defaultString;

- (void) dealloc
{
	[name release];
	[type release];
	[defaultString release];
	
	[super dealloc];
}

+ (SQLKColumnStructure *) columnForTable:(SQLKTableStructure *)aTable
{
	SQLKColumnStructure *c = [self new];
	c.table = aTable;
	
	return [c autorelease];
}
#pragma mark -



#pragma mark Creating and Verifying
- (NSString *) creationQuery
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


- (BOOL) isEqual:(id)object
{
	if ([object isKindOfClass:[self class]]) {
		return [self isEqualToColumn:(SQLKColumnStructure *)object error:NULL];
	}
	return NO;
}

- (BOOL) isEqualToColumn:(SQLKColumnStructure *)oc error:(NSError **)error
{
	BOOL equal = NO;
	if (oc) {
		equal = [[self creationQuery] isEqualToString:[oc creationQuery]];
		if (!equal && NULL != error) {
			NSDictionary *userDict = [NSDictionary dictionaryWithObject:@"Columns are not equal" forKey:NSLocalizedDescriptionKey];
			*error = [NSError errorWithDomain:NSCocoaErrorDomain code:669 userInfo:userDict];
		}
	}
	return equal;
}
#pragma mark -



#pragma mark Utilities
- (NSString *) fullType
{
	if ([@"int" isEqualToString:type] || [@"INT" isEqualToString:type]) {
		self.type = @"INTEGER";
	}
	return type;
}

- (NSString *) description
{
	return [NSString stringWithFormat:@"%@ <0x%x> `%@` %@, primary: %i, unique: %i, default: %@", NSStringFromClass([self class]), self, name, type, isPrimaryKey, isUnique, (defaultNeedsQuotes ? [NSString stringWithFormat:@"\"%@\"", defaultString] : defaultString)];
}


@end
