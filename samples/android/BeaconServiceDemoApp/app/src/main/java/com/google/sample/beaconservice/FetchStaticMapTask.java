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

package com.google.sample.beaconservice;

import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.os.AsyncTask;
import android.util.Log;
import android.widget.ImageView;

import java.io.IOException;
import java.io.InputStream;

/**
 * Simple AsyncTask to fetch an image from the Static Maps API.
 */
class FetchStaticMapTask extends AsyncTask<String, Void, Bitmap> {
  private static final String TAG = FetchStaticMapTask.class.getSimpleName();

  private final ImageView view;

  FetchStaticMapTask(ImageView view) {
    this.view = view;
  }

  @Override
  protected Bitmap doInBackground(String... urls) {
    String url = urls[0];
    Bitmap image = null;
    try {
      InputStream in = new java.net.URL(url).openStream();
      image = BitmapFactory.decodeStream(in);
    }
    catch (IOException e) {
      Log.e(TAG, "IOException fetching map view", e);
    }
    return image;
  }

  @Override
  protected void onPostExecute(Bitmap bitmap) {
    if (bitmap != null) {
      view.setImageBitmap(bitmap);
    }
  }
}
