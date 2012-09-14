//
//  SQLiteObject.m
//  SQLiteKit
//
//  Created by Pascal Pfiffner on 22.09.09.
//  Copyright 2009 Pascal Pfiffner. All rights reserved.
//

#import "SQLiteObject.h"
#import "sqlk.h"
#import "SQLKStructure.h"
#import "SQLKTableStructure.h"
#import <sqlite3.h>
#import <objc/runtime.h>

#define SQLK_TIMING_DEBUG 0


@interface SQLiteObject ()

@property (nonatomic, readwrite, assign) BOOL hydrated;
@property (nonatomic, readwrite, assign) BOOL inDatabase;

- (BOOL)dehydrateProperties:(NSDictionary *)dict tryInsert:(BOOL)tryInsert error:(NSError *__autoreleasing *)error;

@end


@implementation SQLiteObject

@synthesize object_id = _object_id;
@synthesize db, hydrated, inDatabase;



/**
 *	Returns a new object with a database link
 */
+ (id)newWithDatabase:(FMDatabase *)aDatabase
{
	SQLiteObject *o = [self new];
	o.db = aDatabase;
	return o;
}



#pragma mark - Value Setter
/**
 *	Fills all database instance variables with the values from the dictionary
 *	@attention Dictionary entries with key "id" are assumed to be the object id!
 *	@attention Dictionary entries that are not describing a database value are skipped
 */
- (void)setFromDictionary:(NSDictionary *)dict
{
	[self autofillFrom:dict overwrite:NO];
}

/**
 *	Calls "autofillFromDictionary:overwrite:" with YES for overwrite, thus also setting the object_id if it is in the dictionary.
 *	If you use this method, the receiver is assumed to be present in the database already.
 *	@attention Dictionary entries with key "id" are assumed to be the object id!
 */
- (void)hydrateFromDictionary:(NSDictionary *)dict
{
	inDatabase = YES;
	[self autofillFrom:dict overwrite:YES];
}

/**
 *	Fills all instance variables ending with an underscore with the corresponding values from the dictionary
 *	@param dict The dictionary to use
 *	@param overwrite If YES, if the primary key given in the dictionary differs from this instance's id, the primary key will be overwritten
 *	@attention Dictionary entries with key "id" are assumed to be the object id!
 */
- (void)autofillFrom:(NSDictionary *)dict overwrite:(BOOL)overwrite
{
	// make sure we get a dictionary. This step prevents crashes due to direct feeding of JSON that doesn't have the structure the dev thinks it always has.
	if (![dict isKindOfClass:[NSDictionary class]]) {
		if (dict) {
			SQLog(@"We need a dictionary to autofill, got this instead: %@", dict);
		}
		return;
	}
	
	// let's go
	if ([dict count] > 0) {
		NSString *tableKey = [isa tableKey];
		
		// loop all db-ivars and assign appropriately
		for (NSString *aKey in [isa dbVariables]) {
			id value = [dict objectForKey:aKey];
			if (value) {
				
				// handle the primary key
				if ([aKey isEqualToString:tableKey]) {
					if ([value isKindOfClass:[NSString class]] && [[NSString stringWithFormat:@"%d", [value integerValue]] isEqualToString:value]) {
						value = [NSNumber numberWithInteger:[value integerValue]];
					}
					
					if (!_object_id) {
						self.object_id = value;
					}
					else if (overwrite) {
						if (![_object_id isEqual:value]) {
							SQLog(@"We're overwriting the object with a different key!");
							self.object_id = value;
						}
					}
				}
				
				// handle any other ivar
				else {
					if ([NSNull null] == value) {
						value = nil;
					}
					NSString *ivarKey = [aKey stringByAppendingString:@"_"];
					@try {
						[self setValue:value forKey:ivarKey];
					}
					@catch (NSException *exception) {
						SQLog(@"Can not set value for key \"%@\": %@", ivarKey, exception);
					}
				}
			}
		}
		
		// if object_id is not yet set but the dictionary has an "id" or "<tableKey>" entry, use that
		if (!_object_id) {
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
+ (NSString *)tableName;
{
	return @"t1";
}

/**
 *	The column name of the primary id column, holding the unique row identifier
 */
+ (NSString *)tableKey
{
	return @"key";
}

/**
 *	The query used to hydrate the instance from its database values.
 *	By default: SELECT * FROM `<tableName>` WHERE `<tableKey>` = object.key
 */
static NSString *hydrateQuery = nil;
+ (NSString *)hydrateQuery
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
- (BOOL)hydrate
{
	if (!self.db) {
		SQLog(@"We can't hydrate %@ without database", self);
		return NO;
	}
	if (!_object_id) {
		SQLog(@"We can't hydrate %@ without primary key", self);
		return NO;
	}
	
	// fetch first result (hopefully the only one), hydrate and close
	FMResultSet *res = [self.db executeQuery:[[self class] hydrateQuery], _object_id];
	[res next];
	[self hydrateFromDictionary:[res resultDictionary]];
	[res close];
	hydrated = YES;
	[self didHydrateSuccessfully:hydrated];
	
	return hydrated;
}

/**
 *	You may override this method to perform additional tasks after hydration has been completed, e.g. hydrate relationships.
 *	The default implementation does nothing.
 */
- (void)didHydrateSuccessfully:(BOOL)success
{
}



#pragma mark - Dehydrating
/**
 *	Generates an UPDATE query for all "dbVariables" WITHOUT THE TRAILING UNDERSCORE and does an INSERT if the update query didn't match any entry.
 *	Consider using "didDehydrateSuccessfully:" before deciding to override this method.
 *	@attention This method will try to insert/update for all instance variables ending with an underscore and thus FMDB will fail if the database table does not
 *	have a given column. You should NOT call this method if you want to update existing objects and have not hydrated them first.
 */
- (BOOL)dehydrate:(NSError **)error
{
	NSDictionary *dict = [self valuesForPropertiesNamed:[[self class] dbVariables]];
	return [self dehydrateProperties:dict tryInsert:YES error:error];
}


/**
 *	Fetches the current values for the given property names and runs an update query on only these values.
 *	This method filters the supplied property names array to only contain our database values, i.e. those ivars that end with an underscore.
 *	@attention Will not try to INSERT.
 *	@param propNames A set with the property names, without the trailing underscore.
 *	@param error An error pointer
 */
- (BOOL)dehydratePropertiesNamed:(NSSet *)propNames error:(NSError *__autoreleasing *)error
{
	NSMutableSet *cleanNames = [propNames mutableCopy];
	[cleanNames intersectSet:[[self class] dbVariables]];
	
	NSDictionary *dict = [self valuesForPropertiesNamed:cleanNames];
	return [self dehydrateProperties:dict tryInsert:NO error:error];
}


/**
 *	Dehydrates all values in the dictionary to their key
 *	If you use this method directly, you need to ensure that the dictionary keys are actual database columns.
 *	@param dict A dictionary where the key is the column name and the value the value to be written to the database
 *	@param tryInsert Set to YES to try an INSERT query if the UPDATE query didn't affect a row
 *	@param error An error pointer filled with an NSError object if the method returns NO
 */
- (BOOL)dehydrateProperties:(NSDictionary *)dict tryInsert:(BOOL)tryInsert error:(NSError *__autoreleasing *)error
{
#if SQLK_TIMING_DEBUG
	mach_timebase_info_data_t timebase;
	mach_timebase_info(&timebase);
	double ticksToNanoseconds = (double)timebase.numer / timebase.denom;
	uint64_t startTime = mach_absolute_time();
#endif
	
	if ([dict count] < 1) {
		NSString *errorString = [NSString stringWithFormat:@"We can't dehydrate %@ with an empty dictionary", self];
		SQLK_ERR(error, errorString, 0)
		return NO;
	}
	if (!self.db) {
		NSString *errorString = [NSString stringWithFormat:@"We can't dehydrate %@ without a database", self];
		SQLK_ERR(error, errorString, 0);
		return NO;
	}
	
	BOOL success = NO;
	NSString *query = nil;
	
	NSMutableArray *properties = [NSMutableArray arrayWithCapacity:[dict count]];
	NSMutableArray *arguments = [NSMutableArray arrayWithCapacity:[dict count]];
	
	
	// ***** UPDATE
	if (_object_id) {
		
		// distribute column names and their values in two arrays (format needed for FMDB)
		for (NSString *columnKey in [dict allKeys]) {
			[properties addObject:[NSString stringWithFormat:@"%@ = ?", columnKey]];
			[arguments addObject:[dict objectForKey:columnKey]];
		}
		
		// compose and ...
		[arguments addObject:_object_id];									// to satisfy the WHERE condition placeholder
		query = [NSString stringWithFormat:
				 @"UPDATE `%@` SET %@ WHERE `%@` = ?",
				 [[self class] tableName],
				 [properties componentsJoinedByString:@", "],
				 [[self class] tableKey]];
		
		
		// ... execute query
		success = [self.db executeUpdate:query withArgumentsInArray:arguments];
	}
	
	
	// ***** INSERT
	/// @todo If the row didn't need to change but is already there, will this cause an INSERT?
	if (tryInsert && (!_object_id || (success && [self.db changes] < 1))) {
		[properties removeAllObjects];
		[arguments removeAllObjects];
		NSMutableArray *qmarks = [NSMutableArray arrayWithCapacity:[dict count]];
		
		for (NSString *columnKey in [dict allKeys]) {
			[properties addObject:columnKey];
			[qmarks addObject:@"?"];
			[arguments addObject:[dict objectForKey:columnKey]];
		}
		
		// explicitly set primary key if we have one already
		if (_object_id && ![dict objectForKey:[[self class] tableKey]]) {
			[properties addObject:[[self class] tableKey]];
			[qmarks addObject:@"?"];
			[arguments addObject:_object_id];
		}
		
		// compose and execute query
		query = [NSString stringWithFormat:
				 @"INSERT INTO `%@` (%@) VALUES (%@)",
				 [[self class] tableName],
				 [properties componentsJoinedByString:@", "],
				 [qmarks componentsJoinedByString:@", "]];
		
		success = [self.db executeUpdate:query withArgumentsInArray:arguments];
		if (success) {
			inDatabase = YES;
			if (!_object_id) {
				self.object_id = [NSNumber numberWithLongLong:[self.db lastInsertRowId]];
			}
		}
	}
	
	// error?
	if (!success) {
		NSString *errorString = [self.db hadError] ? [self.db lastErrorMessage] : @"Unknown dehydrate error";
		SQLK_ERR(error, errorString, 600)
	}
	
	[self didDehydrateSuccessfully:success];
	
#if SQLK_TIMING_DEBUG
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
- (void)didDehydrateSuccessfully:(BOOL)success
{
}



#pragma mark - Purging/Deleting
/**
 *	Purge/delete an object from the database.
 *	@param error An error pointer which is filled if the method returns NO
 */
- (BOOL)purge:(NSError *__autoreleasing *)error
{
	if (!self.db) {
		NSString *errorMessage = [NSString stringWithFormat:@"We can't delete %@ without database", self];
		SQLK_ERR(error, errorMessage, 0)
		return NO;
	}
	if (!_object_id) {
		NSString *errorMessage = [NSString stringWithFormat:@"We can't delete %@ without primary key", self];
		SQLK_ERR(error, errorMessage, 0)
		return NO;
	}
	
	// delete
	NSString *purgeQuery = [NSString stringWithFormat:@"DELETE FROM `%@` WHERE `%@` = ?", [[self class] tableName], [[self class] tableKey]];
	BOOL success = [self.db executeUpdate:purgeQuery, _object_id];
	if (success) {
		hydrated = NO;
		inDatabase = NO;
	}
	[self didPurgeSuccessfully:success];
	
	return success;
}

/**
 *	Called after an object has been purged. You can override this to perform additional tasks (e.g. delete dependencies).
 *	The default implementation does nothing.
 *	@param success A bool indicating whether the DELETE action was successful
 */
- (void)didPurgeSuccessfully:(BOOL)success
{
}



#pragma mark - Ivar Gathering
/**
 *	Returns all instance variable names that end with an underscore and are thus assumed to be database variables.
 *
 *  This method caused me major headaches because it crashed at the line indicated below, almost at the end, in an app released to the app store but did NOT
 *  crash in debug and AdHoc builds. That's why there is the SQLK_USE_CLASS_VARIABLES_STORE switch.
 *	@return An NSArray full of NSStrings
 */
#define SQLK_USE_CLASS_VARIABLES_STORE 0

+ (NSSet *)dbVariables
{
#if SQLK_USE_CLASS_VARIABLES_STORE
	static NSMutableDictionary *ivarsPerClass = nil;
	
	NSString *className = NSStringFromClass([self class]);
	NSSet *classIvars = [ivarsPerClass objectForKey:className];
	if (!classIvars) {
#endif
		NSMutableSet *ivarSet = nil;
		
		// get instance variables that end with an underscore
		unsigned int numVars, i;
		Ivar *ivars = class_copyIvarList(self, &numVars);
		
		if (numVars > 0) {
			ivarSet = [NSMutableSet setWithCapacity:numVars];
			
			for (i = 0; i < numVars; i++) {
				const char *name = ivar_getName(ivars[i]);
				unsigned long len = strlen(name);
				if (len > 1 && '_' == name[len-1]) {
					
					// remove the trailing underscore
					char stripped_name[len];
					strcpy(stripped_name, name);
					stripped_name[len-1] = '\0';
					
					// add database column name to array
					NSString *varName = [NSString stringWithCString:stripped_name encoding:NSUTF8StringEncoding];
					if (varName) {
						[ivarSet addObject:varName];
					}
				}
			}
		}
		
		free(ivars);
#if !SQLK_USE_CLASS_VARIABLES_STORE
		return ivarSet;
#else
		// store
		classIvars = [ivarSet copy];
		if (className && classIvars) {
			if (!ivarsPerClass) {
				ivarsPerClass = [NSMutableDictionary new];
			}
			[ivarsPerClass setObject:classIvars forKey:className];			//< This crashed in an app store build but not in debug nor AdHoc versions...
		}
	}
	
	return classIvars;
#endif
}

/**
 *	Returns an NSDictionary with the receiver's properties for the given property names
 *	@param propNames An array containing NSString property names, which will be fed to "valueForKey:"
 */
- (NSMutableDictionary *)valuesForPropertiesNamed:(NSSet *)propNames
{
	if ([propNames count] < 1) {
		return nil;
	}
	
	NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithCapacity:[propNames count]];
	
	// insert values into dictionary
	for (NSString *varName in propNames) {
		id value = nil;
		@try {
			value = [self valueForKey:varName];
		}
		@catch (NSException *exception) {
			SQLog(@"Can not get value for key \"%@\": %@", varName, exception);
		}
		if (!value) {
			value = [NSNull null];
		}
		[dict setObject:value forKey:varName];
	}
	
	return dict;
}



#pragma mark - Utilities
/**
 *	An object is equal if it has the same pointer or if it is of the same class and has the same object_id
 */
- (BOOL)isEqual:(id)object
{
	if (self == object) {
		return YES;
	}
	
	if ([object isMemberOfClass:[self class]]) {
		id otherKey = [(SQLiteObject *)object object_id];
		if (otherKey) {
			return [_object_id isEqual:otherKey];
		}
	}
	return NO;
}

- (NSUInteger)hash
{
	return [_object_id hash];
}


- (NSString *)description
{
	return [NSString stringWithFormat:@"%@ <%p> '%@'", NSStringFromClass([self class]), self, _object_id];
}


@end
