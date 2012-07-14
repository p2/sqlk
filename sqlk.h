//
//  sqlk.h
//  sqlk
//
//  Created by Pascal Pfiffner on 11/12/11.
//  Copyright (c) 2011 Pascal Pfiffner. All rights reserved.
//


/// SQLog() calls NSLog with some formatting if DEBUG is defined, it's a noop otherwise
#ifdef DEBUG
#   define SQLog(fmt, ...) NSLog((@"%s (line %d) " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__)
#else
#   define SQLog(...)
#endif

/// SQLK_ERR() puts an error string and code into an error pointer, if it is present, otherwise logs the error if DEBUG is defined
#ifndef SQLK_ERR
#define SQLK_ERR(p, s, c)	if (p != NULL && s) {\
		NSString *str = s ? s : @"Unknown Error";\
		*p = [NSError errorWithDomain:NSCocoaErrorDomain code:(c ? c : 0) userInfo:[NSDictionary dictionaryWithObject:str forKey:NSLocalizedDescriptionKey]];\
	}\
	else {\
		SQLog(@"Ignored Error: %@", s);\
	}
#endif
