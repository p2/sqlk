//
//  SQLiteObject.h
//  SQLiteKit
//
//  Created by Pascal Pfiffner on 22.09.09.
//  Copyright 2009 Pascal Pfiffner. All rights reserved.
//	
//	Base object for your objects hydrated from SQLite
//	Basically, one class represents one table, one instance of the class represents one table entry
//	Note that this class doesn't throw exceptions on valueForUndefinedKey: and setValue:forUndefinedKey:
//

#import <Foundation/Foundation.h>
#import "FMDatabase.h"
#import "FMResultSet.h"


@interface SQLiteObject : NSObject {
	FMDatabase *db;
	
	id<NSObject, NSCopying> object_id;					// the value of this object for "tableKey" in "tableName" (the primary key)
	BOOL hydrated;
}

@property (nonatomic, assign) FMDatabase *db;
@property (nonatomic, retain) id object_id;
@property (nonatomic, readonly, assign, getter=isHydrated) BOOL hydrated;

+ (id) object;
+ (id) objectOfDB:(FMDatabase *)aDatabase;

- (BOOL) hydrate;										// calls 'hydrateFromDictionary:' with data fetched from SQLite
- (void) hydrateFromDictionary:(NSDictionary *)dict;	// by default calls 'autofillFromDictionary:overwrite:' with YES for overwrite
- (void) setFromDictionary:(NSDictionary *)dict;		// by default calls 'autofillFromDictionary:overwrite:' with NO for overwrite
- (void) autofillFrom:(NSDictionary *)dict overwrite:(BOOL)overwrite;	// tries to assign instance variables from dictionary. No need to override.
- (void) didHydrateSuccessfully:(BOOL)success;			// by default does nothing. Override to hydrate relationships and perform other tasks

+ (NSString *) tableName;								// the SQLite table being represented by these objects
+ (NSString *) tableKey;								// the column name of the primary id column, holding the unique row identifier
+ (NSString *) hydrateQuery;							// by default: SELECT * FROM `<tableName>` WHERE `<tableKey>` = object.key

- (BOOL) dehydrate:(NSError **)error;					// by default generates an UPDATE query from 'ivarDictionary' and does an INSERT if the update query didn't match any entry
- (NSMutableDictionary *) ivarDictionary;				// dictionary containing all instance variables. Override to customize.
- (void) didDehydrateSuccessfully:(BOOL)success;		// by default does nothing. Override to dehydrate relationships and perform other tasks


@end
