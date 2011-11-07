//
//  SQLiteObject.h
//  SQLiteKit
//
//  Created by Pascal Pfiffner on 22.09.09.
//  Copyright 2009 Pascal Pfiffner. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FMDatabase.h"
#import "FMResultSet.h"


/**
 *	Base object for your objects hydrated from SQLite
 *	Basically, one class represents one table, one instance of the class represents one table entry. All instance variables beginning with an
 *	underscore will be fetched from and written to the database!
 *	@attention Note that this class doesn't throw exceptions on "valueForUndefinedKey:" and "setValue:forUndefinedKey:", but it does alert you
 *	when the class is not key-value coding compliant for a given path to give you the opportunity to adjust the class to match the database
 */
@interface SQLiteObject : NSObject

@property (nonatomic, unsafe_unretained) FMDatabase *db;
@property (nonatomic, strong) id object_id;										///< The object id can either be an NSNumber or NSString (e.g. for UUIDs)
@property (nonatomic, readonly, assign, getter=isHydrated) BOOL hydrated;

+ (id)objectOfDB:(FMDatabase *)aDatabase;

+ (NSArray *)dbVariables;
- (NSMutableDictionary *)dbValues;

- (void)setFromDictionary:(NSDictionary *)dict;
- (void)hydrateFromDictionary:(NSDictionary *)dict;
- (void)autofillFrom:(NSDictionary *)dict overwrite:(BOOL)overwrite;

+ (NSString *)tableName;
+ (NSString *)tableKey;
+ (NSString *)hydrateQuery;

- (BOOL)hydrate;
- (void)didHydrateSuccessfully:(BOOL)success;

- (BOOL)dehydrate:(NSError **)error;
- (void)didDehydrateSuccessfully:(BOOL)success;


@end


#ifndef SQLK_ERR
#define SQLK_ERR(p, s, c)	if (p != NULL && s) {\
		*p = [NSError errorWithDomain:NSCocoaErrorDomain code:(c ? c : 0) userInfo:[NSDictionary dictionaryWithObject:s forKey:NSLocalizedDescriptionKey]];\
	}\
	else {\
		DLog(@"Ignored Error: %@", s);\
}
#endif