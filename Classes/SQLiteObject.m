//
//  SQLiteObject.m
//  SQLiteKit
//
//  Created by Pascal Pfiffner on 22.09.09.
//  Copyright 2009 Pascal Pfiffner. All rights reserved.
//	
//	Base object for your objects hydrated from SQLite
//	Basically, one class represents from one table, one instance of the class representing one data row
//

#import "SQLiteObject.h"
#import <sqlite3.h>


@interface SQLiteObject ()

@property (nonatomic, readwrite, assign) BOOL hydrated;

@end



@implementation SQLiteObject

@synthesize key;
@synthesize db;
@synthesize hydrated;


- (void) dealloc
{
	[key release];
	
	[super dealloc];
}


+ (id) objectOfDB:(FMDatabase *)aDatabase
{
	SQLiteObject *o = [[[self class] alloc] init];
	o.db = aDatabase;
	return [o autorelease];
}
#pragma mark -



#pragma mark Value Setter
- (void) setFromDict:(NSDictionary *)dict
{
	if (nil != dict) {
		NSString *tableKey = [[self class] tableKey];
		NSDictionary *linker = [[self class] sqlPropertyLinker];
		
		// loop all keys and assign appropriately
		for (NSString *aKey in [dict allKeys]) {
			id value = [dict objectForKey:aKey];
			NSString *linkedKey = [linker objectForKey:aKey];
			
			if ([aKey isEqualToString:tableKey] || [linkedKey isEqualToString:@"key"]) {
				// we don't allow to set the key here, it will be set automatically in hydrate
				// changing this may break a lot of implementations, choose wisely!
			}
			else if (linkedKey) {
				@try {
					[self setValue:value forKey:linkedKey];
				}
				@catch (NSException *e) {
					DLog(@"There is no instance variable for linked key \"%@\"", linkedKey);
				}
			}
			else {
				@try {
					[self setValue:value forKey:aKey];
				}
				@catch (NSException *e) {
					DLog(@"There is no instance variable for key \"%@\"", aKey);
				}
			}
		}
	}
}
#pragma mark -



#pragma mark Hydrating
+ (NSString *) tableName;
{
	return @"t1";
}

+ (NSString *) tableKey
{
	return @"key";
}

+ (NSDictionary *) sqlPropertyLinker
{
	return nil;
}

static NSString *hydrateQuery = nil;
+ (NSString *) hydrateQuery
{
	if (nil == hydrateQuery) {
		hydrateQuery = [[NSString alloc] initWithFormat:@"SELECT * FROM `%@` WHERE `%@` = ?", [self tableName], [self tableKey]];
	}
	return hydrateQuery;
}

- (BOOL) hydrate
{
	if (!db) {
		DLog(@"We can't hydrate without database");
		return NO;
	}
	if (!key) {
		DLog(@"We can't hydrate without primary key");
		return NO;
	}
	
	// fetch first result (hopefully the only one)
	FMResultSet *res = [db executeQuery:[[self class] hydrateQuery], self.key];
	[res next];
	
	// hydrate and close
	NSDictionary *result = [res resultDict];
	self.key = [result objectForKey:[[self class] tableKey]];
	[self setFromDict:result];
	[res close];
	hydrated = YES;
	
	return hydrated;
}
#pragma mark -



#pragma mark Dehydrating
- (NSDictionary *) dehydrateDictionary
{
	return nil;
}

- (BOOL) dehydrate:(NSError **)error
{
	if (!db) {
		DLog(@"We can't dehydrate without a database");
		return NO;
	}
	NSDictionary *dict = [self dehydrateDictionary];
	if (!dict) {
		DLog(@"We can't dehydrate without a dehydrate dictionary");
		return NO;
	}
	
	// prepare to rock
	BOOL success = NO;
	NSString *query = nil;
	
	// ** insert if needed
	if (!self.key) {
		NSMutableArray *properties = [NSMutableArray arrayWithCapacity:[dict count]];
		NSMutableArray *qmarks = [NSMutableArray arrayWithCapacity:[dict count]];
		NSMutableArray *arguments = [NSMutableArray arrayWithCapacity:[dict count]];
		for (NSString *dKey in [dict allKeys]) {
			[properties addObject:dKey];
			[qmarks addObject:@"?"];
			[arguments addObject:[dict objectForKey:dKey]];
		}
		
		query = [NSString stringWithFormat:
				 @"INSERT INTO `%@` (%@) VALUES (%@)",
				 [[self class] tableName],
				 [properties componentsJoinedByString:@", "],
				 [qmarks componentsJoinedByString:@", "]];
		
		// execute
		success = [db executeUpdate:query withArgumentsInArray:arguments];
		if (success) {
			self.key = [NSNumber numberWithLongLong:[db lastInsertRowId]];
		}
	}
	
	// ** else update
	else {
		NSMutableArray *properties = [NSMutableArray arrayWithCapacity:[dict count]];
		NSMutableArray *arguments = [NSMutableArray arrayWithCapacity:[dict count]];
		for (NSString *dKey in [dict allKeys]) {
			[properties addObject:[NSString stringWithFormat:@"%@ = ?", dKey]];
			[arguments addObject:[dict objectForKey:dKey]];
		}
		
		query = [NSString stringWithFormat:
				 @"UPDATE `%@` SET %@ WHERE `%@` = ?",
				 [[self class] tableName],
				 [properties componentsJoinedByString:@", "],
				 [[self class] tableKey]];
		[arguments addObject:self.key];
		
		// execute
		success = [db executeUpdate:query withArgumentsInArray:arguments];
	}
	
	// error?
	if (!success && NULL != error) {
		NSString *errorString = [db hadError] ? [db lastErrorMessage] : @"Unknown dehydrate error";
		NSDictionary *userDict = [NSDictionary dictionaryWithObject:errorString forKey:NSLocalizedDescriptionKey];
		*error = [NSError errorWithDomain:NSCocoaErrorDomain code:676 userInfo:userDict];
	}
	
	return success;
}
#pragma mark -



#pragma mark Utilities
- (BOOL) isEqual:(id)object
{
	if ([object isKindOfClass:[self class]]) {
		NSNumber *otherKey = [(SQLiteObject *)object key];
		if (otherKey) {
			return [key isEqualToNumber:otherKey];
		}
	}
	return NO;
}


- (NSString *) description
{
	return [NSString stringWithFormat:@"%@ <0x%x> '%@'", NSStringFromClass([self class]), self, key];
}


@end
