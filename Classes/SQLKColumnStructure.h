//
//  SQLiteStructureTableRow.h
//  SQLiteKit
//
//  Created by Pascal Pfiffner on 11.09.10.
//	

#import <Foundation/Foundation.h>

@class SQLKTableStructure;


/**
 *	Instances of this class represent columns belonging to a SQLKTableStructure
 */
@interface SQLKColumnStructure : NSObject {
	SQLKTableStructure *__unsafe_unretained table;
	
	NSString *name;
	NSString *type;
	
	BOOL isPrimaryKey;
	BOOL isUnique;
	NSString *defaultString;
	BOOL defaultNeedsQuotes;
	/// @todo add an array for column constraints
}

@property (nonatomic, unsafe_unretained) SQLKTableStructure *table;						///< The table to which the reicever belongs
@property (nonatomic, copy) NSString *name;										///< The column name
@property (nonatomic, copy) NSString *type;										///< The column type (e.g. "int(6)")
@property (nonatomic, assign) BOOL isPrimaryKey;
@property (nonatomic, assign) BOOL isUnique;
@property (nonatomic, copy) NSString *defaultString;
@property (nonatomic, assign) BOOL defaultNeedsQuotes;

+ (SQLKColumnStructure *)columnForTable:(SQLKTableStructure *)aTable;

- (NSString *)creationQuery;
- (BOOL)isEqualToColumn:(SQLKColumnStructure *)oc error:(NSError **)error;

- (NSString *)fullType;


@end
