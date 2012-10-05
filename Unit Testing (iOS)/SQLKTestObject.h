//
//  SQLKTestObject.h
//  sqlk
//
//  Created by Pascal Pfiffner on 7/14/12.
//  This sourcecode is released under the Apache License, Version 2.0
//  http://www.apache.org/licenses/LICENSE-2.0.html
//

#import "SQLiteObject.h"

@interface SQLKTestObject : SQLiteObject

@property (nonatomic, copy) NSString *db_string;
@property (nonatomic, strong) NSNumber *db_number;
@property (nonatomic, copy) NSString *non_db_string;

@end
