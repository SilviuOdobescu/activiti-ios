/*******************************************************************************
 * Copyright (C) 2005-2016 Alfresco Software Limited.
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

#import <UIKit/UIKit.h>
#import "AFATaskServices.h"
@class ASDKModelTask;

@protocol AFAModalTaskDetailsViewControllerDelegate <NSObject>

- (void)didCreateTask:(ASDKModelTask *)task;

@end

@protocol AFAModalTaskDetailsAction <NSObject>

- (void)executeAlertActionWithModel:(AFATaskCreateModel *)taskCreateModel
                    completionBlock:(AFATaskServicesTaskDetailsCompletionBlock)completionBlock;

@end

@interface AFAModalTaskDetailsViewController : UIViewController

@property (strong, nonatomic) NSString  *applicationID;
@property (strong, nonatomic) UIColor   *appThemeColor;
@property (strong, nonatomic) NSString  *alertTitle;
@property (strong, nonatomic) NSString  *progressTitle;
@property (strong, nonatomic) id<AFAModalTaskDetailsAction> confirmAlertAction;
@property (weak, nonatomic)   id<AFAModalTaskDetailsViewControllerDelegate> delegate;

@end
