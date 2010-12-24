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
	
	id key;					// the value of this object for "tableKey" in "tableName"
	BOOL hydrated;
}

@property (nonatomic, assign) FMDatabase *db;
@property (nonatomic, retain) id key;
@property (nonatomic, readonly, assign, getter=isHydrated) BOOL hydrated;

+ (id) objectOfDB:(FMDatabase *)aDatabase;

- (BOOL) hydrate;										// calls 'setFromDictionary:' with data fetched from SQLite
- (void) setFromDictionary:(NSDictionary *)dict;		// OVERRIDE to suit your needs
- (void) autoFillFromDictionary:(NSDictionary *)dict;	// tries to assign instance variables from dictionary

+ (NSString *) tableName;								// the SQLite table being represented by these objects
+ (NSString *) tableKey;								// the column name of the primary id column, holding the unique row identifier
+ (NSString *) hydrateQuery;							// By default: SELECT * FROM `<tableName>` WHERE `<tableKey>` = object.key

- (BOOL) dehydrate:(NSError **)error;
- (NSDictionary *) dehydrateDictionary;


@end
