#import "CDCoreDataDumper.h"

@interface CDCoreDataDumper ()

@property (strong) NSArray *modelContentURLs;

@end

@implementation CDCoreDataDumper

+ (NSString *)inputFileExtension;
{
    return @"xcdatamodel";
}

- (void)findModelContentURLs;
{
    // TODO: only take the latest version
    NSMutableArray *modelContentsURLs = [NSMutableArray array];
    NSDirectoryEnumerator *enumerator = [[NSFileManager new] enumeratorAtURL:self.inputURL includingPropertiesForKeys:@[NSURLNameKey] options:0 errorHandler:NULL];
    for (NSURL *url in enumerator) {
        if ([url.lastPathComponent isEqualToString:@"contents"]) {
            [modelContentsURLs addObject:url];
        }
    }
    self.modelContentURLs = [modelContentsURLs copy];
}

- (void)startWithCompletionHandler:(dispatch_block_t)completionBlock;
{
    dispatch_group_t dispatchGroup = dispatch_group_create();
    dispatch_queue_t dispatchQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_async(dispatchQueue, ^{
        [self findModelContentURLs];
        
        self.interfaceImports = [NSMutableSet set];
        self.classes = [NSMutableDictionary dictionary];
        self.skipClassDeclaration = YES;
        
        self.className = [[NSString stringWithFormat:@"%@%@Model", self.classPrefix, [[self.inputURL lastPathComponent] stringByDeletingPathExtension]] stringByReplacingOccurrencesOfString:@" " withString:@""];
        
        for (NSURL *modelContentURL in self.modelContentURLs) {
            dispatch_group_async(dispatchGroup, dispatchQueue, ^{
                [self parseModelAtURL:modelContentURL];
            });
        }
        
        dispatch_group_wait(dispatchGroup, DISPATCH_TIME_FOREVER);
        
        [self writeOutputFiles];
        
        completionBlock();
    });
}

- (void)parseModelAtURL:(NSURL *)url;
{
    NSXMLDocument *document = [[NSXMLDocument alloc] initWithContentsOfURL:url options:0 error:NULL];
    NSString *modelFilename = [url.pathComponents[url.pathComponents.count-2] stringByDeletingPathExtension];
    NSString *modelName = [modelFilename stringByReplacingOccurrencesOfString:@" " withString:@""];
    
    NSArray *modelEntities = [document nodesForXPath:@"//entity" error:NULL];
    for (NSXMLElement *entityElement in modelEntities) {
        NSString *entityName = [[entityElement attributeForName:@"name"] stringValue];
        NSString *customClass = [[entityElement attributeForName:@"representedClassName"] stringValue];
        
        if (customClass) {
            @synchronized(self.interfaceImports) {
                [self.interfaceImports addObject:[NSString stringWithFormat:@"\"%@.h\"", customClass]];
            }
            
            CGUClass *entityClassCategory = [CGUClass new];
            entityClassCategory.name = customClass;
            entityClassCategory.categoryName = [NSString stringWithFormat:@"ObjcCodeGenUtils_%@", modelName];
            
            CGUMethod *entityNameMethod = [CGUMethod new];
            entityNameMethod.classMethod = YES;
            entityNameMethod.returnType = @"NSString *";
            entityNameMethod.nameAndArguments = @"entityName";
            entityNameMethod.body = [NSString stringWithFormat:@"return @\"%@\";", entityName];
            [entityClassCategory.methods addObject:entityNameMethod];
            
            NSArray *attributeNames = [[entityElement nodesForXPath:@"./attribute/@name" error:NULL] valueForKey:NSStringFromSelector(@selector(stringValue))];
            for (NSString *attributeName in attributeNames) {
                CGUMethod *propertyMethod = [CGUMethod new];
                propertyMethod.classMethod = YES;
                propertyMethod.returnType = @"NSString *";
                propertyMethod.nameAndArguments = attributeName;
                propertyMethod.body = [NSString stringWithFormat:@"return @\"%@\";", attributeName];
                [entityClassCategory.methods addObject:propertyMethod];
            }
            
            @synchronized(self.classes) {
                self.classes[customClass] = entityClassCategory;
            }
        } else {
            
        }
    }
}

@end
