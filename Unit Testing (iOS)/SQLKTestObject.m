//
//  SQLKTestObject.m
//  sqlk
//
//  Created by Pascal Pfiffner on 7/14/12.
//
//

#import "SQLKTestObject.h"

@implementation SQLKTestObject

@synthesize db_string = db_string_;
@synthesize db_number = db_number_;
@synthesize non_db_string = _non_db_string;

+ (NSString *)tableName
{
	return @"test_table";
}

+ (NSString *)tableKey
{
	return @"row_id";
}


@end
