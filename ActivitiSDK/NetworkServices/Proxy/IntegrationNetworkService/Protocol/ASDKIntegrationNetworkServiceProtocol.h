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

#import <Foundation/Foundation.h>

@class ASDKModelPaging,
ASDKIntegrationNodeContentRequestRepresentation;

typedef void  (^ASDKIntegrationAccountListCompletionBlock)  (NSArray *accounts, NSError *error, ASDKModelPaging *paging);
typedef void  (^ASDKIntegrationNetworkListCompletionBlock)  (NSArray *networks, NSError *error, ASDKModelPaging *paging);
typedef void  (^ASDKIntegrationSiteListCompletionBlock)     (NSArray *sites, NSError *error, ASDKModelPaging *paging);
typedef void  (^ASDKIntegrationContentListCompletionBlock)  (NSArray *contentList, NSError *error, ASDKModelPaging *paging);
typedef void  (^ASDKIntegrationContentUploadCompletionBlock)(ASDKModelContent *contentModel, NSError *error);

@protocol ASDKIntegrationNetworkServiceProtocol <NSObject>

/**
 *  Fetches and returns via the completion block a list of external integration service accounts  
 *
 *  @param completionBlock Completion block providing an integration account list, an optional
 *                         error reason and paging information
 */
- (void)fetchIntegrationAccountsWithCompletionBlock:(ASDKIntegrationAccountListCompletionBlock)completionBlock;

/**
 *  Fetches and returns via the completion block a list of external integration networks
 *
 *  @param completionBlock Completion block providing a network list, an optional error reason and
 *                         paging information
 */
- (void)fetchIntegrationNetworksWithCompletionBlock:(ASDKIntegrationNetworkListCompletionBlock)completionBlock;

/**
 *  Fetches and returns via the completion block a list of external integration sites that are
 *  associated with a specified network ID.
 * 
 *  @param networkID       The network ID for which the site list is retrieved
 *
 *  @param completionBlock Completion block providing a site list, an optional error reason and 
 *                         paging information
 */
- (void)fetchIntegrationSitesForNetworkID:(NSString *)networkID
                          completionBlock:(ASDKIntegrationSiteListCompletionBlock)completionBlock;

/**
 *  Fetches and returns via the completion block a list of content elements that is associated
 *  with a specified network and site ID.
 *
 *  @param networkID       The network ID for which the content list is retrieved
 *  @param siteID          The site ID for which the content list is retrieved
 *  @param completionBlock Completion block providing a content list, an optional error reason and
 *                         paging information
 */
- (void)fetchIntegrationContentForNetworkID:(NSString *)networkID
                                     siteID:(NSString *)siteID
                            completionBlock:(ASDKIntegrationContentListCompletionBlock)completionBlock;

/**
 *  Fetches and returns via the completion block a list of content elements that are associated with
 *  a specified network and folder ID.
 *
 *  @param networkID       The network ID for which the content list is retrieved
 *  @param folderID        The site ID for which the content list is retrieved
 *  @param completionBlock Completion block providing a content list, an optional error reason and
 *                         paging information
 */
- (void)fetchIntegrationFolderContentForNetworkID:(NSString *)networkID
                                         folderID:(NSString *)folderID
                                  completionBlock:(ASDKIntegrationContentListCompletionBlock)completionBlock;

/**
 *  Uploads content from an external integration service that is described inside the provided request 
 *  representation and reports back via a completion block the status of the upload.
 *
 *  @param uploadIntegrationContentWithRepresentation Request representation object describing the content to be 
 *                                                    uploaded like the source and the sourceID
 *  @param completionBlock Completion block providing a refference for the uploaded model and an optional error
 *                         reason.
 */
- (void)uploadIntegrationContentWithRepresentation:(ASDKIntegrationNodeContentRequestRepresentation *)uploadIntegrationContentWithRepresentation
                                   completionBlock:(ASDKIntegrationContentUploadCompletionBlock)completionBlock;

@end
