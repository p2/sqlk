//
//  SQLKTestObject.h
//  sqlk
//
//  Created by Pascal Pfiffner on 7/14/12.
//
//

#import "SQLiteObject.h"

@interface SQLKTestObject : SQLiteObject

@property (nonatomic, copy) NSString *db_string;
@property (nonatomic, strong) NSNumber *db_number;
@property (nonatomic, copy) NSString *non_db_string;

@end
