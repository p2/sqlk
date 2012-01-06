//
//  sqlk.h
//  sqlk
//
//  Created by Pascal Pfiffner on 11/12/11.
//  Copyright (c) 2011 Pascal Pfiffner. All rights reserved.
//

#ifndef SQLK_ERR
#define SQLK_ERR(p, s, c)	if (p != NULL && s) {\
		*p = [NSError errorWithDomain:NSCocoaErrorDomain code:(c ? c : 0) userInfo:[NSDictionary dictionaryWithObject:s forKey:NSLocalizedDescriptionKey]];\
	}\
	else {\
		DLog(@"Ignored Error: %@", s);\
	}
#endif
