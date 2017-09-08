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

#import "AFATaskServices.h"
@import ActivitiSDK;

// Models
#import "AFAGenericFilterModel.h"
#import "AFATaskUpdateModel.h"
#import "AFATaskCreateModel.h"

// Configurations
#import "AFALogConfiguration.h"

// Services
#import "AFAUserServices.h"
#import "AFAServiceRepository.h"


static const int activitiLogLevel = AFA_LOG_LEVEL_VERBOSE; // | AFA_LOG_FLAG_TRACE;

@interface AFATaskServices () <ASDKDataAccessorDelegate>

@property (strong, nonatomic) dispatch_queue_t                          taskUpdatesProcessingQueue;
@property (strong, nonatomic) ASDKTaskNetworkServices                   *taskNetworkService;

// Task list
@property (strong, nonatomic) ASDKTaskDataAccessor                      *fetchTaskListDataAccessor;
@property (copy, nonatomic) AFATaskServicesTaskListCompletionBlock      taskListCompletionBlock;
@property (copy, nonatomic) AFATaskServicesTaskListCompletionBlock      taskListCachedResultsBlock;

// Task details
@property (strong, nonatomic) ASDKTaskDataAccessor                      *fetchTaskDetailsDataAccessor;
@property (copy, nonatomic) AFATaskServicesTaskDetailsCompletionBlock   taskDetailsCompletionBlock;
@property (copy, nonatomic) AFATaskServicesTaskDetailsCompletionBlock   taskDetailsCachedResultsBlock;

// Task content list
@property (strong, nonatomic) ASDKTaskDataAccessor                      *fetchTaskContentListDataAccessor;
@property (copy, nonatomic) AFATaskServicesTaskContentCompletionBlock   taskContentListCompletionBlock;
@property (copy, nonatomic) AFATaskServicesTaskContentCompletionBlock   taskContentListCachedResultsBlock;

// Task comment list
@property (strong, nonatomic) ASDKTaskDataAccessor                      *fetchTaskCommentListDataAccessor;
@property (copy, nonatomic) AFATaskServicesTaskCommentsCompletionBlock  taskCommentListCompletionBlock;
@property (copy, nonatomic) AFATaskServicesTaskCommentsCompletionBlock  taskCommentListCachedResultsBlock;

// Task checklist
@property (strong, nonatomic) ASDKTaskDataAccessor                      *fetchTaskChecklistDataAccessor;
@property (copy, nonatomic) AFATaskServicesTaskListCompletionBlock      taskChecklistCompletionBlock;
@property (copy, nonatomic) AFATaskServicesTaskListCompletionBlock      taskChecklistCachedResultsBlock;

// Task update
@property (strong, nonatomic) ASDKTaskDataAccessor                      *updateTaskDetailsDataAccessor;
@property (copy, nonatomic) AFATaskServicesTaskUpdateCompletionBlock    updateTaskDetailsCompletionBlock;

// Task completion
@property (strong, nonatomic) ASDKTaskDataAccessor                      *completeTaskDataAccessor;
@property (copy, nonatomic) AFATaskServicesTaskCompleteCompletionBlock  completeTaskCompletionBlock;

// Task content upload
@property (strong, nonatomic) ASDKTaskDataAccessor                      *taskContentUploadDataAccessor;
@property (copy, nonatomic) AFATaskServicesTaskContentUploadCompletionBlock taskContentUploadCompletionBlock;
@property (copy, nonatomic) AFATaskServiceTaskContentProgressBlock      taskContentUploadProgressBlock;

// Task content delete
@property (strong, nonatomic) ASDKTaskDataAccessor                      *taskContentDeleteDataAccessor;
@property (copy, nonatomic) AFATaskServiceTaskContentDeleteCompletionBlock taskContentDeleteCompletionBlock;

// Task content download
@property (strong, nonatomic) ASDKTaskDataAccessor                      *taskContentDownloadDataAccessor;
@property (copy, nonatomic) AFATaskServiceTaskContentDownloadProgressBlock   taskContentDownloadProgressBlock;
@property (copy, nonatomic) AFATaskServiceTaskContentDownloadCompletionBlock taskContentDownloadCompletionBlock;

// Task content thumbnail download
@property (strong, nonatomic) ASDKTaskDataAccessor                      *taskContentThumbnailDownloadDataAccessor;
@property (copy, nonatomic) AFATaskServiceTaskContentDownloadProgressBlock   taskContentThumbnailDownloadProgressBlock;
@property (copy, nonatomic) AFATaskServiceTaskContentDownloadCompletionBlock taskContentThumbnailDownloadCompletionBlock;

// Involve user
@property (strong, nonatomic) ASDKTaskDataAccessor                      *taskInvolveUserDataAccessor;
@property (copy, nonatomic) AFATaskServicesUserInvolvementCompletionBlock   taskInvolveUserCompletionBlock;

// Remove user
@property (strong, nonatomic) ASDKTaskDataAccessor                      *taskRemoveUserDataAccesor;
@property (copy, nonatomic) AFATaskServicesUserInvolvementCompletionBlock   taskRemoveUserCompletionBlock;

@end

@implementation AFATaskServices


#pragma mark -
#pragma mark Life cycle

- (instancetype)init {
    self = [super init];
    
    if (self) {
        self.taskUpdatesProcessingQueue = dispatch_queue_create([[NSString stringWithFormat:@"%@.`%@ProcessingQueue", [NSBundle mainBundle].bundleIdentifier, NSStringFromClass([self class])] UTF8String], DISPATCH_QUEUE_SERIAL);
        
        // Acquire and set up the app network service
        ASDKBootstrap *sdkBootstrap = [ASDKBootstrap sharedInstance];
        self.taskNetworkService = [sdkBootstrap.serviceLocator serviceConformingToProtocol:@protocol(ASDKTaskNetworkServiceProtocol)];
        self.taskNetworkService.resultsQueue = self.taskUpdatesProcessingQueue;
    }
    
    return self;
}


#pragma mark -
#pragma mark Public interface

- (void)requestTaskListWithFilter:(AFAGenericFilterModel *)taskFilter
                  completionBlock:(AFATaskServicesTaskListCompletionBlock)completionBlock
                    cachedResults:(AFATaskServicesTaskListCompletionBlock)cacheCompletionBlock {
    NSParameterAssert(completionBlock);
    
    self.taskListCompletionBlock = completionBlock;
    self.taskListCachedResultsBlock = cacheCompletionBlock;
    
    // Create request representation for the filter model
    ASDKFilterRequestRepresentation *filterRequestRepresentation = [ASDKFilterRequestRepresentation new];
    filterRequestRepresentation.jsonAdapterType = ASDKRequestRepresentationJSONAdapterTypeExcludeNilValues;
    filterRequestRepresentation.filterID = taskFilter.filterID;
    filterRequestRepresentation.appDefinitionID = taskFilter.appDefinitionID;
    filterRequestRepresentation.appDeploymentID = taskFilter.appDeploymentID;
    
    ASDKModelFilter *modelFilter = [ASDKModelFilter new];
    modelFilter.jsonAdapterType = ASDKModelJSONAdapterTypeExcludeNilValues;
    modelFilter.sortType = (NSInteger)taskFilter.sortType;
    modelFilter.state = (NSInteger)taskFilter.state;
    modelFilter.assignmentType = (NSInteger)taskFilter.assignmentType;
    modelFilter.name = taskFilter.text;
    
    filterRequestRepresentation.filterModel = modelFilter;
    filterRequestRepresentation.page = taskFilter.page;
    filterRequestRepresentation.size = taskFilter.size;
    
    self.fetchTaskListDataAccessor = [[ASDKTaskDataAccessor alloc] initWithDelegate:self];
    [self.fetchTaskListDataAccessor fetchTasksWithFilter:filterRequestRepresentation];
}

- (void)requestTaskDetailsForID:(NSString *)taskID
                completionBlock:(AFATaskServicesTaskDetailsCompletionBlock)completionBlock
                  cachedResults:(AFATaskServicesTaskDetailsCompletionBlock)cacheCompletionBlock {
    NSParameterAssert(completionBlock);
    
    self.taskDetailsCompletionBlock = completionBlock;
    self.taskDetailsCachedResultsBlock = cacheCompletionBlock;
    
    self.fetchTaskDetailsDataAccessor = [[ASDKTaskDataAccessor alloc] initWithDelegate:self];
    [self.fetchTaskDetailsDataAccessor fetchTaskDetailsForTaskID:taskID];
}

- (void)requestTaskContentForID:(NSString *)taskID
                completionBlock:(AFATaskServicesTaskContentCompletionBlock)completionBlock
                  cachedResults:(AFATaskServicesTaskContentCompletionBlock)cacheCompletionBlock {
    NSParameterAssert(completionBlock);
    
    self.taskContentListCompletionBlock = completionBlock;
    self.taskContentListCachedResultsBlock = cacheCompletionBlock;
    
    self.fetchTaskContentListDataAccessor = [[ASDKTaskDataAccessor alloc] initWithDelegate:self];
    [self.fetchTaskContentListDataAccessor fetchTaskContentForTaskID:taskID];
}

- (void)requestTaskCommentsForID:(NSString *)taskID
                 completionBlock:(AFATaskServicesTaskCommentsCompletionBlock)completionBlock
                   cachedResults:(AFATaskServicesTaskCommentsCompletionBlock)cacheCompletionBlock {
    NSParameterAssert(completionBlock);
    
    self.taskCommentListCompletionBlock = completionBlock;
    self.taskCommentListCachedResultsBlock = cacheCompletionBlock;
    
    self.fetchTaskCommentListDataAccessor = [[ASDKTaskDataAccessor alloc] initWithDelegate:self];
    [self.fetchTaskCommentListDataAccessor fetchTaskCommentsForTaskID:taskID];
}

- (void)requestTaskUpdateWithRepresentation:(AFATaskUpdateModel *)update
                                  forTaskID:(NSString *)taskID
                        withCompletionBlock:(AFATaskServicesTaskUpdateCompletionBlock)completionBlock {
    NSParameterAssert(completionBlock);
    
    self.updateTaskDetailsCompletionBlock = completionBlock;
    
    // Create request representation for the task update model
    ASDKTaskUpdateRequestRepresentation *taskUpdateRequestRepresentation = [ASDKTaskUpdateRequestRepresentation new];
    taskUpdateRequestRepresentation.jsonAdapterType = ASDKRequestRepresentationJSONAdapterTypeCustomPolicy;
    
    // Remove all nil properties but the due date
    taskUpdateRequestRepresentation.policyBlock = ^(id value, NSString *key) {
        BOOL keyShouldBeRemoved = YES;
        BOOL isNilValue = [[NSNull null] isEqual:value];
        
        if ([NSStringFromSelector(@selector(dueDate)) isEqualToString:key]) {
            keyShouldBeRemoved = NO;
        } else if (!isNilValue) {
            keyShouldBeRemoved = NO;
        }
        
        return keyShouldBeRemoved;
    };
    taskUpdateRequestRepresentation.name = update.taskName;
    taskUpdateRequestRepresentation.taskDescription = update.taskDescription;
    taskUpdateRequestRepresentation.dueDate = update.taskDueDate;
    
    self.updateTaskDetailsDataAccessor = [[ASDKTaskDataAccessor alloc] initWithDelegate:self];
    [self.updateTaskDetailsDataAccessor updateTaskWithID:taskID
                                      withRepresentation:taskUpdateRequestRepresentation];
}

- (void)requestTaskCompletionForID:(NSString *)taskID
               withCompletionBlock:(AFATaskServicesTaskCompleteCompletionBlock)completionBlock {
    NSParameterAssert(completionBlock);
    
    self.completeTaskCompletionBlock = completionBlock;
    
    self.completeTaskDataAccessor = [[ASDKTaskDataAccessor alloc] initWithDelegate:self];
    [self.completeTaskDataAccessor completeTaskWithID:taskID];
}

- (void)requestContentUploadAtFileURL:(NSURL *)fileURL
                      withContentData:(NSData *)contentData
                            forTaskID:(NSString *)taskID
                    withProgressBlock:(AFATaskServiceTaskContentProgressBlock)progressBlock
                      completionBlock:(AFATaskServicesTaskContentUploadCompletionBlock)completionBlock {
    NSParameterAssert(completionBlock);
    
    self.taskContentUploadProgressBlock = progressBlock;
    self.taskContentUploadCompletionBlock = completionBlock;
    
    self.taskContentUploadDataAccessor = [[ASDKTaskDataAccessor alloc] initWithDelegate:self];
    [self.taskContentUploadDataAccessor uploadContentForTaskWithID:taskID
                                                       fromFileURL:fileURL
                                                   withContentData:contentData];
}

- (void)requestTaskContentDeleteForContent:(ASDKModelContent *)content
                       withCompletionBlock:(AFATaskServiceTaskContentDeleteCompletionBlock)completionBlock {
    NSParameterAssert(completionBlock);
    
    self.taskContentDeleteCompletionBlock = completionBlock;
    
    self.taskContentDeleteDataAccessor = [[ASDKTaskDataAccessor alloc] initWithDelegate:self];
    [self.taskContentDeleteDataAccessor deleteContent:content];
}

- (void)requestTaskContentDownloadForContent:(ASDKModelContent *)content
                          allowCachedResults:(BOOL)allowCachedResults
                           withProgressBlock:(AFATaskServiceTaskContentDownloadProgressBlock)progressBlock
                         withCompletionBlock:(AFATaskServiceTaskContentDownloadCompletionBlock)completionBlock {
    NSParameterAssert(completionBlock);
    
    self.taskContentDownloadProgressBlock = progressBlock;
    self.taskContentDownloadCompletionBlock = completionBlock;
    
    self.taskContentDownloadDataAccessor = [[ASDKTaskDataAccessor alloc] initWithDelegate:self];
    self.taskContentDownloadDataAccessor.cachePolicy = allowCachedResults ? ASDKServiceDataAccessorCachingPolicyHybrid : ASDKServiceDataAccessorCachingPolicyAPIOnly;
    
    [self.taskContentDownloadDataAccessor downloadTaskContent:content];
}

- (void)requestTaskContentThumbnailDownloadForContent:(ASDKModelContent *)content
                                   allowCachedResults:(BOOL)allowCachedResults
                                    withProgressBlock:(AFATaskServiceTaskContentDownloadProgressBlock)progressBlock
                                  withCompletionBlock:(AFATaskServiceTaskContentDownloadCompletionBlock)completionBlock {
    NSParameterAssert(completionBlock);
    
    self.taskContentThumbnailDownloadProgressBlock = progressBlock;
    self.taskContentThumbnailDownloadCompletionBlock = completionBlock;
    
    self.taskContentThumbnailDownloadDataAccessor = [[ASDKTaskDataAccessor alloc] initWithDelegate:self];
    [self.taskContentThumbnailDownloadDataAccessor downloadThumbnailForTaskContent:content];
}

- (void)requestTaskUserInvolvement:(ASDKModelUser *)user
                         forTaskID:(NSString *)taskID
                   completionBlock:(AFATaskServicesUserInvolvementCompletionBlock)completionBlock {
    NSParameterAssert(completionBlock);
    
    self.taskInvolveUserCompletionBlock = completionBlock;
    
    self.taskInvolveUserDataAccessor = [[ASDKTaskDataAccessor alloc] initWithDelegate:self];
    [self.taskInvolveUserDataAccessor involveUser:user
                                     inTaskWithID:taskID];
}

- (void)requestToRemoveTaskUserInvolvement:(ASDKModelUser *)user
                                 forTaskID:(NSString *)taskID
                           completionBlock:(AFATaskServicesUserInvolvementCompletionBlock)completionBlock {
    NSParameterAssert(completionBlock);
    
    self.taskRemoveUserCompletionBlock = completionBlock;
    
    self.taskRemoveUserDataAccesor = [[ASDKTaskDataAccessor alloc] initWithDelegate:self];
    [self.taskRemoveUserDataAccesor removeInvolvedUser:user
                                        fromTaskWithID:taskID];
}

- (void)requestCreateComment:(NSString *)comment
                   forTaskID:(NSString *)taskID
             completionBlock:(AFATaskServicesCreateCommentCompletionBlock)completionBlock {
    NSParameterAssert(comment);
    NSParameterAssert(taskID);
    NSParameterAssert(completionBlock);
    
    [self.taskNetworkService createComment:comment
                                 forTaskID:taskID
                           completionBlock:^(ASDKModelComment *comment, NSError *error) {
                               if (!error && comment) {
                                   AFALogVerbose(@"Comment for task ID :%@ created successfully.", taskID);
                                   
                                   dispatch_async(dispatch_get_main_queue(), ^{
                                       completionBlock(comment, nil);
                                   });
                               } else {
                                   AFALogError(@"An error occured creating comment for task id %@. Reason:%@", taskID, error.localizedDescription);
                                   
                                   dispatch_async(dispatch_get_main_queue(), ^{
                                       completionBlock(nil, error);
                                   });
                               }
                           }];
}

- (void)requestCreateTaskWithRepresentation:(AFATaskCreateModel *)taskRepresentation
                            completionBlock:(AFATaskServicesTaskDetailsCompletionBlock)completionBlock {
    NSParameterAssert(taskRepresentation);
    NSParameterAssert(completionBlock);
    
    ASDKTaskCreationRequestRepresentation *taskCreationRequestRepresentation = [ASDKTaskCreationRequestRepresentation new];
    taskCreationRequestRepresentation.taskName = taskRepresentation.taskName;
    taskCreationRequestRepresentation.taskDescription = taskRepresentation.taskDescription;
    taskCreationRequestRepresentation.appDefinitionID = taskRepresentation.applicationID;
    taskCreationRequestRepresentation.assigneeID = taskRepresentation.assigneeID;
    taskCreationRequestRepresentation.jsonAdapterType = ASDKModelJSONAdapterTypeExcludeNilValues;
    
    [self.taskNetworkService createTaskWithRepresentation:taskCreationRequestRepresentation
                                          completionBlock:^(ASDKModelTask *task, NSError *error) {
                                              if (!error) {
                                                  AFALogVerbose(@"Created task %@", task.name);
                                                  
                                                  dispatch_async(dispatch_get_main_queue(), ^{
                                                      completionBlock (task, nil);
                                                  });
                                              } else {
                                                  AFALogError(@"An error occured while creating task: %@. Reason:%@", task.name, error.localizedDescription);
                                                  
                                                  dispatch_async(dispatch_get_main_queue(), ^{
                                                      completionBlock(nil, error);
                                                  });
                                              }
                                          }];
}

- (void)requestTaskClaimForTaskID:(NSString *)taskID
                  completionBlock:(AFATaskServicesClaimCompletionBlock)completionBlock {
    NSParameterAssert(taskID);
    NSParameterAssert(completionBlock);
    
    [self.taskNetworkService claimTaskWithID:taskID
                             completionBlock:^(BOOL isTaskClaimed, NSError *error) {
                                 if (!error && isTaskClaimed) {
                                     AFALogVerbose(@"Claimed task with ID:%@", taskID);
                                     
                                     dispatch_async(dispatch_get_main_queue(), ^{
                                         completionBlock (YES, nil);
                                     });
                                 } else {
                                     AFALogError(@"An error occured while claiming task with ID:%@. Reason:%@", taskID, error.localizedDescription);
                                     
                                     dispatch_async(dispatch_get_main_queue(), ^{
                                         completionBlock(NO, error);
                                     });
                                 }
                             }];
}

- (void)requestTaskUnclaimForTaskID:(NSString *)taskID
                    completionBlock:(AFATaskServicesClaimCompletionBlock)completionBlock {
    NSParameterAssert(taskID);
    NSParameterAssert(completionBlock);
    
    [self.taskNetworkService unclaimTaskWithID:taskID
                               completionBlock:^(BOOL isTaskClaimed, NSError *error) {
                                   if (!error && !isTaskClaimed) {
                                       AFALogVerbose(@"Unclaimed task with ID:%@", taskID);
                                       
                                       dispatch_async(dispatch_get_main_queue(), ^{
                                           completionBlock (NO, nil);
                                       });
                                   } else {
                                       AFALogError(@"An error occured while unclaiming task with ID:%@. Reason:%@", taskID, error.localizedDescription);
                                       
                                       dispatch_async(dispatch_get_main_queue(), ^{
                                           completionBlock(YES, error);
                                       });
                                   }
                               }];
}

- (void)requestTaskAssignForTaskWithID:(NSString *)taskID
                                toUser:(ASDKModelUser *)user
                       completionBlock:(AFATaskServicesTaskDetailsCompletionBlock)completionBlock {
    NSParameterAssert(taskID);
    NSParameterAssert(user);
    NSParameterAssert(completionBlock);
    
    [self.taskNetworkService assignTaskWithID:taskID
                                       toUser:user
                              completionBlock:^(ASDKModelTask *task, NSError *error) {
                                  if (!error && task) {
                                      AFALogVerbose(@"Assigned user:%@ to task:%@", [NSString stringWithFormat:@"%@ %@", user.userFirstName, user.userLastName], task.name);
                                      
                                      dispatch_async(dispatch_get_main_queue(), ^{
                                          completionBlock(task, nil);
                                      });
                                  } else {
                                      AFALogError(@"An error occured while assigning user:%@ to task with ID:%@. Reason:%@", [NSString stringWithFormat:@"%@ %@", user.userFirstName, user.userLastName], taskID, error.localizedDescription);
                                      
                                      dispatch_async(dispatch_get_main_queue(), ^{
                                          completionBlock(nil, error);
                                      });
                                  }
                              }];
}

- (void)requestDownloadAuditLogForTaskWithID:(NSString *)taskID
                          allowCachedResults:(BOOL)allowCachedResults
                               progressBlock:(AFATaskServiceTaskContentDownloadProgressBlock)progressBlock
                             completionBlock:(AFATaskServiceTaskContentDownloadCompletionBlock)completionBlock {
    NSParameterAssert(taskID);
    NSParameterAssert(completionBlock);
    
    [self.taskNetworkService downloadAuditLogForTaskWithID:taskID
                                        allowCachedResults:allowCachedResults
                                             progressBlock:^(NSString *formattedReceivedBytesString, NSError *error) {
                                                 AFALogVerbose(@"Downloaded %@ of content for the audit log of task with ID:%@ ", formattedReceivedBytesString, taskID);
                                                 dispatch_async(dispatch_get_main_queue(), ^{
                                                     progressBlock (formattedReceivedBytesString, error);
                                                 });
                                             } completionBlock:^(NSURL *downloadedContentURL, BOOL isLocalContent, NSError *error) {
                                                 if (!error && downloadedContentURL) {
                                                     AFALogVerbose(@"Audit log content for task with ID:%@ was downloaded successfully.", taskID);
                                                     
                                                     dispatch_async(dispatch_get_main_queue(), ^{
                                                         completionBlock(downloadedContentURL, isLocalContent,nil);
                                                     });
                                                 } else {
                                                     AFALogError(@"An error occured while downloading audit log content for task with ID:%@. Reason:%@", taskID, error.localizedDescription);
                                                     
                                                     dispatch_async(dispatch_get_main_queue(), ^{
                                                         completionBlock(nil, NO, error);
                                                     });
                                                 }
                                             }];
}

- (void)requestChecklistForTaskWithID:(NSString *)taskID
                      completionBlock:(AFATaskServicesTaskListCompletionBlock)completionBlock
                        cachedResults:(AFATaskServicesTaskListCompletionBlock)cacheCompletionBlock {
    NSParameterAssert(taskID);
    NSParameterAssert(completionBlock);
    
    self.taskChecklistCompletionBlock = completionBlock;
    self.taskChecklistCachedResultsBlock = cacheCompletionBlock;
    
    self.fetchTaskChecklistDataAccessor = [[ASDKTaskDataAccessor alloc] initWithDelegate:self];
    [self.fetchTaskChecklistDataAccessor fetchTaskCheckListForTaskID:taskID];
}

- (void)requestChecklistCreateWithRepresentation:(AFATaskCreateModel *)taskRepresentation
                                          taskID:(NSString *)taskID
                                 completionBlock:(AFATaskServicesTaskDetailsCompletionBlock)completionBlock {
    NSParameterAssert(taskRepresentation);
    NSParameterAssert(taskID);
    NSParameterAssert(completionBlock);
    
    ASDKTaskCreationRequestRepresentation *checklistCreationRequestRepresentation = [ASDKTaskCreationRequestRepresentation new];
    checklistCreationRequestRepresentation.taskName = taskRepresentation.taskName;
    checklistCreationRequestRepresentation.taskDescription = taskRepresentation.taskDescription;
    checklistCreationRequestRepresentation.assigneeID = taskRepresentation.assigneeID;
    checklistCreationRequestRepresentation.parentTaskID = taskID;
    checklistCreationRequestRepresentation.jsonAdapterType = ASDKModelJSONAdapterTypeExcludeNilValues;
    
    [self.taskNetworkService createChecklistWithRepresentation:checklistCreationRequestRepresentation
                                                        taskID:taskID
                                               completionBlock:^(ASDKModelTask *task, NSError *error) {
                                                   if (!error) {
                                                       AFALogVerbose(@"Created checklist item %@", task.name);
                                                       
                                                       dispatch_async(dispatch_get_main_queue(), ^{
                                                           completionBlock (task, nil);
                                                       });
                                                   } else {
                                                       AFALogError(@"An error occured while creating checklist item: %@. Reason:%@", task.name, error.localizedDescription);
                                                       
                                                       dispatch_async(dispatch_get_main_queue(), ^{
                                                           completionBlock(nil, error);
                                                       });
                                                   }
                                               }];
}

- (void)requestChecklistOrderUpdateWithOrderArrat:(NSArray *)orderArray
                                           taskID:(NSString *)taskID
                                  completionBlock:(AFATaskServicesTaskUpdateCompletionBlock)completionBlock {
    NSParameterAssert(orderArray);
    NSParameterAssert(taskID);
    NSParameterAssert(completionBlock);
    
    ASDKTaskChecklistOrderRequestRepresentation *checklistOrderRequestRepresentation = [ASDKTaskChecklistOrderRequestRepresentation new];
    checklistOrderRequestRepresentation.checklistOrder = orderArray;
    
    [self.taskNetworkService updateChecklistOrderWithRepresentation:checklistOrderRequestRepresentation
                                                             taskID:taskID
                                                    completionBlock:^(BOOL isTaskUpdated, NSError *error) {
                                                        if (!error && isTaskUpdated) {
                                                            AFALogVerbose(@"Updated checklist order for task with ID:%@", taskID);
                                                            
                                                            dispatch_async(dispatch_get_main_queue(), ^{
                                                                completionBlock(YES, nil);
                                                            });
                                                        } else {
                                                            AFALogError(@"An error occured while updating the checklist order for task with ID:%@. Reason:%@", taskID, error.localizedDescription);
                                                        }
                                                    }];
}


#pragma mark -
#pragma mark ASDKDataAccessorDelegate

- (void)dataAccessor:(id<ASDKServiceDataAccessorProtocol>)dataAccessor
 didLoadDataResponse:(ASDKDataAccessorResponseBase *)response {
    if (self.fetchTaskListDataAccessor == dataAccessor) {
        [self handleFetchTaskListDataAccessorResponse:response];
    } else if (self.fetchTaskDetailsDataAccessor == dataAccessor) {
        [self handleFetchTaskDetailsDataAccessorResponse:response];
    } else if (self.fetchTaskContentListDataAccessor == dataAccessor) {
        [self handleFetchTaskContentListDataAccessorResponse:response];
    } else if (self.fetchTaskCommentListDataAccessor == dataAccessor) {
        [self handleFetchTaskCommentListDataAccessorResponse:response];
    } else if (self.fetchTaskChecklistDataAccessor == dataAccessor) {
        [self handleFetchTaskChecklistDataAccessorResponse:response];
    } else if (self.updateTaskDetailsDataAccessor == dataAccessor) {
        [self handleUpdateTaskDetailsDataAccessorResponse:response];
    } else if (self.completeTaskDataAccessor == dataAccessor) {
        [self handleCompleteTaskDataAccessorResponse:response];
    } else if (self.taskContentUploadDataAccessor == dataAccessor) {
        [self handleTaskContentUploadDataAccessorResponse:response];
    } else if (self.taskContentDeleteDataAccessor == dataAccessor) {
        [self handleTaskContentDeleteDataAccessorResponse:response];
    } else if (self.taskContentDownloadDataAccessor == dataAccessor) {
        [self handleTaskContentDownloadDataAccessorResponse:response];
    } else if (self.taskContentThumbnailDownloadDataAccessor == dataAccessor) {
        [self handleTaskContentThumbnailDownloadDataAccessorResponse:response];
    } else if (self.taskInvolveUserDataAccessor == dataAccessor ||
               self.taskRemoveUserDataAccesor == dataAccessor) {
        [self handleTaskUserInvolveDataAccessorResponse:response];
    }
}

- (void)dataAccessorDidFinishedLoadingDataResponse:(id<ASDKServiceDataAccessorProtocol>)dataAccessor {
}


#pragma mark -
#pragma mark Private interface

- (void)handleFetchTaskListDataAccessorResponse:(ASDKDataAccessorResponseBase *)response {
    ASDKDataAccessorResponseCollection *taskListResponse = (ASDKDataAccessorResponseCollection *)response;
    NSArray *taskList = taskListResponse.collection;
    
    __weak typeof(self) weakSelf = self;
    if (!taskListResponse.error) {
        if (taskListResponse.isCachedData) {
            dispatch_async(dispatch_get_main_queue(), ^{
                __strong typeof(self) strongSelf = weakSelf;
                
                if (strongSelf.taskListCachedResultsBlock) {
                    strongSelf.taskListCachedResultsBlock(taskList, nil, taskListResponse.paging);
                    strongSelf.taskListCachedResultsBlock = nil;
                }
            });
            
            return;
        }
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        __strong typeof(self) strongSelf = weakSelf;
        
        if (strongSelf.taskListCompletionBlock) {
            strongSelf.taskListCompletionBlock(taskList, taskListResponse.error, taskListResponse.paging);
            strongSelf.taskListCompletionBlock = nil;
        }
    });
}

- (void)handleFetchTaskDetailsDataAccessorResponse:(ASDKDataAccessorResponseBase *)response {
    ASDKDataAccessorResponseModel *taskResponse = (ASDKDataAccessorResponseModel *)response;
    
    __weak typeof(self) weakSelf = self;
    if (!taskResponse.error) {
        if (taskResponse.isCachedData) {
            dispatch_async(dispatch_get_main_queue(), ^{
                __strong typeof(self) strongSelf = weakSelf;
                
                if (strongSelf.taskDetailsCachedResultsBlock) {
                    strongSelf.taskDetailsCachedResultsBlock(taskResponse.model, nil);
                    strongSelf.taskDetailsCachedResultsBlock = nil;
                }
            });
            
            return;
        }
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        __strong typeof(self) strongSelf = weakSelf;
        
        if (strongSelf.taskDetailsCompletionBlock) {
            strongSelf.taskDetailsCompletionBlock(taskResponse.model, taskResponse.error);
            strongSelf.taskDetailsCompletionBlock = nil;
        }
    });
}

- (void)handleFetchTaskContentListDataAccessorResponse:(ASDKDataAccessorResponseBase *)response {
    ASDKDataAccessorResponseCollection *taskContentListResponse = (ASDKDataAccessorResponseCollection *)response;
    NSArray *contentList = taskContentListResponse.collection;
    
    __weak typeof(self) weakSelf = self;
    if (!taskContentListResponse.error) {
        if (taskContentListResponse.isCachedData) {
            dispatch_async(dispatch_get_main_queue(), ^{
                __strong typeof(self) strongSelf = weakSelf;
                
                if (strongSelf.taskContentListCachedResultsBlock) {
                    strongSelf.taskContentListCachedResultsBlock(contentList, nil);
                    strongSelf.taskContentListCachedResultsBlock = nil;
                }
            });
            
            return;
        }
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        __strong typeof(self) strongSelf = weakSelf;
        
        if (strongSelf.taskContentListCompletionBlock) {
            strongSelf.taskContentListCompletionBlock(contentList, taskContentListResponse.error);
            strongSelf.taskContentListCompletionBlock = nil;
        }
    });
}

- (void)handleFetchTaskCommentListDataAccessorResponse:(ASDKDataAccessorResponseBase *)response {
    ASDKDataAccessorResponseCollection *taskCommentListResponse = (ASDKDataAccessorResponseCollection *)response;
    NSArray *commentList = taskCommentListResponse.collection;
    
    __weak typeof(self) weakSelf = self;
    if (!taskCommentListResponse.error) {
        if (taskCommentListResponse.isCachedData) {
            dispatch_async(dispatch_get_main_queue(), ^{
                __strong typeof(self) strongSelf = weakSelf;
                
                if (strongSelf.taskCommentListCachedResultsBlock) {
                    strongSelf.taskCommentListCachedResultsBlock(commentList, nil, taskCommentListResponse.paging);
                    strongSelf.taskCommentListCachedResultsBlock = nil;
                }
            });
            
            return;
        }
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        __strong typeof(self) strongSelf = weakSelf;
        
        if (strongSelf.taskCommentListCompletionBlock) {
            strongSelf.taskCommentListCompletionBlock(commentList, taskCommentListResponse.error, taskCommentListResponse.paging);
        }
    });
}

- (void)handleFetchTaskChecklistDataAccessorResponse:(ASDKDataAccessorResponseBase *)response {
    ASDKDataAccessorResponseCollection *taskCheckListResponse = (ASDKDataAccessorResponseCollection *)response;
    NSArray *checklist = taskCheckListResponse.collection;
    
    __weak typeof(self) weakSelf = self;
    if (!taskCheckListResponse.error) {
        if (taskCheckListResponse.isCachedData) {
            dispatch_async(dispatch_get_main_queue(), ^{
                __strong typeof(self) strongSelf = weakSelf;
                
                if (strongSelf.taskChecklistCachedResultsBlock) {
                    strongSelf.taskChecklistCachedResultsBlock(checklist, nil, taskCheckListResponse.paging);
                    strongSelf.taskChecklistCachedResultsBlock = nil;
                }
            });
            
            return;
        }
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        __strong typeof(self) strongSelf = weakSelf;
        
        if (strongSelf.taskChecklistCompletionBlock) {
            strongSelf.taskChecklistCompletionBlock(checklist, taskCheckListResponse.error, taskCheckListResponse.paging);
        }
    });
}

- (void)handleUpdateTaskDetailsDataAccessorResponse:(ASDKDataAccessorResponseBase *)response {
    ASDKDataAccessorResponseConfirmation *taskUpdateResponse = (ASDKDataAccessorResponseConfirmation *)response;
    
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        __strong typeof(self) strongSelf = weakSelf;
        
        if (strongSelf.updateTaskDetailsCompletionBlock) {
            strongSelf.updateTaskDetailsCompletionBlock(taskUpdateResponse.isConfirmation, taskUpdateResponse.error);
        }
    });
}

- (void)handleCompleteTaskDataAccessorResponse:(ASDKDataAccessorResponseBase *)response {
    ASDKDataAccessorResponseConfirmation *taskCompleteResponse = (ASDKDataAccessorResponseConfirmation *)response;
    
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        __strong typeof(self) strongSelf = weakSelf;
        
        if (strongSelf.completeTaskCompletionBlock) {
            strongSelf.completeTaskCompletionBlock(taskCompleteResponse.isConfirmation, taskCompleteResponse.error);
        }
    });
}

- (void)handleTaskContentUploadDataAccessorResponse:(ASDKDataAccessorResponseBase *)response {
    __weak typeof(self) weakSelf = self;
    if ([response isKindOfClass:[ASDKDataAccessorResponseProgress class]]) {
        ASDKDataAccessorResponseProgress *progressResponse = (ASDKDataAccessorResponseProgress *)response;
        NSUInteger progress = progressResponse.progress;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(self) strongSelf = weakSelf;
            
            if (strongSelf.taskContentUploadProgressBlock) {
                strongSelf.taskContentUploadProgressBlock(progress, progressResponse.error);
            }
        });
    } else if ([response isKindOfClass:[ASDKDataAccessorResponseModel class]]) {
        ASDKDataAccessorResponseModel *contentResponse = (ASDKDataAccessorResponseModel *)response;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(self) strongSelf = weakSelf;
            
            if (strongSelf.taskContentUploadCompletionBlock) {
                strongSelf.taskContentUploadCompletionBlock(contentResponse.model ? YES : NO, contentResponse.error);
                strongSelf.taskContentUploadCompletionBlock = nil;
                strongSelf.taskContentUploadProgressBlock = nil;
            }
        });
    }
}

- (void)handleTaskContentDeleteDataAccessorResponse:(ASDKDataAccessorResponseBase *)response {
    ASDKDataAccessorResponseConfirmation *contentDeleteResponse = (ASDKDataAccessorResponseConfirmation *)response;
    
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        __strong typeof(self) strongSelf = weakSelf;
        
        if (strongSelf.taskContentDeleteCompletionBlock) {
            strongSelf.taskContentDeleteCompletionBlock(contentDeleteResponse.isConfirmation, contentDeleteResponse.error);
        }
    });
}

- (void)handleTaskContentDownloadDataAccessorResponse:(ASDKDataAccessorResponseBase *)response {
    __weak typeof(self) weakSelf = self;
    if ([response isKindOfClass:[ASDKDataAccessorResponseProgress class]]) {
        ASDKDataAccessorResponseProgress *progressResponse = (ASDKDataAccessorResponseProgress *)response;
        NSString *formattedProgressString = progressResponse.formattedProgressString;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(self) strongSelf = weakSelf;
            
            if (strongSelf.taskContentDownloadProgressBlock) {
                strongSelf.taskContentDownloadProgressBlock(formattedProgressString, progressResponse.error);
            }
        });
    } else if ([response isKindOfClass:[ASDKDataAccessorResponseModel class]]) {
        ASDKDataAccessorResponseModel *contentResponse = (ASDKDataAccessorResponseModel *)response;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(self) strongSelf = weakSelf;
            
            if (strongSelf.taskContentDownloadCompletionBlock) {
                strongSelf.taskContentDownloadCompletionBlock(contentResponse.model, contentResponse.isCachedData, contentResponse.error);
                strongSelf.taskContentDownloadCompletionBlock = nil;
                strongSelf.taskContentDownloadProgressBlock = nil;
            }
        });
    }
}

- (void)handleTaskContentThumbnailDownloadDataAccessorResponse:(ASDKDataAccessorResponseBase *)response {
    __weak typeof(self) weakSelf = self;
    if ([response isKindOfClass:[ASDKDataAccessorResponseProgress class]]) {
        ASDKDataAccessorResponseProgress *progressResponse = (ASDKDataAccessorResponseProgress *)response;
        NSString *formattedProgressString = progressResponse.formattedProgressString;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(self) strongSelf = weakSelf;
            
            if (strongSelf.taskContentThumbnailDownloadProgressBlock) {
                strongSelf.taskContentThumbnailDownloadProgressBlock(formattedProgressString, progressResponse.error);
            }
        });
    } else if ([response isKindOfClass:[ASDKDataAccessorResponseModel class]]) {
        ASDKDataAccessorResponseModel *contentResponse = (ASDKDataAccessorResponseModel *)response;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(self) strongSelf = weakSelf;
            
            if (strongSelf.taskContentThumbnailDownloadCompletionBlock) {
                strongSelf.taskContentThumbnailDownloadCompletionBlock(contentResponse.model, contentResponse.isCachedData, contentResponse.error);
                strongSelf.taskContentThumbnailDownloadCompletionBlock = nil;
                strongSelf.taskContentThumbnailDownloadProgressBlock = nil;
            }
        });
    }
}

- (void)handleTaskUserInvolveDataAccessorResponse:(ASDKDataAccessorResponseBase *)response {
    ASDKDataAccessorResponseConfirmation *taskInvolveResponse = (ASDKDataAccessorResponseConfirmation *)response;
    
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        __strong typeof(self) strongSelf = weakSelf;
        
        if (strongSelf.taskInvolveUserCompletionBlock) {
            strongSelf.taskInvolveUserCompletionBlock(taskInvolveResponse.isConfirmation, taskInvolveResponse.error);
        }
    });
}

@end
