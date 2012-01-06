//
//  SQLiteStructureTable.h
//  SQLiteKit
//
//  Created by Pascal Pfiffner on 11.09.10.
//	

#import <Foundation/Foundation.h>

@class SQLKStructure;
@class SQLKColumnStructure;
@class FMDatabase;


/**
 *	Instances of this class represent tables belonging to a SQLKStructure
 */
@interface SQLKTableStructure : NSObject {
	SQLKStructure *structure;
	
	NSString *name;
	NSArray *columns;
	NSArray *constraints;
	NSString *originalQuery;
}

@property (nonatomic, assign) SQLKStructure *structure;
@property (nonatomic, copy) NSString *name;							///< Table names are assumed to be unique per database/SQLKStructure
@property (nonatomic, copy) NSArray *columns;						///< An array full of SQLiteStructureTableColumn objects
@property (nonatomic, copy) NSArray *constraints;					///< An array full of NSString objects
@property (nonatomic, copy) NSString *originalQuery;

+ (SQLKTableStructure *)tableForStructure:(SQLKStructure *)aStructure;
+ (SQLKTableStructure *)tableFromQuery:(NSString *)aQuery;

- (BOOL)createInDatabase:(FMDatabase *)database error:(NSError **)error;
- (NSString *)creationQuery;

- (BOOL)hasColumnNamed:(NSString *)columnName;
- (BOOL)hasColumnWithStructure:(SQLKColumnStructure *)columnStructure error:(NSError **)error;

- (BOOL)isEqualToTable:(SQLKTableStructure *)otherTable error:(NSError **)error;
- (BOOL)updateTableAccordingTo:(NSString *)tableDesc dropUnused:(BOOL)drop error:(NSError **)error;	// returns YES on success

- (void)log;


@end
