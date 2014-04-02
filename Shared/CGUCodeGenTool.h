//
//  CGUCodeGenTool.h
//  codegenutils
//
//  Created by Jim Puls on 9/6/13.
//  Licensed to Square, Inc. under one or more contributor license agreements.
//  See the LICENSE file distributed with this work for the terms under
//  which Square, Inc. licenses this file to you.

#import <Foundation/Foundation.h>


@interface CGUCodeGenTool : NSObject

+ (int)startWithArgc:(int)argc argv:(const char **)argv;

+ (NSString *)inputFileExtension;

@property (copy) NSURL *inputURL;
@property (copy) NSString *classPrefix;
@property (copy) NSString *searchPath;
@property BOOL targetiOS6;
@property BOOL skipClassDeclaration;
@property BOOL uberMode;

@property (copy) NSString *className;
@property (strong) NSMutableArray *interfaceContents;
/// An array of strings such as "<Foundation/Foundation.h>" which will be imported at the top of the .h file.
@property (strong) NSMutableArray *interfaceImports;
@property (strong) NSMutableArray *implementationContents;

- (void)startWithCompletionHandler:(dispatch_block_t)completionBlock;

- (void)writeOutputFiles;

- (NSString *)methodNameForKey:(NSString *)key;

@end
