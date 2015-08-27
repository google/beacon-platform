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

import android.os.Handler;
import android.os.Looper;

import com.squareup.okhttp.Callback;
import com.squareup.okhttp.Request;
import com.squareup.okhttp.Response;

import java.io.IOException;

/**
 * A wrapper around OkHttp's Callback class that runs its methods on the UI thread.
 */
class HttpCallback implements Callback {
  private final Callback delegate;
  private final Handler handler;

  public HttpCallback(Callback delegate) {
    this.delegate = delegate;
    this.handler = new Handler(Looper.getMainLooper());
  }

  @Override
  public void onFailure(final Request request, final IOException e) {
    handler.post(new Runnable() {
      @Override
      public void run() {
        delegate.onFailure(request, e);
      }
    });
  }

  @Override
  public void onResponse(final Response response) throws IOException {
    handler.post(new Runnable() {
      @Override
      public void run() {
        try {
          delegate.onResponse(response);
        } catch (IOException e) {
          delegate.onFailure(null, e);
        }
      }
    });
  }
}
