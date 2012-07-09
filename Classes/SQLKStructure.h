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
	
	@private
	NSMutableString *parsingString;
	BOOL duplicateTable;
}

@property (nonatomic, readonly, strong) FMDatabase *database;			///< A handle to the sqlite database that the receiver is representing

@property (nonatomic, copy) NSArray *tables;							///< An array full of SQLiteStructureTable objects

@property (nonatomic, strong) NSMutableArray *parsingTables;
@property (nonatomic, strong) SQLKTableStructure *parsingTable;
@property (nonatomic, strong) NSMutableArray *parsingTableColumns;
@property (nonatomic, strong) NSMutableArray *parsingTableConstraints;

+ (SQLKStructure *)structureFromXML:(NSURL *)xmlPath;
+ (SQLKStructure *)structureFromArchive:(NSURL *)archiveUrl;
+ (SQLKStructure *)structureFromDatabase:(NSURL *)dbPath;

- (SQLKTableStructure *)tableWithName:(NSString *)tableName;

- (BOOL)parseStructureFromXML:(NSURL *)xmlUrl error:(NSError **)error;

- (FMDatabase *)createDatabaseAt:(NSURL *)dbPath error:(NSError **)error;
- (FMDatabase *)createMemoryDatabaseWithError:(NSError **)error;
- (BOOL)isEqualTo:(SQLKStructure *)otherDB error:(NSError **)error;
- (BOOL)updateDatabaseAt:(NSURL *)dbPath allowToDropColumns:(BOOL)dropCol tables:(BOOL)dropTables error:(NSError **)error;

- (BOOL)hasTable:(NSString *)tableName;
- (BOOL)hasTableWithStructure:(SQLKTableStructure *)tableStructure error:(NSError **)error;

- (BOOL)canAccessURL:(NSURL *)dbPath;
- (NSURL *)backupDatabaseAt:(NSURL *)dbPath;
- (void)log;


@end
