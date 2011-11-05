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
#import "SQLKStructure.h"
#import "SQLKTableStructure.h"
#import <sqlite3.h>
#import <objc/runtime.h>

#define TIMING_DEBUG 0


@interface SQLiteObject ()

@property (nonatomic, readwrite, assign) BOOL hydrated;

@end


@implementation SQLiteObject

@synthesize db;
@synthesize object_id;
@synthesize hydrated;




+ (id) object
{
	return [[self class] new];
}

+ (id) objectOfDB:(FMDatabase *)aDatabase
{
	SQLiteObject *o = [[self class] new];
	o.db = aDatabase;
	return o;
}
#pragma mark -



#pragma mark Value Setter
- (void) setFromDictionary:(NSDictionary *)dict
{
	[self autofillFrom:dict overwrite:NO];
}

- (void) autofillFrom:(NSDictionary *)dict overwrite:(BOOL)overwrite
{
	if ([dict count] > 0) {
		NSString *tableKey = [[self class] tableKey];
		
		// loop all keys and assign appropriately
		for (NSString *aKey in [dict allKeys]) {
			id value = [dict objectForKey:aKey];
			
			// handle the key
			if ([aKey isEqualToString:tableKey]) {
				if (!object_id) {
					self.object_id = value;
				}
				else if (overwrite) {
					if (![object_id isEqual:value]) {
						DLog(@"We're overwriting the object with a different key!");
						self.object_id = value;
					}
				}
			}
			
			// handle any other ivar
			else {
				if ([NSNull null] == value) {
					value = nil;
				}
				[self setValue:value forKey:aKey];
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
		DLog(@"We can't hydrate %@ without database", self);
		return NO;
	}
	if (!object_id) {
		DLog(@"We can't hydrate %@ without primary key", self);
		return NO;
	}
	
	// fetch first result (hopefully the only one), hydrate and close
	FMResultSet *res = [db executeQuery:[[self class] hydrateQuery], self.object_id];
	
	[res next];
	[self hydrateFromDictionary:[res resultDict]];
	[res close];
	hydrated = YES;
	[self didHydrateSuccessfully:hydrated];
	
	return hydrated;
}

- (void) hydrateFromDictionary:(NSDictionary *)dict
{
	[self autofillFrom:dict overwrite:YES];
}

- (void) didHydrateSuccessfully:(BOOL)success
{
}
#pragma mark -



#pragma mark Dehydrating
- (NSMutableDictionary *) ivarDictionary
{
	NSMutableDictionary *ivarDict = nil;
	
	// get instance variables
	unsigned int numVars, i;
	Ivar *ivars = class_copyIvarList([self class], &numVars);
	
	if (numVars > 0) {
		ivarDict = [NSMutableDictionary dictionaryWithCapacity:numVars];
		
		for (i = 0; i < numVars; i++) {
			Ivar var = ivars[i];
			const char* name = ivar_getName(var);
			NSString *theKey = [NSString stringWithUTF8String:name];
			
			// insert value into dictionary
			id value = [self valueForKey:theKey];
			if (!value) {
				value = [NSNull null];
			}
			[ivarDict setObject:value forKey:theKey];
		}
	}
	
	free(ivars);
	return ivarDict;
}

- (BOOL) dehydrate:(NSError **)error
{
#if TIMING_DEBUG
	mach_timebase_info_data_t timebase;
	mach_timebase_info(&timebase);
	double ticksToNanoseconds = (double)timebase.numer / timebase.denom;
	uint64_t startTime = mach_absolute_time();
#endif
	
	if (!db) {
		DLog(@"We can't dehydrate without a database");
		return NO;
	}
	if (!object_id) {
		DLog(@"We can't dehydrate without a primary key");
		return NO;
	}
	
	NSDictionary *dict = [self ivarDictionary];
	if (!dict) {
		DLog(@"We can't dehydrate without an ivar dictionary");
		return NO;
	}
	
	// check the table fields at our disposal
	SQLKStructure *ourDB = [SQLKStructure structureFromDatabase:[NSURL fileURLWithPath:[db databasePath]]];
	SQLKTableStructure *ourTable = [ourDB tableWithName:[[self class] tableName]];
	if (!ourTable) {
		DLog(@"Unable to determine the table structure for table named %@ in %@. Trying to continue.", [[self class] tableName], db);
	}
	
	
	// ** try to update
	BOOL success = NO;
	NSString *query = nil;
	
	NSMutableArray *properties = [NSMutableArray arrayWithCapacity:[dict count]];
	NSMutableArray *arguments = [NSMutableArray arrayWithCapacity:[dict count]];
	
	for (NSString *columnKey in [dict allKeys]) {
		if (!ourTable || [ourTable hasColumnNamed:columnKey]) {
			[properties addObject:[NSString stringWithFormat:@"%@ = ?", columnKey]];
			[arguments addObject:[dict objectForKey:columnKey]];
		}
	}
	
	// compose and execute query
	[arguments addObject:object_id];		// to satisfy the WHERE condition placeholder
	query = [NSString stringWithFormat:
			 @"UPDATE `%@` SET %@ WHERE `%@` = ?",
			 [[self class] tableName],
			 [properties componentsJoinedByString:@", "],
			 [[self class] tableKey]];
	
	success = [db executeUpdate:query withArgumentsInArray:arguments];
	
	
	// ** insert if needed (success is YES if the query succeeded, no matter how many changes occurred)
	if (success && [db changes] < 1) {
		[properties removeAllObjects];
		[arguments removeAllObjects];
		NSMutableArray *qmarks = [NSMutableArray arrayWithCapacity:[dict count]];
		
		for (NSString *columnKey in [dict allKeys]) {
			if (!ourTable || [ourTable hasColumnNamed:columnKey]) {
				[properties addObject:columnKey];
				[qmarks addObject:@"?"];
				[arguments addObject:[dict objectForKey:columnKey]];
			}
		}
		
		// explicitly set primary key if we have one already
		if (object_id && ![dict objectForKey:[[self class] tableKey]]) {
			[properties addObject:[[self class] tableKey]];
			[qmarks addObject:@"?"];
			[arguments addObject:object_id];
		}
		
		// compose and execute query
		query = [NSString stringWithFormat:
				 @"INSERT INTO `%@` (%@) VALUES (%@)",
				 [[self class] tableName],
				 [properties componentsJoinedByString:@", "],
				 [qmarks componentsJoinedByString:@", "]];
		
		success = [db executeUpdate:query withArgumentsInArray:arguments];
	}
	
	// error?
	if (!success) {
		NSString *errorString = [db hadError] ? [db lastErrorMessage] : @"Unknown dehydrate error";
		DLog(@"dehydrate failed: %@", errorString);
		if (NULL != error) {
			NSDictionary *userDict = [NSDictionary dictionaryWithObject:errorString forKey:NSLocalizedDescriptionKey];
			*error = [NSError errorWithDomain:NSCocoaErrorDomain code:676 userInfo:userDict];
		}
	}
	
	[self didDehydrateSuccessfully:success];
	
#if TIMING_DEBUG
	uint64_t elapsedTime = mach_absolute_time() - startTime;
	double elapsedTimeInNanoseconds = elapsedTime * ticksToNanoseconds;
	NSLog(@"dehydrate %@: %f millisec", self, elapsedTimeInNanoseconds / 1000000);
#endif
	return success;
}

- (void) didDehydrateSuccessfully:(BOOL)success
{
}
#pragma mark -



#pragma mark Key-Value Overrides
// TODO: Implement class-checking setValue:forKey:

- (id) valueForUndefinedKey:(NSString *)aKey
{
	// don't throw an error
	return nil;
}

- (void) setValue:(id)value forUndefinedKey:(NSString *)aKey
{
	// don't throw an error
}
#pragma mark -



#pragma mark Utilities
- (BOOL) isEqual:(id)object
{
	if (self == object) {
		return YES;
	}
	
	if ([object isKindOfClass:[self class]]) {
		id otherKey = [(SQLiteObject *)object object_id];
		if (otherKey) {
			return [object_id isEqual:otherKey];
		}
	}
	return NO;
}


- (NSString *) description
{
	return [NSString stringWithFormat:@"%@ <0x%x> '%@'", NSStringFromClass([self class]), self, object_id];
}


@end
