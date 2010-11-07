//
//  SQLiteStructureTableRow.h
//  EviApp
//
//  Created by Pascal Pfiffner on 11.09.10.
//  Copyright 2010 Institute Of Immunology. All rights reserved.
//

#import <Foundation/Foundation.h>
@class SQLKTableStructure;


@interface SQLKColumnStructure : NSObject {
	SQLKTableStructure *table;
	
	NSString *name;						// column name: "column_name"
	NSString *type;						// column type: "int(6)"
	
	BOOL isPrimaryKey;
	BOOL isUnique;
	NSString *defaultString;
	BOOL defaultNeedsQuotes;
	// add an array for column constraints
	// add an array for table constraints
}

@property (nonatomic, assign) SQLKTableStructure *table;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *type;
@property (nonatomic, assign) BOOL isPrimaryKey;
@property (nonatomic, assign) BOOL isUnique;
@property (nonatomic, copy) NSString *defaultString;
@property (nonatomic, assign) BOOL defaultNeedsQuotes;

+ (SQLKColumnStructure *) columnForTable:(SQLKTableStructure *)aTable;

- (NSString *) creationQuery;													// a query string representing this column, created from its properties
- (BOOL) isEqualToColumn:(SQLKColumnStructure *)oc error:(NSError **)error;		// returns YES if creationQuery of both columns are the same


@end
