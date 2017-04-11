/*******************************************************************************
 * Copyright (C) 2005-2017 Alfresco Software Limited.
 *
 * This file is part of the Alfresco Activiti Mobile iOS App.
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

#import "AFATaskListViewModel.h"

// Constants
#import "AFALocalizationConstants.h"

@implementation AFATaskListViewModel


#pragma mark -
#pragma mark Public interface 

- (NSString *)noRecordsLabelText {
    return NSLocalizedString(kLocalizationListScreenNoTasksAvailableText, @"No tasks available text");
    
    NSLocalizedString(kLocalizationProcessInstanceScreenNoProcessInstancesText, @"No process instances text");
}

- (NSString *)searchTextFieldPlacholderText {
    NSLocalizedString(kLocalizationListScreenProcessInstancesText, @"process instances text");
    return [NSString stringWithFormat:NSLocalizedString(kLocalizationListScreenSearchFieldPlaceholderFormat, @"Search bar format"), NSLocalizedString(kLocalizationListScreenTasksText, @"tasks text")];
}

@end