//
//  CGUCodeGenTool.m
//  codegenutils
//
//  Created by Jim Puls on 9/6/13.
//  Licensed to Square, Inc. under one or more contributor license agreements.
//  See the LICENSE file distributed with this work for the terms under
//  which Square, Inc. licenses this file to you.

#import "CGUCodeGenTool.h"

#import <libgen.h>

typedef NS_ENUM(NSInteger, CGUClassType) {
    CGUClassType_Definition,
    CGUClassType_Extension,
    CGUClassType_Category
};

@interface CGUCodeGenTool ()

@property (copy) NSString *toolName;
@property (strong) NSMutableDictionary *classesImported;

@end

@interface CGUClass ()

/// The class type is determined by the following:
/// - If there is a superClassName, this is a class definition
/// - If there is a clategoryName, this is a category
/// - Otherwise, this is a class extension
@property (readonly) CGUClassType classType;

@end


@implementation CGUCodeGenTool

+ (NSString *)inputFileExtension;
{
    NSAssert(NO, @"Unimplemented abstract method: %@", NSStringFromSelector(_cmd));
    return nil;
}

+ (int)startWithArgc:(int)argc argv:(const char **)argv;
{
    char opt = -1;
    NSURL *searchURL = nil;
    NSString *searchPath = nil;
    NSString *classPrefix = @"";
    BOOL target6 = NO;
    NSMutableArray *inputURLs = [NSMutableArray array];
    
    while ((opt = getopt(argc, (char *const*)argv, "o:f:p:h6")) != -1) {
        switch (opt) {
            case 'h': {
                printf("Usage: %s [-6] [-o <path>] [-f <path>] [-p <prefix>] [<paths>]\n", basename((char *)argv[0]));
                printf("       %s -h\n\n", basename((char *)argv[0]));
                printf("Options:\n");
                printf("    -6          Target iOS 6 in addition to iOS 7\n");
                printf("    -o <path>   Output files at <path>\n");
                printf("    -f <path>   Search for *.%s folders starting from <path>\n", [[self inputFileExtension] UTF8String]);
                printf("    -p <prefix> Use <prefix> as the class prefix in the generated code\n");
                printf("    -h          Print this help and exit\n");
                printf("    <paths>     Input files; this and/or -f are required.\n");
                return 0;
            }
                
            case 'o': {
                NSString *outputPath = [[NSString alloc] initWithUTF8String:optarg];
                outputPath = [outputPath stringByExpandingTildeInPath];
                [[NSFileManager defaultManager] changeCurrentDirectoryPath:outputPath];
                break;
            }
                
            case 'f': {
                searchPath = [[NSString alloc] initWithUTF8String:optarg];
                searchPath = [searchPath stringByExpandingTildeInPath];
                searchURL = [NSURL fileURLWithPath:searchPath];
                break;
            }
                
            case 'p': {
                classPrefix = [[NSString alloc] initWithUTF8String:optarg];
                break;
            }
                
            case '6': {
                target6 = YES;
                break;
            }
                
            default:
                break;
        }
    }
    
    for (int index = optind; index < argc; index++) {
        NSString *inputPath = [[NSString alloc] initWithUTF8String:argv[index]];
        inputPath = [inputPath stringByExpandingTildeInPath];
        [inputURLs addObject:[NSURL fileURLWithPath:inputPath]];
    }
    
    if (searchURL) {
        NSDirectoryEnumerator *enumerator = [[NSFileManager defaultManager] enumeratorAtURL:searchURL includingPropertiesForKeys:@[NSURLNameKey] options:0 errorHandler:NULL];
        for (NSURL *url in enumerator) {
            if ([url.pathExtension isEqualToString:[self inputFileExtension]]) {
                [inputURLs addObject:url];
            }
        }
    }
    
    dispatch_group_t group = dispatch_group_create();
    
    for (NSURL *url in inputURLs) {
        dispatch_group_enter(group);
        
        CGUCodeGenTool *target = [self new];
        target.inputURL = url;
        target.searchPath = searchPath;
        target.targetiOS6 = target6;
        target.classPrefix = classPrefix;
        target.toolName = [[NSString stringWithUTF8String:argv[0]] lastPathComponent];
        [target startWithCompletionHandler:^{
            dispatch_group_leave(group);
        }];
    }
    
    dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
    return 0;
}

- (void)startWithCompletionHandler:(dispatch_block_t)completionBlock;
{
    NSAssert(NO, @"Unimplemented abstract method: %@", NSStringFromSelector(_cmd));
}

- (void)writeOutputFiles;
{
    NSAssert(self.className, @"Class name isn't set");

    NSString *classNameH = [self.className stringByAppendingPathExtension:@"h"];
    NSString *classNameM = [self.className stringByAppendingPathExtension:@"m"];

    NSURL *currentDirectory = [NSURL fileURLWithPath:[[NSFileManager new] currentDirectoryPath]];
    NSURL *interfaceURL = [currentDirectory URLByAppendingPathComponent:classNameH];
    NSURL *implementationURL = [currentDirectory URLByAppendingPathComponent:classNameM];
    
    [self.interfaceContents sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        return [obj1 compare:obj2];
    }];
    [self.implementationContents sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        return [obj1 compare:obj2];
    }];
    
    NSMutableString *interface = [NSMutableString stringWithFormat:@"//\n// This file is generated from %@ by %@.\n// Please do not edit.\n//\n\n#import <UIKit/UIKit.h>\n\n\n", self.inputURL.lastPathComponent, self.toolName];
    
    for (NSString *import in self.interfaceImports) {
        [interface appendFormat:@"#import %@\n", import];
    }
    [interface appendString:@"\n"];
    
    for (NSString *className in self.classes) {
        CGUClass *class = self.classes[className];
        [interface appendFormat:@"%@\n", [class interfaceCode]];
    }

    if (self.skipClassDeclaration) {
        if (self.interfaceContents) {
            [interface appendString:[self.interfaceContents componentsJoinedByString:@""]];
        }
    } else {
        [interface appendFormat:@"@interface %@ : NSObject\n\n%@\n@end\n", self.className, [self.interfaceContents componentsJoinedByString:@""]];
    }
    
    if (![interface isEqualToString:[NSString stringWithContentsOfURL:interfaceURL encoding:NSUTF8StringEncoding error:NULL]]) {
        [interface writeToURL:interfaceURL atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    }
    
    NSMutableString *implementation = [NSMutableString stringWithFormat:@"//\n// This file is generated from %@ by %@.\n// Please do not edit.\n//\n\n#import \"%@\"\n\n\n", self.inputURL.lastPathComponent, self.toolName, classNameH];
    
    for (NSString *className in self.classes) {
        CGUClass *class = self.classes[className];
        [implementation appendFormat:@"%@\n", [class implementationCode]];
    }

    if (self.skipClassDeclaration) {
        if (self.implementationContents) {
            [implementation appendString:[self.implementationContents componentsJoinedByString:@""]];
        }
    } else {
        [implementation appendFormat:@"@implementation %@\n\n%@\n@end\n", self.className, [self.implementationContents componentsJoinedByString:@"\n"]];
    }

    if (![implementation isEqualToString:[NSString stringWithContentsOfURL:implementationURL encoding:NSUTF8StringEncoding error:NULL]]) {
        [implementation writeToURL:implementationURL atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    }
    
    NSLog(@"Wrote %@ to %@", self.className, currentDirectory);
}

- (NSString *)methodNameForKey:(NSString *)key;
{
    NSMutableString *mutableKey = [key mutableCopy];
    // If the string is already all caps, it's an abbrevation. Lowercase the whole thing.
    // Otherwise, camelcase it by lowercasing the first character.
    if ([mutableKey isEqualToString:[mutableKey uppercaseString]]) {
        mutableKey = [[mutableKey lowercaseString] mutableCopy];
    } else {
        [mutableKey replaceCharactersInRange:NSMakeRange(0, 1) withString:[[key substringToIndex:1] lowercaseString]];
    }
    [mutableKey replaceOccurrencesOfString:@" " withString:@"" options:0 range:NSMakeRange(0, mutableKey.length)];
    [mutableKey replaceOccurrencesOfString:@"~" withString:@"" options:0 range:NSMakeRange(0, mutableKey.length)];
    return [mutableKey copy];
}

/// This method may be called multiple times with the same className without inquiring a search penalty each time.
- (BOOL)importClass:(NSString *)className;
{
    /// Keys: NSString of class name; Values: @(BOOL) stating if it was successfully imported or not
    if (!self.classesImported) {
        self.classesImported = [NSMutableDictionary dictionary];
    }
    
    if (self.classesImported[className]) {
        // if we have arleady tried searching for this class, there is no need to search for it again
        return [self.classesImported[className] boolValue];
    }
    
    NSTask *findFiles = [NSTask new];
    [findFiles setLaunchPath:@"/usr/bin/grep"];
    [findFiles setCurrentDirectoryPath:self.searchPath];
    [findFiles setArguments:[[NSString stringWithFormat:@"-r -l -e @interface[[:space:]]\\{1,\\}%@[[:space:]]*:[[:space:]]*[[:alpha:]]\\{1,\\} .", className] componentsSeparatedByString:@" "]];
    
    NSPipe *pipe = [NSPipe pipe];
    [findFiles setStandardOutput:pipe];
    NSFileHandle *file = [pipe fileHandleForReading];
    
    [findFiles launch];
    [findFiles waitUntilExit];
    
    NSData *data = [file readDataToEndOfFile];
    
    NSString *string = [[NSString alloc] initWithData: data encoding:NSUTF8StringEncoding];
    NSArray *lines = [string componentsSeparatedByString:@"\n"];
    BOOL successfullyImported = NO;
    for (NSString *line in lines) {
        NSURL *path = [NSURL URLWithString:line];
        NSString *importFile = [path lastPathComponent];
        if ([importFile hasSuffix:@".h"]) {
            @synchronized(self.interfaceImports) {
                [self.interfaceImports addObject:[NSString stringWithFormat:@"\"%@\"", importFile]];
            }
            successfullyImported = YES;
            break;
        }
    }
    
    if (!successfullyImported) {
        NSLog(@"Unable to find class interface for '%@'. Reverting to global string constant behavior.", className);
    }
    self.classesImported[className] = @(successfullyImported);
    return successfullyImported;
}

@end



@implementation CGUClass

- (instancetype)init;
{
    self = [super init];
    if (self) {
        self.methods = [NSMutableArray array];
    }
    return self;
}

- (void)sortMethods;
{
    [self.methods sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        CGUMethod *method1 = obj1;
        CGUMethod *method2 = obj2;
        
        // 1. sort class methods first, then instance methods
        if (method1.classMethod && !method2.classMethod) {
            return NSOrderedAscending;
        } else if (!method1.classMethod && method2.classMethod) {
            return NSOrderedDescending;
        }
        
        // 2. sort by the method name
        return [method1.nameAndArguments caseInsensitiveCompare:method2.nameAndArguments];
    }];
}

- (NSString *)interfaceCode;
{
    if (self.methods.count == 0 && self.classType != CGUClassType_Definition) {
        // no need to print a category/extension if it has no methods
        return @"";
    }
    
    [self sortMethods];
    
    NSMutableString *result = [NSMutableString string];
    if (self.classType == CGUClassType_Definition) {
        [result appendFormat:@"@interface %@ : %@\n", self.name, self.superClassName];
    } else {
        [result appendFormat:@"@interface %@ (%@)\n", self.name, self.categoryName];
    }
    for (CGUMethod *method in self.methods) {
        [result appendString:[method interfaceCode]];
        [result appendString:@"\n"];
    }
    [result appendFormat:@"@end\n"];
    return result;
}

- (NSString *)implementationCode;
{
    if (self.methods.count == 0 && self.classType != CGUClassType_Definition) {
        // no need to print a category/extension if it has no methods
        return @"";
    }

    [self sortMethods];
    
    NSMutableString *result = [NSMutableString string];
    if (self.classType == CGUClassType_Definition) {
        [result appendFormat:@"@implementation %@\n", self.name];
    } else {
        [result appendFormat:@"@implementation %@ (%@)\n", self.name, self.categoryName];
    }
    for (CGUMethod *method in self.methods) {
        [result appendString:[method implementationCode]];
        [result appendString:@"\n"];
    }
    [result appendFormat:@"@end\n"];
    return result;
}

- (CGUClassType)classType;
{
    if (self.superClassName) {
        return CGUClassType_Definition;
    } else {
        return self.categoryName.length == 0 ? CGUClassType_Extension : CGUClassType_Category;
    }
}

@end



@implementation CGUMethod

- (NSString *)interfaceCode;
{
    return [NSString stringWithFormat:@"%@ (%@)%@;", (self.classMethod ? @"+" : @"-"), self.returnType ?: @"void", self.nameAndArguments];
}

- (NSString *)implementationCode;
{
    // TODO: indent each line in the body?
    return [NSString stringWithFormat:@"%@ (%@)%@ {\n%@\n}", (self.classMethod ? @"+" : @"-"), self.returnType ?: @"void", self.nameAndArguments, self.body];
}

@end