//
//  SQLiteStructureTable.h
//  SQLiteKit
//
//  Created by Pascal Pfiffner on 11.09.10.
//	
//	Instances of this class represent tables belonging to a SQLKStructure
//

#import <Foundation/Foundation.h>
@class SQLKStructure;
@class SQLKColumnStructure;
@class FMDatabase;


@interface SQLKTableStructure : NSObject {
	SQLKStructure *structure;
	
	NSString *name;								// table names are assumed to be unique per database/SQLKStructure
	NSArray *columns;							// SQLiteStructureTableColumn objects
	NSString *originalQuery;
}

@property (nonatomic, assign) SQLKStructure *structure;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSArray *columns;
@property (nonatomic, copy) NSString *originalQuery;

+ (SQLKTableStructure *) tableForStructure:(SQLKStructure *)aStructure;
+ (SQLKTableStructure *) tableFromQuery:(NSString *)aQuery;

- (BOOL) createInDatabase:(FMDatabase *)database error:(NSError **)error;
- (NSString *) creationQuery;

- (BOOL) hasColumnNamed:(NSString *)columnName;
- (BOOL) hasColumnWithStructure:(SQLKColumnStructure *)columnStructure error:(NSError **)error;

// The following is especially used by SQLKStructure to compare an instance created from XML to an instance created from the actual database
// return YES if this instance matches the other instance. isEqual: would also return YES, then
- (BOOL) isEqualToTable:(SQLKTableStructure *)otherTable error:(NSError **)error;
- (BOOL) updateTableAccordingTo:(NSString *)tableDesc dropUnused:(BOOL)drop error:(NSError **)error;	// returns YES on success


@end
