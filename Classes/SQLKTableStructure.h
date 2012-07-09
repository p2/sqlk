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
	SQLKStructure *__unsafe_unretained structure;
	
	NSString *name;
	NSArray *columns;
	NSArray *constraints;
	NSString *originalQuery;
}

@property (nonatomic, unsafe_unretained) SQLKStructure *structure;
@property (nonatomic, copy) NSString *name;							///< Table names are assumed to be unique per database/SQLKStructure
@property (nonatomic, copy) NSArray *columns;						///< An array full of SQLiteStructureTableColumn objects
@property (nonatomic, copy) NSArray *constraints;					///< An array full of NSString objects
@property (nonatomic, copy) NSString *originalQuery;

+ (SQLKTableStructure *)tableForStructure:(SQLKStructure *)aStructure;
+ (SQLKTableStructure *)tableFromQuery:(NSString *)aQuery;

- (BOOL)createInDatabase:(FMDatabase *)database error:(NSError **)error;
- (NSString *)creationQuery;

- (SQLKColumnStructure *)columnNamed:(NSString *)columnName;
- (BOOL)hasColumnNamed:(NSString *)columnName;
- (BOOL)hasColumnWithStructure:(SQLKColumnStructure *)columnStructure error:(NSError **)error;

- (BOOL)isEqualToTable:(SQLKTableStructure *)refTable error:(NSError **)error;
- (BOOL)updateTableWith:(SQLKTableStructure *)refTable dropUnusedColumns:(BOOL)dropColumns error:(NSError **)error;

- (BOOL)dropFromDatabase:(FMDatabase *)database error:(NSError **)error;

- (void)log;


@end
