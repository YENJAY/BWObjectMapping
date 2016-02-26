//
// Created by Bruno Wernimont on 2012
// Copyright 2012 BWObjectMapping
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

#import "BWObjectMapping.h"

#import "BWObjectAttributeMapping.h"
#import "BWObjectMapper.h"
#import "BWOjectRelationAttributeMapping.h"
#import "NSString+BWObjectMapping.h"
#import <objc/runtime.h>
#import "BWObjectValueMapper.h"

////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////
@interface BWObjectMapping ()

@end


////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////
@implementation BWObjectMapping


////////////////////////////////////////////////////////////////////////////////////////////////////
- (id)initWithObjectClass:(Class)objectClass {
    self = [self init];
    if (self) {
        self.objectClass = objectClass;
        _attributeMappings = [NSMutableDictionary dictionary];
        _hasOneMappings = [NSMutableDictionary dictionary];
        _hasManyMappings = [NSMutableDictionary dictionary];
        
        [self generateAutoMapping];
    }
    return self;
}


////////////////////////////////////////////////////////////////////////////////////////////////////
+ (id)mappingForObject:(Class)objectClass block:(void(^)(BWObjectMapping *mapping))block {
    BWObjectMapping *mapping = [[self alloc] initWithObjectClass:objectClass];
    if (block) {
        block(mapping);
    }
    return mapping;
}


////////////////////////////////////////////////////////////////////////////////////////////////////
+ (id)mappingForObject:(Class)objectClass {
    return [self mappingForObject:objectClass block:nil];
}


////////////////////////////////////////////////////////////////////////////////////////////////////
- (void)mapPrimaryKeyAttribute:(NSString *)primaryKey toAttribute:(NSString *)attribute {
    BWObjectAttributeMapping *attributeMapping = [BWObjectAttributeMapping attributeMapping];
    attributeMapping.keyPath = primaryKey;
    attributeMapping.attribute = attribute;
    
    self.primaryKeyAttribute = attributeMapping;
    [self addAttributeMappingToObjectMapping:attributeMapping];
}


////////////////////////////////////////////////////////////////////////////////////////////////////
- (void)mapKeyPath:(NSString *)keyPath toAttribute:(NSString *)attribute {
    BWObjectAttributeMapping *attributeMapping = [BWObjectAttributeMapping attributeMapping];
    attributeMapping.keyPath = keyPath;
    attributeMapping.attribute = attribute;
    
    [self addAttributeMappingToObjectMapping:attributeMapping];
}


////////////////////////////////////////////////////////////////////////////////////////////////////
- (void)mapKeyPath:(NSString *)keyPath toAttribute:(NSString *)attribute dateFormat:(NSString *)dateFormat {
    BWObjectAttributeMapping *attributeMapping = [BWObjectAttributeMapping attributeMapping];
    attributeMapping.keyPath = keyPath;
    attributeMapping.attribute = attribute;
    attributeMapping.dateFormat = dateFormat;
    
    [self addAttributeMappingToObjectMapping:attributeMapping];
}


////////////////////////////////////////////////////////////////////////////////////////////////////
- (void)mapKeyPath:(NSString *)keyPath
       toAttribute:(NSString *)attribute
        valueBlock:(BWObjectMappingValueBlock)valueBlock {
    
    BWObjectAttributeMapping *attributeMapping = [BWObjectAttributeMapping attributeMapping];
    attributeMapping.keyPath = keyPath;
    attributeMapping.attribute = attribute;
    attributeMapping.valueBlock = valueBlock;
    
    [self addAttributeMappingToObjectMapping:attributeMapping];
}


////////////////////////////////////////////////////////////////////////////////////////////////////
- (void)mapAttributeFromArray:(NSArray *)attributes {
    [attributes enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        [self mapKeyPath:obj toAttribute:obj];
    }];
}


////////////////////////////////////////////////////////////////////////////////////////////////////
- (void)mapRailsAttributeFormatFromCoreDataFormatWithArray:(NSArray *)attributes {
    [attributes enumerateObjectsUsingBlock:^(NSString *coreDataAttribute, NSUInteger idx, BOOL *stop) {
        NSString *attribute = coreDataAttribute;
        
        if ([BWObjectMapper shared].shouldAutomaticallyTransformUnderscoredKeypath) {
            attribute = [coreDataAttribute BWO_stringByUnderscoringWord];
        }
        
        [self mapKeyPath:attribute toAttribute:coreDataAttribute];
    }];
}


////////////////////////////////////////////////////////////////////////////////////////////////////
- (void)mapAttributeFromDictionary:(NSDictionary *)attributes {
    [attributes enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        [self mapKeyPath:key toAttribute:obj];
    }];
}


////////////////////////////////////////////////////////////////////////////////////////////////////
- (void)hasManyWithRelationMapping:(BWObjectMapping *)mapping
                        forKeyPath:(NSString *)keyPath {
    
    [self hasManyWithRelationMapping:mapping forKeyPath:keyPath attribute:nil];
}

////////////////////////////////////////////////////////////////////////////////////////////////////
- (void)hasManyWithRelationMapping:(BWObjectMapping *)mapping
                        forKeyPath:(NSString *)keyPath
                         attribute:(NSString *)attribute {
    
    [self addRelationAttributeMappingForKeyPath:keyPath
                                      attribute:attribute
                                  objectMapping:mapping
                             objectMappingClass:nil
                                        hasMany:YES];
}


////////////////////////////////////////////////////////////////////////////////////////////////////
- (void)hasManyWithRelationObjectMappingClass:(Class)objectMappingClass
                                   forKeyPath:(NSString *)keyPath {
    
    [self hasManyWithRelationObjectMappingClass:objectMappingClass forKeyPath:keyPath attribute:nil];
}


////////////////////////////////////////////////////////////////////////////////////////////////////
- (void)hasManyWithRelationObjectMappingClass:(Class)objectMappingClass
                                   forKeyPath:(NSString *)keyPath
                                    attribute:(NSString *)attribute {
    
    [self addRelationAttributeMappingForKeyPath:keyPath
                                      attribute:attribute
                                  objectMapping:nil
                             objectMappingClass:objectMappingClass
                                        hasMany:YES];
}


////////////////////////////////////////////////////////////////////////////////////////////////////
- (void)hasOneWithRelationMapping:(BWObjectMapping *)mapping
                       forKeyPath:(NSString *)keyPath {
    
    [self hasOneWithRelationMapping:mapping forKeyPath:keyPath attribute:nil];
}


////////////////////////////////////////////////////////////////////////////////////////////////////
- (void)hasOneWithRelationMapping:(BWObjectMapping *)mapping
                       forKeyPath:(NSString *)keyPath
                        attribute:(NSString *)attribute {
    
    [self addRelationAttributeMappingForKeyPath:keyPath
                                      attribute:attribute
                                  objectMapping:mapping
                             objectMappingClass:nil
                                        hasMany:NO];
}


////////////////////////////////////////////////////////////////////////////////////////////////////
- (void)hasOneWithRelationObjectMappingClass:(Class)objectMappingClass
                                  forKeyPath:(NSString *)keyPath {
    
    [self hasOneWithRelationObjectMappingClass:objectMappingClass forKeyPath:keyPath attribute:nil];
}


////////////////////////////////////////////////////////////////////////////////////////////////////
- (void)hasOneWithRelationObjectMappingClass:(Class)objectMappingClass
                                  forKeyPath:(NSString *)keyPath
                                   attribute:(NSString *)attribute {
    
    [self addRelationAttributeMappingForKeyPath:keyPath
                                      attribute:attribute
                                  objectMapping:nil
                             objectMappingClass:objectMappingClass
                                        hasMany:NO];
}


////////////////////////////////////////////////////////////////////////////////////////////////////
- (void)setObjectClass:(Class)objectClass {
    _objectClass = objectClass;
    _objectClassString = NSStringFromClass([objectClass class]);
}


////////////////////////////////////////////////////////////////////////////////////////////////////
- (NSString *)description {
    return [NSString stringWithFormat:@"%@ %@", self.objectClassString, self.rootKeyPath];
}


////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Private


////////////////////////////////////////////////////////////////////////////////////////////////////
- (BOOL)isPropertyPrimitive:(NSString *)propertyName {
    NSString *propertyType = [BWObjectValueMapper propertyStringTypeForName:propertyName klass:self.objectClass];
    Class propertyKlass = NSClassFromString(propertyType);
    
    if ([NSNumber class] == propertyKlass ||
        [NSString class] == propertyKlass ||
        [NSDate class] == propertyKlass) {
        return YES;
    }
    
    return NO;
}


////////////////////////////////////////////////////////////////////////////////////////////////////
- (BOOL)isPropertyPrimaryKey:(NSString *)propertyName {
    if ([propertyName rangeOfString:@"ID"].location == NSNotFound) {
        return NO;
    }
    
    NSString *className = [NSStringFromClass(self.objectClass) lowercaseString];
    NSString *propertyEscapedName = [[propertyName stringByReplacingOccurrencesOfString:@"ID" withString:@""] lowercaseString];
    
    if ([className isEqualToString:propertyEscapedName]) {
        return YES;
    }
    
    return NO;
}


////////////////////////////////////////////////////////////////////////////////////////////////////
- (void)generateAutoMapping {
    Class klass = self.objectClass;
    
    while ([NSObject class] != klass) {
        unsigned int outCount, i;
        objc_property_t *properties = class_copyPropertyList(klass, &outCount);
        
        for(i = 0; i < outCount; i++) {
            objc_property_t property = properties[i];
            [self generateMappingForProperty:property];
        }
        free(properties);
        
        klass = class_getSuperclass(klass);
    }
}


////////////////////////////////////////////////////////////////////////////////////////////////////
- (void)generateMappingForProperty:(objc_property_t)property {
    NSString *propertyName = @(property_getName(property));
    if ([self isPropertyPrimitive:propertyName]) {
        
        if ([self isPropertyPrimaryKey:propertyName]) {
            [self mapPrimaryKeyAttribute:@"id" toAttribute:propertyName];
            
        } else if ([[BWObjectMapper shared].defaultMappings objectForKey:propertyName]) {
            [self mapKeyPath:[[BWObjectMapper shared].defaultMappings objectForKey:propertyName]
                 toAttribute:propertyName];
            
        } else {
            [self mapRailsAttributeFormatFromCoreDataFormatWithArray:@[ propertyName ]];
        }
    }
}


////////////////////////////////////////////////////////////////////////////////////////////////////
- (void)addRelationAttributeMappingForKeyPath:(NSString *)keyPath
                                    attribute:(NSString *)attribute
                                objectMapping:(BWObjectMapping *)objectMapping
                           objectMappingClass:(Class)objectMappingClass
                                      hasMany:(BOOL)hasMany {
    
    BWOjectRelationAttributeMapping *attributeMapping = [[BWOjectRelationAttributeMapping alloc] init];
    
    attributeMapping.keyPath = keyPath;
    attributeMapping.attribute = attribute ?: keyPath;
    attributeMapping.objectMapping = objectMapping;
    attributeMapping.objectMappingClass = objectMappingClass;
    
    if (hasMany) {
        [self.hasManyMappings setValue:attributeMapping forKey:keyPath];
    } else {
        [self.hasOneMappings setValue:attributeMapping forKey:keyPath];
    }
}


////////////////////////////////////////////////////////////////////////////////////////////////////
- (void)addAttributeMappingToObjectMapping:(BWObjectAttributeMapping *)attributeMapping {
    [self.attributeMappings setObject:attributeMapping forKey:attributeMapping.attribute];
}


@end
