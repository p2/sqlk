//
//  SQLiteStructure.h
//  SQLiteKit
//
//  Created by Pascal Pfiffner on 11.09.10.
//  Copyright 2010 Institute Of Immunology. All rights reserved.
//	
//	Instances of this class represent one database. You mostly only interact with this class
//

#import <Foundation/Foundation.h>
@class SQLKTableStructure;
@class FMDatabase;


@interface SQLKStructure : NSObject <NSCoding, NSXMLParserDelegate> {
	NSArray *tables;							// SQLiteStructureTable objects
	NSURL *path;
	
	// XML parsing
	BOOL asyncParsing;							// Defaults to YES
	NSMutableArray *parsingTables;
	SQLKTableStructure *parsingTable;
	NSMutableArray *parsingTableColumns;
	BOOL duplicateTable;
}

@property (nonatomic, copy) NSArray *tables;
@property (nonatomic, retain) NSURL *path;

@property (nonatomic, assign) BOOL asyncParsing;
@property (nonatomic, retain) NSMutableArray *parsingTables;
@property (nonatomic, retain) SQLKTableStructure *parsingTable;
@property (nonatomic, retain) NSMutableArray *parsingTableColumns;

+ (SQLKStructure *) structure;
+ (SQLKStructure *) structureFromArchive:(NSURL *)archiveUrl;
+ (SQLKStructure *) structureFromDatabase:(NSURL *)dbPath;

- (SQLKTableStructure *) tableWithName:(NSString *)tableName;

- (void) parseStructureFromXML:(NSURL *)xmlUrl error:(NSError **)error;

- (FMDatabase *) createDatabaseAt:(NSURL *)dbPath error:(NSError **)error;
- (FMDatabase *) createMemoryDatabaseWithError:(NSError **)error;
- (BOOL) isEqualToDb:(SQLKStructure *)otherDB error:(NSError **)error;
- (BOOL) updateDatabaseAt:(NSURL *)dbPath allowToDropColumns:(BOOL)dropCol tables:(BOOL)dropTables error:(NSError **)error;

- (BOOL) hasTable:(NSString *)tableName;
- (BOOL) hasTableWithStructure:(SQLKTableStructure *)tableStructure error:(NSError **)error;

- (BOOL) canAccessURL:(NSURL *)dbPath;
- (NSURL *) backupDatabaseAt:(NSURL *)dbPath;
- (void) log;									// recursively logs the structure


@end
