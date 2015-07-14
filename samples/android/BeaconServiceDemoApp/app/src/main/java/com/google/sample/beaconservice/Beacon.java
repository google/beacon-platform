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

import android.os.Parcel;
import android.os.Parcelable;
import android.support.annotation.Nullable;

import com.google.android.gms.maps.model.LatLng;

import org.json.JSONException;
import org.json.JSONObject;

/**
 * A simple struct representation of a Beacon object. Supports basic parsing and serialization
 * to and from JSONObject.
 */
public class Beacon implements Parcelable {
  // These constants are in the Proximity Service Status enum:
  static final String STATUS_UNSPECIFIED = "STATUS_UNSPECIFIED";
  static final String STATUS_ACTIVE = "ACTIVE";
  static final String STATUS_INACTIVE = "INACTIVE";
  static final String STATUS_DECOMMISSIONED = "DECOMMISSIONED";
  static final String STABILITY_UNSPECIFIED = "STABILITY_UNSPECIFIED";

  // These constants are convenience for this app:
  static final String UNREGISTERED = "UNREGISTERED";
  static final String NOT_AUTHORIZED = "NOT_AUTHORIZED";

  String type;
  byte[] id;
  String status;
  String placeId;
  Double latitude;
  Double longitude;
  String expectedStability;
  String description;

  // This isn't really a beacon property, but it's useful to have it here so we can sort
  // the list of beacons during scanning so the closest and/or strongest is listed first.
  // It doesn't need to be persisted via the parcelable.
  int rssi;

  public Beacon(String type, byte[] id, String status, int rssi) {
    this.type = type;
    this.id = id;
    this.status = status;
    this.placeId = null;
    this.latitude = null;
    this.longitude = null;
    this.expectedStability = null;
    this.description = null;
    this.rssi = rssi;
  }

  public Beacon(JSONObject response) {
    try {
      JSONObject json = response.getJSONObject("advertisedId");
      type = json.getString("type");
      id = Utils.base64Decode(json.getString("id"));
    } catch (JSONException e) {
      // NOP
    }

    try {
      status = response.getString("status");
    } catch (JSONException e) {
      status = STATUS_UNSPECIFIED;
    }

    try {
      placeId = response.getString("placeId");
    } catch (JSONException e) {
      // NOP
    }

    try {
      JSONObject latLngJson = response.getJSONObject("latLng");
      latitude = latLngJson.getDouble("latitude");
      longitude = latLngJson.getDouble("longitude");
    } catch (JSONException e) {
      latitude = null;
      longitude = null;
    }

    try {
      expectedStability = response.getString("expectedStability");
    } catch (JSONException e) {
      // NOP
    }

    try {
      description = response.getString("description");
    } catch (JSONException e) {
      // NOP
    }

  }

  public JSONObject toJson() throws JSONException {
    JSONObject json = new JSONObject();
    JSONObject advertisedId = new JSONObject()
        .put("type", type)
        .put("id", Utils.base64Encode(id));
    json.put("advertisedId", advertisedId);
    if (!status.equals(STATUS_UNSPECIFIED)) {
      json.put("status", status);
    }
    if (placeId != null) {
      json.put("placeId", placeId);
    }
    if (latitude != null && longitude != null) {
      JSONObject latLng = new JSONObject();
      latLng.put("latitude", latitude);
      latLng.put("longitude", longitude);
      json.put("latLng", latLng);
    }
    if (expectedStability != null && !expectedStability.equals(STABILITY_UNSPECIFIED)) {
      json.put("expectedStability", expectedStability);
    }
    if (description != null) {
      json.put("description", description);
    }
    // TODO: beacon properties
    return json;
  }

  public String getHexId() {
    return Utils.toHexString(id);
  }

  /**
   * The beaconName is formatted as "beacons/%d!%s" where %d is an integer representing the
   * beacon ID type. For Eddystone this is 3. The %s is the base16 (hex) ASCII for the ID bytes.
   */
  public String getBeaconName() {
    return String.format("beacons/3!%s", getHexId());
  }

  @Nullable
  public LatLng getLatLng() {
    if (latitude == null || longitude == null) {
      return null;
    }
    return new LatLng(latitude, longitude);
  }

  @Override
  public int describeContents() {
    return 0;
  }

  private Beacon(Parcel source) {
    type = source.readString();
    int len = source.readInt();
    id = new byte[len];
    source.readByteArray(id);
    status = source.readString();
    if (source.readInt() == 1) {
      placeId = source.readString();
    }
    if (source.readInt() == 1) {
      latitude = source.readDouble();
    }
    if (source.readInt() == 1) {
      longitude = source.readDouble();
    }
    if (source.readInt() == 1) {
      expectedStability = source.readString();
    }
    if (source.readInt() == 1) {
      description = source.readString();
    }
  }

  @Override
  public void writeToParcel(Parcel dest, int flags) {
    dest.writeString(type);
    dest.writeByteArray(id);
    dest.writeString(status);
    if (placeId != null) {
      dest.writeInt(1);
      dest.writeString(placeId);
    } else {
      dest.writeInt(0);
    }
    if (latitude != null) {
      dest.writeInt(1);
      dest.writeDouble(latitude);
    } else {
      dest.writeInt(0);
    }
    if (longitude != null) {
      dest.writeInt(1);
      dest.writeDouble(longitude);
    } else {
      dest.writeInt(0);
    }
    if (expectedStability != null ) {
      dest.writeInt(1);
      dest.writeString(expectedStability);
    } else {
      dest.writeInt(0);
    }
    if (description != null) {
      dest.writeInt(1);
      dest.writeString(description);
    } else {
      dest.writeInt(0);
    }
  }

  public static final Parcelable.Creator<Beacon> CREATOR = new Parcelable.Creator<Beacon>() {

    @Override
    public Beacon createFromParcel(Parcel source) {
      return new Beacon(source);
    }

    @Override
    public Beacon[] newArray(int size) {
      return new Beacon[size];
    }
  };

}
