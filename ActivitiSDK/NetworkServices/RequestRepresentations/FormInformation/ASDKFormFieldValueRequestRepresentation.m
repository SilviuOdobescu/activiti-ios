/*******************************************************************************
 * Copyright (C) 2005-2016 Alfresco Software Limited.
 *
 * This file is part of the Alfresco Activiti Mobile SDK.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *  http://www.apache.org/licenses/LICENSE-2.0
 *
 *  Unless required by applicable law or agreed to in writing, software
 *  distributed under the License is distributed on an "AS IS" BASIS,
 *  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *  See the License for the specific language governing permissions and
 *  limitations under the License.
 ******************************************************************************/

#import "ASDKFormFieldValueRequestRepresentation.h"
#import "ASDKModelFormFieldValue.h"
#import "ASDKModelFormField.h"
#import "ASDKNetworkServiceConstants.h"
#import "ASDKModelFormFieldOption.h"
#import "ASDKModelUser.h"
#import "ASDKModelDynamicTableFormField.h"

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

@implementation ASDKFormFieldValueRequestRepresentation

#pragma mark -
#pragma mark MTLJSONSerializing Delegate

+ (NSDictionary *)JSONKeyPathsByPropertyKey {
    return @{//Objc property          JSON property
             @"formFields"          : @"values",
             @"outcome"             : @"outcome"
             };
}


#pragma mark -
#pragma mark Value transformations

+ (NSValueTransformer *)formFieldsJSONTransformer {
    return [MTLValueTransformer transformerUsingReversibleBlock:^id(NSDictionary *formFields, BOOL *success, NSError *__autoreleasing *error) {
        NSMutableDictionary *formFieldMetadataValuesDict = [NSMutableDictionary dictionary];
        
        for (NSNumber *sectionCount in formFields.allKeys) {
            // Extract the form fields for the correspondent container
            if ([formFields[sectionCount] isKindOfClass:ASDKModelDynamicTableFormField.class]) {
                NSMutableArray *rowValues = [NSMutableArray new];

                for (NSArray *row in [formFields[sectionCount] values]) {
                    NSMutableDictionary *columnValues = [NSMutableDictionary new];
                    
                    for (ASDKModelFormField *columnFormField in row) {
                        id formFieldValue = [self determineValueForFormField:columnFormField];
                        if (formFieldValue) {
                            [columnValues setObject:formFieldValue
                                             forKey:columnFormField.instanceID];
                        }
                    }
                    [rowValues addObject:columnValues];
                }
                [formFieldMetadataValuesDict setObject:rowValues
                                                forKey:[formFields[sectionCount] instanceID]];

            } else {
                for (ASDKModelFormField *formField in [formFields[sectionCount] formFields]) {
                    id formFieldValue = [self determineValueForFormField:formField];
                    if (formFieldValue) {
                        [formFieldMetadataValuesDict setObject:formFieldValue
                                                        forKey:formField.instanceID];
                    }
                }
            }
        }
        
        return formFieldMetadataValuesDict;
    }];
}

+ (id) determineValueForFormField:(ASDKModelFormField *)formField {
    
    id formFieldValue = nil;
    
    if (ASDKModelFormFieldRepresentationTypeReadOnly != formField.representationType
        && ASDKModelFormFieldRepresentationTypeContainer != formField.representationType) {
        
        // If there's an option field available change the nesting structure
        if (formField.metadataValue.option) {
            formFieldValue = @{kASDKAPIGenericIDParameter  : formField.instanceID,
                               kASDKAPIGenericNameParameter: formField.metadataValue.option.attachedValue};
        } else if (formField.metadataValue.attachedValue) { // if there's a attached value
            // special date field handling
            if (formField.representationType == ASDKModelFormFieldRepresentationTypeDate) {
                // create date object from saved string
                NSDateFormatter *displayDateFormatter = [[NSDateFormatter alloc] init];
                [displayDateFormatter setDateFormat:@"dd-MM-yyyy"];
                NSDate *storedDate = [displayDateFormatter dateFromString:formField.metadataValue.attachedValue];
                
                //format submit date (2016-02-23T23:00:000Z)
                NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
                dateFormatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
                dateFormatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss.SSS'Z";
                
                formFieldValue = [dateFormatter stringFromDate:storedDate];
            } else {
                formFieldValue = formField.metadataValue.attachedValue;
            }
        } else if (formField.values) { // otherwise use the original value
            // special attach field handling
            if (formField.representationType == ASDKModelFormFieldRepresentationTypeAttach) {
                NSMutableArray *modelContentArray = [NSMutableArray new];
                for (ASDKModelContent *modelContent in formField.values) {
                    [modelContentArray addObject:modelContent.instanceID];
                }
                formFieldValue = [modelContentArray componentsJoinedByString:@","];
            }
            // special radio / dropdown field handling
            else if (formField.representationType == ASDKModelFormFieldRepresentationTypeDropdown ||
                     formField.representationType == ASDKModelFormFieldRepresentationTypeRadio) {
                if ([formField.values.firstObject isKindOfClass:NSDictionary.class]) {
                    formFieldValue = formField.values.firstObject;
                } else {
                    for (ASDKModelFormFieldOption *formFieldOption in formField.formFieldOptions) {
                        if ([formFieldOption.name isEqualToString:formField.values.firstObject]) {
                            // check if option has id (dynamic table dropdown column types don't have any)
                            NSString *optionID = @"";
                            if (formFieldOption.instanceID) {
                                optionID = formFieldOption.instanceID;
                            }
                            formFieldValue = @{kASDKAPIGenericIDParameter  : optionID,
                                               kASDKAPIGenericNameParameter: formField.values.firstObject};
                            break;
                        }
                    }
                }
            }
            // special people field handling
            else if (formField.representationType == ASDKModelFormFieldRepresentationTypePeople) {
                NSError *error = nil;
                if (formField.values.count > 1) {
                    NSArray *JSONDictionaryArr = [MTLJSONAdapter JSONArrayFromModels:formField.values
                                                                               error:&error];
                    formFieldValue = JSONDictionaryArr;
                } else if (formField.values.count == 1) {
                    
                    NSDictionary *JSONDictionary = [MTLJSONAdapter JSONDictionaryFromModel:formField.values.firstObject
                                                                                     error:&error];
                    formFieldValue = JSONDictionary;
                }
            }
            // special people field handling
            else if (formField.representationType == ASDKModelFormFieldRepresentationTypeBoolean) {
                if (!formField.values.firstObject) {
                    formFieldValue = @NO;
                }
            }
            else {
                formFieldValue = formField.values.firstObject;
            }
            
        }
    }
    
    return formFieldValue;
}

@end