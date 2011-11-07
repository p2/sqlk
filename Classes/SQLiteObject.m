//
//  SQLiteObject.m
//  SQLiteKit
//
//  Created by Pascal Pfiffner on 22.09.09.
//  Copyright 2009 Pascal Pfiffner. All rights reserved.
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



/**
 *	Returns a new object with a database link
 */
+ (id)objectOfDB:(FMDatabase *)aDatabase
{
	SQLiteObject *o = [self new];
	o.db = aDatabase;
	return o;
}



#pragma mark - Value Setter
/**
 *	Fills all instance variables beginning with an underscore with the corresponding values from the dictionary
 *	@attention Dictionary entries with key "id" are assumed to be the object id!
 */
- (void)setFromDictionary:(NSDictionary *)dict
{
	[self autofillFrom:dict overwrite:NO];
}

/**
 *	Calls "autofillFromDictionary:overwrite:" with YES for overwrite, thus setting the object_id
 *	@attention Dictionary entries with key "id" are assumed to be the object id!
 */
- (void) hydrateFromDictionary:(NSDictionary *)dict
{
	[self autofillFrom:dict overwrite:YES];
}

/**
 *	Fills all instance variables beginning with an underscore with the corresponding values from the dictionary
 *	@param dict The dictionary to use
 *	@param overwrite If YES, if the table key given in the dictionary differs from this instance's id, the key will be overwritten
 *	@attention Dictionary entries with key "id" are assumed to be the object id!
 */
- (void)autofillFrom:(NSDictionary *)dict overwrite:(BOOL)overwrite
{
	if ([dict count] > 0) {
		NSString *tableKey = [[self class] tableKey];
		NSDictionary *dbvars = [self dbValues];
		
		// loop all db-ivars and assign appropriately
		for (NSString *aKey in [dbvars allKeys]) {
			id value = [dict objectForKey:aKey];
			if (value) {
				
				// handle the key
				if ([aKey isEqualToString:tableKey]) {
					if ([value isKindOfClass:[NSString class]] && [[NSString stringWithFormat:@"%d", [value integerValue]] isEqualToString:value]) {
						value = [NSNumber numberWithInteger:[value integerValue]];
					}
					
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
					NSString *ivarKey = [@"_" stringByAppendingString:aKey];
					@try {
						[self setValue:value forKey:ivarKey];
					}
					@catch (NSException *exception) {
						DLog(@"Catched exception when setting value for key \"%@\": %@", ivarKey, exception);
					}
				}
			}
		}
		
		// if object_id is not yet set but the dictionary has an "id" or "<tableKey>" entry, use that
		if (!object_id) {
			id value = nil;
			if ([dict objectForKey:tableKey]) {
				value = [dict objectForKey:tableKey];
			}
			else if ([dict objectForKey:@"id"]) {
				value = [dict objectForKey:@"id"];
			}
			
			if (value) {
				if ([value isKindOfClass:[NSString class]] && [[NSString stringWithFormat:@"%d", [value integerValue]] isEqualToString:value]) {
					value = [NSNumber numberWithInteger:[value integerValue]];
				}
				self.object_id = value;
			}
		}
	}
}



#pragma mark - Hydrating
/**
 *	The SQLite table being represented by these objects
 */
+ (NSString *) tableName;
{
	return @"t1";
}

/**
 *	The column name of the primary id column, holding the unique row identifier
 */
+ (NSString *) tableKey
{
	return @"key";
}

/**
 *	The query used to hydrate the instance from its database values.
 *	By default: SELECT * FROM `<tableName>` WHERE `<tableKey>` = object.key
 */
static NSString *hydrateQuery = nil;
+ (NSString *) hydrateQuery
{
	if (nil == hydrateQuery) {
		hydrateQuery = [[NSString alloc] initWithFormat:@"SELECT * FROM `%@` WHERE `%@` = ?", [self tableName], [self tableKey]];
	}
	return hydrateQuery;
}



/**
 *	Calls "hydrateFromDictionary:" after performing "hydrateQuery"
 *	Consider using "didHydrateSuccessfully:" before deciding to override this method.
 */
- (BOOL) hydrate
{
	if (!self.db) {
		DLog(@"We can't hydrate %@ without database", self);
		return NO;
	}
	if (!object_id) {
		DLog(@"We can't hydrate %@ without primary key", self);
		return NO;
	}
	
	// fetch first result (hopefully the only one), hydrate and close
	FMResultSet *res = [self.db executeQuery:[[self class] hydrateQuery], self.object_id];
	
	[res next];
	[self hydrateFromDictionary:[res resultDict]];
	[res close];
	hydrated = YES;
	[self didHydrateSuccessfully:hydrated];
	
	return hydrated;
}

/**
 *	You may override this method to perform additional tasks after hydration has been completed, e.g. hydrate relationships.
 *	The default implementation does nothing.
 */
- (void) didHydrateSuccessfully:(BOOL)success
{
}



#pragma mark - Dehydrating
/**
 *	Returns all instance variable names that begin with an underscore
 *	@return An NSArray full of NSStrings
 */
static NSMutableDictionary *ivarsPerClass = nil;

+ (NSArray *)dbVariables
{
	NSString *className = NSStringFromClass([self class]);
	NSArray *classIvars = [ivarsPerClass objectForKey:className];
	if (!classIvars) {
		NSMutableArray *ivarArr = nil;
		
		// get instance variables
		unsigned int numVars, i;
		Ivar *ivars = class_copyIvarList(self, &numVars);
		
		if (numVars > 0) {
			ivarArr = [NSMutableArray arrayWithCapacity:numVars];
			
			for (i = 0; i < numVars; i++) {
				const char *name = ivar_getName(ivars[i]);
				if (sizeof(name) > 0 && '_' == name[0]) {
					name++;			/// @attention removes underscore
					NSString *varName = [NSString stringWithCString:name encoding:NSUTF8StringEncoding];
					if (varName) {
						[ivarArr addObject:varName];
					}
				}
			}
		}
		
		free(ivars);
		
		// store
		classIvars = [ivarArr copy];
		if (!ivarsPerClass) {
			ivarsPerClass = [NSMutableDictionary new];
		}
		[ivarsPerClass setObject:classIvars forKey:className];
	}
	
	return classIvars;
}

/**
 *	Returns an NSDictionary with the receivers properties that are stored in the database (i.e. their ivar names start with an underscore)
 */
- (NSMutableDictionary *)dbValues
{
	NSArray *vars = [[self class] dbVariables];
	NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithCapacity:[vars count]];
	
	// insert values into dictionary
	for (NSString *varName in vars) {
		id value = nil;
		@try {
			value = [self valueForKey:varName];
		}
		@catch (NSException *exception) {
			DLog(@"Catched exception when getting value for key \"%@\": %@", varName, exception);
		}
		if (!value) {
			value = [NSNull null];
		}
		[dict setObject:value forKey:varName];
	}
	
	return dict;
}

/**
 *	Generates an UPDATE query for all "dbValues" WITHOUT THE LEADING UNDERSCORE and does an INSERT if the update query didn't match any entry.
 *	Consider using "didDehydrateSuccessfully:" before deciding to override this method.
 */
- (BOOL)dehydrate:(NSError **)error
{
#if TIMING_DEBUG
	mach_timebase_info_data_t timebase;
	mach_timebase_info(&timebase);
	double ticksToNanoseconds = (double)timebase.numer / timebase.denom;
	uint64_t startTime = mach_absolute_time();
#endif
	
	if (!self.db) {
		DLog(@"We can't dehydrate %@ without a database", self);
		return NO;
	}
	
	NSDictionary *dict = [self dbValues];
	if (!dict) {
		DLog(@"We can't dehydrate %@ without ivars for the database", self);
		return NO;
	}
	
	// check the table fields at our disposal
	/// @todo This is probably a lot faster if we cache the table structure per class or something along these lines
	SQLKStructure *ourDB = [SQLKStructure structureFromDatabase:[NSURL fileURLWithPath:[self.db databasePath]]];
	SQLKTableStructure *ourTable = [ourDB tableWithName:[[self class] tableName]];
	if (!ourTable) {
		DLog(@"Unable to determine the table structure for table named %@ in %@, cannot dehydrate", [[self class] tableName], self.db);
		return NO;
	}
	
	BOOL success = NO;
	NSString *query = nil;
	
	NSMutableArray *properties = [NSMutableArray arrayWithCapacity:[dict count]];
	NSMutableArray *arguments = [NSMutableArray arrayWithCapacity:[dict count]];
	
	
	// ***** UPDATE
	if (self.object_id) {
		
		// distribute column names and their values in two arrays (format needed for FMDB)
		for (NSString *columnKey in [dict allKeys]) {
			if (!ourTable || [ourTable hasColumnNamed:columnKey]) {
				[properties addObject:[NSString stringWithFormat:@"%@ = ?", columnKey]];
				[arguments addObject:[dict objectForKey:columnKey]];
			}
		}
		
		// compose and ...
		[arguments addObject:object_id];									///< to satisfy the WHERE condition placeholder
		query = [NSString stringWithFormat:
				 @"UPDATE `%@` SET %@ WHERE `%@` = ?",
				 [[self class] tableName],
				 [properties componentsJoinedByString:@", "],
				 [[self class] tableKey]];
		
		
		// ... EXECUTE QUERY
		success = [self.db executeUpdate:query withArgumentsInArray:arguments];
	}
	
	
	// ***** INSERT
	if (!self.object_id || (success && [self.db changes] < 1)) {
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
		if (self.object_id && ![dict objectForKey:[[self class] tableKey]]) {
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
		
		success = [self.db executeUpdate:query withArgumentsInArray:arguments];
		if (success && !self.object_id) {
			self.object_id = [NSNumber numberWithLongLong:[self.db lastInsertRowId]];
		}
	}
	
	// error?
	if (!success) {
		NSString *errorString = [self.db hadError] ? [self.db lastErrorMessage] : @"Unknown dehydrate error";
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

/**
 *	You can override this method to perform additional tasks after dehydration (e.g. dehydrate properties).
 *	The default implementation does nothing.
 */
- (void) didDehydrateSuccessfully:(BOOL)success
{
}



#pragma mark - Utilities
/**
 *	An object is equal if it has the same address or if it is of the same class and has the same object_id
 */
- (BOOL)isEqual:(id)object
{
	if (self == object) {
		return YES;
	}
	
	if ([object isMemberOfClass:[self class]]) {
		id otherKey = [(SQLiteObject *)object object_id];
		if (otherKey) {
			return [object_id isEqual:otherKey];
		}
	}
	return NO;
}


- (NSString *)description
{
	return [NSString stringWithFormat:@"%@ <0x%x> '%@'", NSStringFromClass([self class]), self, object_id];
}


@end
