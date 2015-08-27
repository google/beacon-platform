// Copyright 2015 Google Inc. All rights reserved.
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

package com.google.sample.libproximitybeacon;

import com.squareup.okhttp.Callback;

import org.json.JSONObject;

/**
 * Asynchronous HTTP library for the ProximityBeacon API.
 * https://developers.google.com/beacons/proximity/reference/rest/
 */
public interface ProximityBeacon {

  /**
   * https://developers.google.com/beacons/proximity/reference/rest/v1beta1/beaconinfo/getforobserved
   */
  void getForObserved(Callback callback, JSONObject requestBody, String apiKey);

  /**
   * https://developers.google.com/beacons/proximity/reference/rest/v1beta1/beacons/activate
   */
  void activateBeacon(Callback callback, String beaconName);

  /**
   * https://developers.google.com/beacons/proximity/reference/rest/v1beta1/beacons/deactivate
   */
  void deactivateBeacon(Callback callback, String beaconName);

  /**
   * https://developers.google.com/beacons/proximity/reference/rest/v1beta1/beacons/decommission
   */
  void decommissionBeacon(Callback callback, String beaconName);

  /**
   * https://developers.google.com/beacons/proximity/reference/rest/v1beta1/beacons/get
   */
  void getBeacon(Callback callback, String beaconName);

  /**
   * https://developers.google.com/beacons/proximity/reference/rest/v1beta1/beacons/list
   */
  void listBeacons(Callback callback, String query);

  /**
   * https://developers.google.com/beacons/proximity/reference/rest/v1beta1/beacons/register
   */
  void registerBeacon(Callback callback, JSONObject requestBody);

  /**
   * https://developers.google.com/beacons/proximity/reference/rest/v1beta1/beacons/update
   */
  void updateBeacon(Callback callback, String beaconName, JSONObject requestBody);

  /**
   * https://developers.google.com/beacons/proximity/reference/rest/v1beta1/beacons.attachments/batchDelete
   */
  void batchDeleteAttachments(Callback callback, String beaconName);

  /**
   * https://developers.google.com/beacons/proximity/reference/rest/v1beta1/beacons.attachments/create
   */
  void createAttachment(Callback callback, String beaconName, JSONObject requestBody);

  /**
   * https://developers.google.com/beacons/proximity/reference/rest/v1beta1/beacons.attachments/delete
   */
  void deleteAttachment(Callback callback, String attachmentName);

  /**
   * https://developers.google.com/beacons/proximity/reference/rest/v1beta1/beacons.attachments/list
   */
  void listAttachments(Callback callback, String beaconName);

  /**
   * https://developers.google.com/beacons/proximity/reference/rest/v1beta1/beacons.diagnostics/list
   */
  void listDiagnostics(Callback callback, String beaconName);

  /**
   * https://developers.google.com/beacons/proximity/reference/rest/v1beta1/namespaces/list
   */
  void listNamespaces(Callback callback);

}
