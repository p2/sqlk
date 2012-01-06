//
//  SQLiteStructure.h
//  SQLiteKit
//
//  Created by Pascal Pfiffner on 11.09.10.
//  Copyright 2010 Pascal Pfiffner. All rights reserved.
//	

#import <Foundation/Foundation.h>

@class SQLKTableStructure;
@class FMDatabase;


/**
 *	Instances of this class represent one database. You mostly only interact with this class and only rarely need to use the table and column structure classes
 */
@interface SQLKStructure : NSObject <NSCoding, NSXMLParserDelegate> {
	NSArray *tables;
	NSURL *path;
	
	// XML parsing
	BOOL asyncParsing;
	NSMutableArray *parsingTables;
	SQLKTableStructure *parsingTable;
	NSMutableArray *parsingTableColumns;
	NSMutableArray *parsingTableConstraints;
	NSMutableString *parsingString;
	BOOL duplicateTable;
}

@property (nonatomic, copy) NSArray *tables;							///< An array full of SQLiteStructureTable objects
@property (nonatomic, retain) NSURL *path;								///< The path to an sqlite database represented by the instance

@property (nonatomic, assign) BOOL asyncParsing;						///< Defaults to YES
@property (nonatomic, retain) NSMutableArray *parsingTables;
@property (nonatomic, retain) SQLKTableStructure *parsingTable;
@property (nonatomic, retain) NSMutableArray *parsingTableColumns;
@property (nonatomic, retain) NSMutableArray *parsingTableConstraints;

+ (SQLKStructure *)structure;
+ (SQLKStructure *)structureFromArchive:(NSURL *)archiveUrl;
+ (SQLKStructure *)structureFromDatabase:(NSURL *)dbPath;

- (SQLKTableStructure *)tableWithName:(NSString *)tableName;

- (void)parseStructureFromXML:(NSURL *)xmlUrl error:(NSError **)error;

- (FMDatabase *)createDatabaseAt:(NSURL *)dbPath error:(NSError **)error;
- (FMDatabase *)createMemoryDatabaseWithError:(NSError **)error;
- (BOOL)isEqualToDb:(SQLKStructure *)otherDB error:(NSError **)error;
- (BOOL)updateDatabaseAt:(NSURL *)dbPath allowToDropColumns:(BOOL)dropCol tables:(BOOL)dropTables error:(NSError **)error;

- (BOOL)hasTable:(NSString *)tableName;
- (BOOL)hasTableWithStructure:(SQLKTableStructure *)tableStructure error:(NSError **)error;

- (BOOL)canAccessURL:(NSURL *)dbPath;
- (NSURL *)backupDatabaseAt:(NSURL *)dbPath;
- (void)log;


@end
