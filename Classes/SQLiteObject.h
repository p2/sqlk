//
//  SQLiteObject.h
//  SQLiteKit
//
//  Created by Pascal Pfiffner on 22.09.09.
//  Copyright 2009 Pascal Pfiffner. All rights reserved.
//	
//	Base object for your objects hydrated from SQLite
//	Basically, one class represents from one table, one instance of the class representing one data row
//

#import <Foundation/Foundation.h>
#import "FMDatabase.h"
#import "FMResultSet.h"


@interface SQLiteObject : NSObject {
	FMDatabase *db;
	
	id key;					// the value of this object's value for "tableKey" in "tableName"
	BOOL hydrated;
}

@property (nonatomic, assign) FMDatabase *db;
@property (nonatomic, retain) id key;
@property (nonatomic, readonly, assign, getter=isHydrated) BOOL hydrated;

+ (id) objectOfDB:(FMDatabase *)aDatabase;

- (BOOL) hydrate;
- (void) setFromDictionary:(NSDictionary *)dict;
+ (NSString *) tableName;							// the SQLite table being represented by these objects
+ (NSString *) tableKey;							// the column name of the primary id column, holding the unique row identifier
+ (NSString *) hydrateQuery;						// By default: SELECT * FROM `<tableName>` WHERE `<tableKey>` = object.key
+ (NSDictionary *) sqlPropertyLinker;				// if a property has a different column name in the table, put it in here. The dictionary key must be the name of the table column

- (BOOL) dehydrate:(NSError **)error;
- (NSDictionary *) dehydrateDictionary;


@end
