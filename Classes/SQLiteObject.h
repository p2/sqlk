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
 *	Base object for your objects hydrated from SQLite.
 *	
 *	Basically, one class represents one table, one instance of the class represents one table entry. All instance variables ENDING WITH AN UNDERSCORE will be
 *	fetched from and written to the database!
 *	@attention Note that this class doesn't throw exceptions on "valueForUndefinedKey:" and "setValue:forUndefinedKey:", but it does alert you when the class is
 *	not key-value coding compliant for a given path to give you the opportunity to adjust the class to match the database.
 */
@interface SQLiteObject : NSObject

@property (nonatomic, unsafe_unretained) FMDatabase *db;
@property (nonatomic, strong) id object_id;											///< The object id can either be an NSNumber or NSString (e.g. for UUIDs)
@property (nonatomic, readonly, assign, getter=isHydrated) BOOL hydrated;
@property (nonatomic, readonly, assign, getter=isInDatabase) BOOL inDatabase;		///< Set to YES if one of the "[de]hydrate" methods has been called on the object

+ (id)newWithDatabase:(FMDatabase *)aDatabase;

+ (NSArray *)dbVariables;
- (NSMutableDictionary *)dbValuesForPropertyNames:(NSArray *)propNames;

- (void)setFromDictionary:(NSDictionary *)dict;
- (void)hydrateFromDictionary:(NSDictionary *)dict;
- (void)autofillFrom:(NSDictionary *)dict overwrite:(BOOL)overwrite;

+ (NSString *)tableName;
+ (NSString *)tableKey;
+ (NSString *)hydrateQuery;

- (BOOL)hydrate;
- (void)didHydrateSuccessfully:(BOOL)success;

- (BOOL)dehydrate:(NSError **)error;
- (BOOL)dehydratePropertiesNamed:(NSArray *)propNames error:(NSError **)error;
- (void)didDehydrateSuccessfully:(BOOL)success;

- (BOOL)purge:(NSError **)error;
- (void)didPurgeSuccessfully:(BOOL)success;


@end
