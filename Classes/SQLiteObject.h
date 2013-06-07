//
//  SQLiteObject.h
//  SQLiteKit
//
//  Created by Pascal Pfiffner on 22.09.09.
//  Copyright 2009 Pascal Pfiffner. All rights reserved.
//  This sourcecode is released under the Apache License, Version 2.0
//  http://www.apache.org/licenses/LICENSE-2.0.html
//

#import <Foundation/Foundation.h>
#import "FMDatabase.h"
#import "FMResultSet.h"


/**
 *	Base object for your objects hydrated from SQLite.
 *	
 *	Basically, one class represents one table, one instance of the class represents one table entry. All instance variables ENDING WITH AN UNDERSCORE will be
 *	fetched from and written to the database!
 *	@attention Note that this class doesn't throw exceptions on "valueForUndefinedKey:" and "setValue:forUndefinedKey:", but it does alert you when the class is
 *	not key-value coding compliant for a given path to give you the opportunity to adjust the class to match the database.
 */
@interface SQLiteObject : NSObject

@property (nonatomic, unsafe_unretained) FMDatabase *db;
@property (nonatomic, copy) id object_id;											///< The object id should either be an NSNumber or NSString (e.g. for UUIDs)
@property (nonatomic, readonly, assign, getter=isHydrated) BOOL hydrated;
@property (nonatomic, readonly, assign, getter=isInDatabase) BOOL inDatabase;		///< Set to YES if one of the "[de]hydrate" methods has been called on the object

+ (id)newWithDatabase:(FMDatabase *)aDatabase;

+ (NSSet *)dbVariables;
- (NSMutableDictionary *)valuesForPropertiesNamed:(NSSet *)propNames;

+ (NSString *)tableName;
+ (NSString *)tableKey;
+ (NSString *)hydrateQuery;

- (BOOL)hydrate;
- (BOOL)setFromDictionary:(NSDictionary *)dict;
- (BOOL)hydrateFromDictionary:(NSDictionary *)dict;
- (void)didHydrateSuccessfully:(BOOL)success;

- (BOOL)dehydrate:(NSError **)error;
- (BOOL)dehydratePropertiesNamed:(NSSet *)propNames error:(NSError **)error;
- (void)didDehydrateSuccessfully:(BOOL)success;

- (BOOL)purge:(NSError **)error;
- (void)didPurgeSuccessfully:(BOOL)success;


@end
