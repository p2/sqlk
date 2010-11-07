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
		NSString *tk = [[self class] tableKey];
		NSDictionary *linker = [[self class] sqlPropertyLinker];
		
		// loop all keys and assign appropriately
		for (NSString *k in [dict allKeys]) {
			id value = [dict objectForKey:k];
			NSString *linkedKey = [linker objectForKey:k];
			
			if ([k isEqualToString:tk]) {
				self.key = value;
			}
			else if (linkedKey) {
				[self setValue:value forKey:linkedKey];
			}
			else {
				[self setValue:value forKey:k];
			}
		}
	}
}

- (void) setValue:(id)value forUndefinedKey:(NSString *)undefKey
{
	// NSObject's implementation raises an exception. We are more benevolent here.
	DLog(@"There is no instance variable for key \"%@\"", undefKey);
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

- (void) hydrate
{
	if (!db) {
		DLog(@"We can't hydrate without database");
		return;
	}
	if (!key) {
		DLog(@"We can't hydrate without primary key");
		return;
	}
	
	// fetch first result (hopefully the only one)
	FMResultSet *res = [db executeQuery:[[self class] hydrateQuery], self.key];
	[res next];
	
	// hydrate and close
	[self setFromDict:[res resultDict]];
	[res close];
	hydrated = YES;
}
#pragma mark -



#pragma mark Dehydrating
- (void) dehydrate
{
	// "UPDATE `t1` SET `x` = ? WHERE `key` = ?";
	DLog(@"Implement me!");
	hydrated = NO;
}
#pragma mark -



#pragma mark Utilities
- (NSString *) description
{
	return [NSString stringWithFormat:@"%@ <0x%x> '%@'", NSStringFromClass([self class]), self, key];
}


@end
