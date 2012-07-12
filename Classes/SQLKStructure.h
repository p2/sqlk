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
	BOOL duplicateTable;
	BOOL didParseSchema;
}

@property (nonatomic, readonly, strong) FMDatabase *database;			///< A handle to the sqlite database that the receiver is representing
@property (nonatomic, copy) NSArray *tables;							///< An array full of SQLiteStructureTable objects
@property (nonatomic, readonly, copy) NSString *schemaPath;				///< The path to the XML schema

+ (SQLKStructure *)structureFromXML:(NSString *)xmlPath;
+ (SQLKStructure *)structureFromArchive:(NSString *)archiveUrl;
+ (SQLKStructure *)structureFromDatabase:(NSString *)dbPath;

- (SQLKTableStructure *)tableWithName:(NSString *)tableName;

- (FMDatabase *)createDatabaseAt:(NSString *)dbPath useBundleDbIfMissing:(NSString *)bundleFilename wasMissing:(BOOL *)wasMissing updateStructure:(BOOL)update error:(NSError * __autoreleasing *)error;
- (FMDatabase *)createDatabaseAt:(NSString *)dbPath useBundleDbIfMissing:(NSString *)bundleFilename updateStructure:(BOOL)update error:(NSError * __autoreleasing *)error;
- (FMDatabase *)createDatabaseAt:(NSString *)dbPath useBundleDbIfMissing:(NSString *)bundleFilename error:(NSError * __autoreleasing *)error;
- (FMDatabase *)createDatabaseAt:(NSString *)dbPath error:(NSError * __autoreleasing *)error;
- (FMDatabase *)createMemoryDatabaseWithError:(NSError **)error;

- (BOOL)isEqualTo:(SQLKStructure *)otherDB error:(NSError **)error;
- (BOOL)updateDatabaseAt:(NSString *)dbPath dropTables:(BOOL)dropTables error:(NSError **)error;

- (BOOL)hasTable:(NSString *)tableName;
- (BOOL)hasTableWithStructure:(SQLKTableStructure *)tableStructure error:(NSError **)error;

- (void)log;


@end
