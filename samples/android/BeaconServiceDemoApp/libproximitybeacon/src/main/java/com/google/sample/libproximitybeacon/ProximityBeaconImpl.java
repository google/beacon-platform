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

import com.google.android.gms.auth.GoogleAuthException;
import com.google.android.gms.auth.GoogleAuthUtil;
import com.google.android.gms.auth.UserRecoverableAuthException;

import android.content.Context;
import android.os.AsyncTask;
import android.util.Log;

import com.squareup.okhttp.Callback;
import com.squareup.okhttp.MediaType;
import com.squareup.okhttp.OkHttpClient;
import com.squareup.okhttp.Request;
import com.squareup.okhttp.RequestBody;

import org.json.JSONObject;

import java.io.IOException;

public class ProximityBeaconImpl implements ProximityBeacon {
  private static final String TAG = ProximityBeaconImpl.class.getSimpleName();
  private static final String ENDPOINT = "https://proximitybeacon.googleapis.com/v1beta1/";
  private static final String SCOPE = "oauth2:https://www.googleapis.com/auth/userlocation.beacon.registry";
  public static final MediaType MEDIA_TYPE_JSON = MediaType.parse("application/json; charset=utf-8");

  private static final int GET = 0;
  private static final int PUT = 1;
  private static final int POST = 2;
  private static final int DELETE = 3;

  private final Context ctx;
  private final String account;
  private final OkHttpClient httpClient;

  public ProximityBeaconImpl(Context ctx, String account) {
    this.ctx = ctx;
    this.account = account;
    this.httpClient = new OkHttpClient();
  }

  @Override
  public void getForObserved(Callback callback, JSONObject requestBody, String apiKey) {
    // The authorization step here isn't strictly necessary. The API key is enough.
    new AuthTask("beaconinfo:getforobserved?key=" + apiKey, POST, requestBody.toString(), callback).execute();
  }

  @Override
  public void activateBeacon(Callback callback, String beaconName) {
    new AuthTask(beaconName + ":activate", POST, "", callback).execute();
  }

  @Override
  public void deactivateBeacon(Callback callback, String beaconName) {
    new AuthTask(beaconName + ":deactivate", POST, "", callback).execute();
  }

  @Override
  public void decommissionBeacon(Callback callback, String beaconName) {
    new AuthTask(beaconName + ":decommission", POST, "", callback).execute();
  }

  @Override
  public void getBeacon(Callback callback, String beaconName) {
    new AuthTask(beaconName, callback).execute();
  }

  @Override
  public void listBeacons(Callback callback, String query) {
    new AuthTask("beacons" + "?q=" + query, callback).execute();
  }

  @Override
  public void registerBeacon(Callback callback, JSONObject requestBody) {
    new AuthTask("beacons:register", POST, requestBody.toString(), callback).execute();
  }

  @Override
  public void updateBeacon(Callback callback, String beaconName, JSONObject requestBody) {
    new AuthTask(beaconName, PUT, requestBody.toString(), callback).execute();
  }

  @Override
  public void batchDeleteAttachments(Callback callback, String beaconName) {
    new AuthTask(beaconName + "/attachments:batchDelete", POST, "", callback).execute();
  }

  @Override
  public void createAttachment(Callback callback, String beaconName, JSONObject requestBody) {
    new AuthTask(beaconName + "/attachments", POST, requestBody.toString(), callback).execute();
  }

  @Override
  public void deleteAttachment(Callback callback, String attachmentName) {
    new AuthTask(attachmentName, DELETE, "", callback).execute();
  }

  @Override
  public void listAttachments(Callback callback, String beaconName) {
    new AuthTask(beaconName + "/attachments?namespacedType=*/*", callback).execute();
  }

  @Override
  public void listDiagnostics(Callback callback, String beaconName) {
    new AuthTask(beaconName + "/diagnostics", callback).execute();
  }

  @Override
  public void listNamespaces(Callback callback) {
    new AuthTask("namespaces", callback).execute();
  }

  private class AuthTask extends AsyncTask<Void, Void, Void> {

    public static final String AUTHORIZATION = "Authorization";
    public static final String BEARER = "Bearer ";
    private final String urlPart;
    private final int method;
    private final String json;
    private final Callback callback;

    AuthTask(String urlPart, Callback callback) {
      this(urlPart, GET, "", callback);
    }

    AuthTask(String urlPart, int method, String json, Callback callback) {
      this.urlPart = urlPart;
      this.method = method;
      this.json = json;
      this.callback = callback;
    }

    @Override
    protected Void doInBackground(Void... params) {
      try {
        final String token = GoogleAuthUtil.getToken(ctx, account, SCOPE);
        Request.Builder requestBuilder = new Request.Builder()
            .header(AUTHORIZATION, BEARER + token)
            .url(ENDPOINT + urlPart);
        switch (method) {
          case PUT:
            requestBuilder.put(RequestBody.create(MEDIA_TYPE_JSON, json));
            break;
          case POST:
            requestBuilder.post(RequestBody.create(MEDIA_TYPE_JSON, json));
            break;
          case DELETE:
            requestBuilder.delete(RequestBody.create(MEDIA_TYPE_JSON, json));
            break;
          default: break;
        }
        Request request = requestBuilder.build();
        httpClient.newCall(request).enqueue(new HttpCallback(callback));
      } catch (UserRecoverableAuthException e) {
        // GooglePlayServices.apk is either old, disabled, or not present
        // so we need to show the user some UI in the activity to recover.
        Log.e(TAG, "UserRecoverableAuthException", e);
      } catch (GoogleAuthException e) {
        // Some other type of unrecoverable exception has occurred.
        // Report and log the error as appropriate for your app.
        Log.e(TAG, "GoogleAuthException", e);
      } catch (IOException e) {
        // The fetchToken() method handles Google-specific exceptions,
        // so this indicates something went wrong at a higher level.
        // TIP: Check for network connectivity before starting the AsyncTask.
        Log.e(TAG, "IOException", e);
      }
      return null;
    }
  }
}
