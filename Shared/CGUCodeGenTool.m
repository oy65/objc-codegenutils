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
    CGUClassType_Category
    // TODO: add extension in the future?
};

@interface CGUCodeGenTool ()

@property (copy) NSString *toolName;

@end

@interface CGUClass ()

/// The class type is determined by the following:
/// - If there is a categoryName, this is a category.
/// - Otherwise this is a class definition.
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
    NSString *classPrefix = @"";
    BOOL target6 = NO;
    NSMutableArray *inputURLs = [NSMutableArray array];
    NSMutableSet *headerFilesFound = [NSMutableSet set];
    
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
                NSString *searchPath = [[NSString alloc] initWithUTF8String:optarg];
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
            if ([url.pathExtension isEqualToString:@"h"]) {
                NSString *fileName = [url lastPathComponent];
                [headerFilesFound addObject:[fileName substringToIndex:[fileName length] - 2]];
            }
        }
    }
    
    dispatch_group_t group = dispatch_group_create();
    
    for (NSURL *url in inputURLs) {
        dispatch_group_enter(group);
        
        CGUCodeGenTool *target = [self new];
        target.inputURL = url;
        target.headerFilesFound = headerFilesFound;
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
        [interface appendString:[self.interfaceContents componentsJoinedByString:@""]];
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
        [implementation appendString:[self.implementationContents componentsJoinedByString:@""]];
    } else {
        [implementation appendFormat:@"@implementation %@\n\n%@\n@end\n", self.className, [self.implementationContents componentsJoinedByString:@"\n"]];
    }

    if (![implementation isEqualToString:[NSString stringWithContentsOfURL:implementationURL encoding:NSUTF8StringEncoding error:NULL]]) {
        [implementation writeToURL:implementationURL atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    }
    
    NSLog(@"Wrote %@ to %@", self.className, currentDirectory);
}

+ (NSString *)identifierNameForKey:(NSString *)key camelCase:(BOOL)camelCase;
{
    /*
     Standard examples (camelCase):
     My Scene Identifier -> mySceneIdentifier
     my scene identifier -> mySceneIdentifier
     
     Abbreviation examples (camelCase only feature) (i.e. uppercase first word -> lowercase):
     USA -> usa
     usa -> usa
     USA2 -> usa2                       // considered uppercased first word
     USoA -> uSoA
     usa image -> usaImage
     USA image -> usaImage
     image USA -> imageUSA              // abbreviations are only searched for in the first word
     
     Number handling examples (camelCase):
     2url -> _2url                      // identifiers cannot begin with a number
     A2test -> A2test                   // A2 is in uppercase, so it assumes it is a namespace
     2Atest -> _2Atest
     22test -> _22test

     Special character handling (camelCase):
     usa image -> usaImage              // space acts as word separator
     usa-image -> usaImage              // any non alphanumeric character acts as a word separator
     usa_image -> usa_image             // underscores are preserved
     
     More examples (camelCase):
     NSString -> nSString
     NS String -> nsString
     my url -> myUrl
     my uRL -> myURL
     my URL -> myURL
     my u r l -> myURL
     myUrl list -> myUrlList
     myUrl MyUrl -> myUrlMyUrl
     myUrl NSUrl -> myUrlNSUrl
     myURL NSUrl -> myURLNSUrl
     */
    
    NSRegularExpression *wordsRegex = [NSRegularExpression regularExpressionWithPattern:@"\\w+" options:0 error:NULL];
    NSArray *wordMatches = [wordsRegex matchesInString:key options:0 range:NSMakeRange(0, key.length)];
    NSMutableArray *words = [NSMutableArray array];
    for (NSTextCheckingResult *wordMatch in wordMatches) {
        [words addObject:[key substringWithRange:wordMatch.range]];
    }
    NSAssert([words count] > 0, @"Must have at least one character in an identifier.");
    
    // Process the first word.
    if (camelCase) {
        // If the first word is all caps, it's an abbrevation. Lowercase it.
        // Otherwise, camelcase it by lowercasing the first character.
        if ([words[0] isEqualToString:[words[0] uppercaseString]]) {
            words[0] = [words[0] lowercaseString];
        } else {
            words[0] = [words[0] stringByReplacingCharactersInRange:NSMakeRange(0, 1) withString:[[words[0] substringToIndex:1] lowercaseString]];
        }
    } else {
        words[0] = [words[0] stringByReplacingCharactersInRange:NSMakeRange(0, 1) withString:[[words[0] substringToIndex:1] uppercaseString]];
    }
    
    // If the first word starts with a number, prefix with underscore.
    if ([words[0] rangeOfCharacterFromSet:[NSCharacterSet decimalDigitCharacterSet]].location == 0) {
        words[0] = [NSString stringWithFormat:@"_%@", words[0]];
    }
    
    // Process the remaining words (uppercase first letter of each word).
    for (NSInteger i = 1; i < [words count]; i++) {
        words[i] = [words[i] stringByReplacingCharactersInRange:NSMakeRange(0, 1) withString:[[words[i] substringToIndex:1] uppercaseString]];
    }

    return [words componentsJoinedByString:@""];
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
        [result appendFormat:@"@interface %@ : %@\n", self.name, self.superClassName ?: @"NSObject"];
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
    if (self.categoryName.length > 0) {
        return CGUClassType_Category;
    } else {
        return CGUClassType_Definition;
    }
}

@end



@implementation CGUMethod

- (NSString *)name;
{
    if ([self.nameAndArguments rangeOfString:@":"].location == NSNotFound) {
        return self.nameAndArguments;
    } else {
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"\\w+:" options:0 error:NULL];
        NSArray *matches = [regex matchesInString:self.nameAndArguments options:0 range:NSMakeRange(0, [self.nameAndArguments length])];
        NSMutableString *name = [NSMutableString string];
        for (NSTextCheckingResult *match in matches) {
            [name appendString:[self.nameAndArguments substringWithRange:match.range]];
        }
        return name;
    }
}

- (NSString *)interfaceCode;
{
    NSMutableString *interfaceCode = [NSMutableString string];
    if (self.documentation) {
        NSArray *lines = [self.documentation componentsSeparatedByString:@"\n"];
        for (NSString *line in lines) {
            [interfaceCode appendFormat:@"/// %@\n", line];
        }
    }
    [interfaceCode appendFormat:@"%@ (%@)%@;", (self.classMethod ? @"+" : @"-"), self.returnType ?: @"void", self.nameAndArguments];
    return [interfaceCode copy];
}

- (NSString *)implementationCode;
{
    // TODO: indent each line in the body?
    return [NSString stringWithFormat:@"%@ (%@)%@ {\n%@\n}", (self.classMethod ? @"+" : @"-"), self.returnType ?: @"void", self.nameAndArguments, self.body];
}

@end