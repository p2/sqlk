//
//  SQLiteStructureTableRow.h
//  SQLiteKit
//
//  Created by Pascal Pfiffner on 11.09.10.
//  This sourcecode is released under the Apache License, Version 2.0
//  http://www.apache.org/licenses/LICENSE-2.0.html
//

#import <Foundation/Foundation.h>

@class SQLKTableStructure;


/**
 *	Instances of this class represent columns belonging to a SQLKTableStructure
 */
@interface SQLKColumnStructure : NSObject

@property (nonatomic, unsafe_unretained) SQLKTableStructure *table;				///< The table to which the reicever belongs
@property (nonatomic, copy) NSString *name;										///< The column name
@property (nonatomic, copy) NSString *type;										///< The column type (e.g. "INTEGER")
@property (nonatomic, assign) BOOL isPrimaryKey;								///< YES if the column is the primary key
@property (nonatomic, assign) BOOL isUnique;									///< YES if the column wants to be unique
@property (nonatomic, copy) NSString *defaultString;							///< String representation of the default value
@property (nonatomic, assign) BOOL defaultNeedsQuotes;							///< If YES, the default value is quoted. Important because: DEFAULT "CURRENT_TIME" might not be what you want.

/// @todo add an array for column constraints

+ (SQLKColumnStructure *)columnForTable:(SQLKTableStructure *)aTable;

- (NSString *)creationQuery;
- (void)setFromAttributeDictionary:(NSDictionary *)dictionary;


@end
