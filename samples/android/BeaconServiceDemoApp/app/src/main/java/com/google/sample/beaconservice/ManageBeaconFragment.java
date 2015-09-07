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

import android.app.Activity;
import android.app.AlertDialog;
import android.app.Fragment;
import android.content.DialogInterface;
import android.content.Intent;
import android.os.Bundle;
import android.util.Log;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.ArrayAdapter;
import android.widget.Button;
import android.widget.EditText;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.Spinner;
import android.widget.TableLayout;
import android.widget.TextView;
import android.widget.Toast;

import com.google.android.gms.common.GooglePlayServicesNotAvailableException;
import com.google.android.gms.common.GooglePlayServicesRepairableException;
import com.google.android.gms.location.places.Place;
import com.google.android.gms.location.places.ui.PlacePicker;
import com.google.android.gms.maps.model.LatLng;
import com.google.android.gms.maps.model.LatLngBounds;
import com.google.sample.libproximitybeacon.ProximityBeacon;
import com.google.sample.libproximitybeacon.ProximityBeaconImpl;
import com.squareup.okhttp.Callback;
import com.squareup.okhttp.Request;
import com.squareup.okhttp.Response;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.io.IOException;

/**
 * The main beacon management UI. Depending on the status of the beacon, presents the
 * activate, deactivate and decommission options. Also allows simple CRUD operations
 * on the beacon's attachments.
 */
public class ManageBeaconFragment extends Fragment {
  private static final String TAG = ManageBeaconFragment.class.getSimpleName();

  private static final TableLayout.LayoutParams FIXED_WIDTH_COLS_LAYOUT =
    new TableLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 0.8f);

  private static final TableLayout.LayoutParams BUTTON_COL_LAYOUT =
    new TableLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1.0f);

  private Beacon beacon;
  private String namespace;

  private TextView advertisedId_Type;
  private TextView advertisedId_Id;
  private TextView status;
  private TextView placeId;
  private TextView latLng;
  private ImageView mapView;
  private TextView expectedStability;
  private TextView description;
  private Button actionButton;
  private Button decommissionButton;
  private View attachmentsDivider;
  private TextView attachmentsLabel;
  private TableLayout attachmentsTable;

  private ProximityBeacon client;

  @Override
  public void onCreate(Bundle savedInstanceState) {
    super.onCreate(savedInstanceState);
    Bundle b = this.getArguments();
    beacon = b.getParcelable("beacon");
    String accountName = b.getString("accountName");
    client = new ProximityBeaconImpl(getActivity(), accountName);
  }

  @Override
  public View onCreateView(LayoutInflater inflater,
                           ViewGroup container,
                           Bundle savedInstanceState) {
    View rootView = inflater.inflate(R.layout.fragment_manage_beacon, container, false);

    advertisedId_Type = (TextView)rootView.findViewById(R.id.advertisedId_Type);
    advertisedId_Id = (TextView)rootView.findViewById(R.id.advertisedId_Id);
    status = (TextView)rootView.findViewById(R.id.status);
    placeId = (TextView)rootView.findViewById(R.id.placeId);
    placeId.setOnClickListener(new View.OnClickListener() {
      @Override
      public void onClick(View v) {
        editLatLngAction();
      }
    });
    latLng = (TextView)rootView.findViewById(R.id.latLng);
    latLng.setOnClickListener(new View.OnClickListener() {
      @Override
      public void onClick(View v) {
        editLatLngAction();
      }
    });
    mapView = (ImageView)rootView.findViewById(R.id.mapView);
    mapView.setOnClickListener(new View.OnClickListener() {
      @Override
      public void onClick(View v) {
        editLatLngAction();
      }
    });

    expectedStability = (TextView)rootView.findViewById(R.id.expectedStability);
    expectedStability.setOnClickListener(new View.OnClickListener() {
      @Override
      public void onClick(View v) {
        AlertDialog.Builder builder =
          new AlertDialog.Builder(getActivity()).setTitle("Edit Stability");
        final ArrayAdapter<CharSequence> adapter = ArrayAdapter
          .createFromResource(getActivity(), R.array.stability_enums,
                              android.R.layout.simple_spinner_item);
        adapter.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item);
        final Spinner spinner = new Spinner(getActivity());
        spinner.setAdapter(adapter);
        // Set the position of the spinner to the current value.
        if (beacon.expectedStability != null &&
            !beacon.expectedStability.equals(Beacon.STABILITY_UNSPECIFIED)) {
          for (int i = 0; i < spinner.getCount(); i++) {
            if (beacon.expectedStability.equals(spinner.getItemAtPosition(i))) {
              spinner.setSelection(i);
            }
          }
        }
        builder.setView(spinner);
        builder.setPositiveButton("Save", new DialogInterface.OnClickListener() {
          @Override
          public void onClick(DialogInterface dialog, int which) {
            beacon.expectedStability = (String)spinner.getSelectedItem();
            updateBeacon();
            dialog.dismiss();
          }
        });
        builder.setNegativeButton("Cancel", new DialogInterface.OnClickListener() {
          @Override
          public void onClick(DialogInterface dialog, int which) {
            dialog.dismiss();
          }
        });
        builder.show();
      }
    });

    description = (TextView)rootView.findViewById(R.id.description);
    description.setOnClickListener(new View.OnClickListener() {
      @Override
      public void onClick(View v) {
        AlertDialog.Builder builder =
          new AlertDialog.Builder(getActivity()).setTitle("Edit description");
        final EditText editText = new EditText(getActivity());
        editText.setText(description.getText());
        builder.setView(editText);
        builder.setPositiveButton("Save", new DialogInterface.OnClickListener() {
          @Override
          public void onClick(DialogInterface dialog, int which) {
            beacon.description = editText.getText().toString();
            updateBeacon();
            dialog.dismiss();
          }
        });
        builder.setNegativeButton("Cancel", new DialogInterface.OnClickListener() {
          @Override
          public void onClick(DialogInterface dialog, int which) {
            dialog.dismiss();
          }
        });
        builder.show();
      }
    });

    actionButton = (Button)rootView.findViewById(R.id.actionButton);

    decommissionButton = (Button)rootView.findViewById(R.id.decommissionButton);
    decommissionButton.setOnClickListener(new View.OnClickListener() {
      @Override
      public void onClick(View v) {
        new AlertDialog.Builder(getActivity())
            .setTitle("Decommission Beacon")
            .setMessage("Are you sure you want to decommission this beacon? This operation is "
                + "irreversible and the beacon cannot be registered again")
            .setPositiveButton("Decommission", new DialogInterface.OnClickListener() {
              @Override
              public void onClick(DialogInterface dialog, int which) {
                dialog.dismiss();
                Callback decommissionCallback = new Callback() {
                  @Override
                  public void onFailure(Request request, IOException e) {
                    logErrorAndToast("Failed request: " + request, e);
                  }

                  @Override
                  public void onResponse(Response response) throws IOException {
                    if (response.isSuccessful()) {
                      beacon.status = Beacon.STATUS_DECOMMISSIONED;
                      updateBeacon();
                    } else {
                      String body = response.body().string();
                      logErrorAndToast("Unsuccessful decommissionBeacon request: " + body);
                    }
                  }
                };
                client.decommissionBeacon(decommissionCallback, beacon.getBeaconName());
              }
            })
            .setNegativeButton("Cancel", new DialogInterface.OnClickListener() {
              @Override
              public void onClick(DialogInterface dialog, int which) {
                dialog.dismiss();
              }
            })
            .show();
      }
    });

    attachmentsDivider = rootView.findViewById(R.id.attachmentsDivider);
    attachmentsLabel = (TextView)rootView.findViewById(R.id.attachmentsLabel);
    attachmentsTable = (TableLayout)rootView.findViewById(R.id.attachmentsTableLayout);

    // Fetch the namespace for the developer console project ID. We redraw the UI once that
    // request completes.
    // TODO: cache this.
    Callback listNamespacesCallback = new Callback() {
      @Override
      public void onFailure(Request request, IOException e) {
        logErrorAndToast("Failed request: " + request, e);
      }

      @Override
      public void onResponse(Response response) throws IOException {
        String body = response.body().string();
        if (response.isSuccessful()) {
          try {
            JSONObject json = new JSONObject(body);
            JSONArray namespaces = json.getJSONArray("namespaces");
            // At present there can be only one namespace.
            String tmp = namespaces.getJSONObject(0).getString("namespaceName");
            if (tmp.startsWith("namespaces/")) {
              namespace = tmp.substring("namespaces/".length());
            } else {
              namespace = tmp;
            }
            redraw();
          } catch (JSONException e) {
            Log.e(TAG, "JSONException", e);
          }
        } else {
          logErrorAndToast("Unsuccessful listNamespaces request: " + body);
        }
      }
    };
    client.listNamespaces(listNamespacesCallback);
    return rootView;
  }

  @Override
  public void onActivityResult(int requestCode, int resultCode, Intent data) {
    if (requestCode == Constants.REQUEST_CODE_PLACE_PICKER) {
      if (resultCode == Activity.RESULT_OK) {
        Place place = PlacePicker.getPlace(data, getActivity());
        if (place == null) {
          return;
        }
        // The place picker presents two selection options: "select this location" and
        // "nearby places". Only the nearby places selection returns a placeId we can
        // submit to the service; the location selection will return a hex-like 0xbeef
        // identifier for that position instead, which isn't what we want. Here we check
        // if the entire string is hex and clear the placeId if it is.
        String id = place.getId();
        if (id.startsWith("0x") && id.matches("0x[0-9a-f]+")) {
          placeId.setText("");
          beacon.placeId = "";
        } else {
          placeId.setText(id);
          beacon.placeId = id;
        }
        LatLng placeLatLng = place.getLatLng();
        latLng.setText(placeLatLng.toString());
        beacon.latitude = placeLatLng.latitude;
        beacon.longitude = placeLatLng.longitude;
        updateBeacon();
      } else {
        logErrorAndToast("Error loading place picker. Is the Places API enabled? "
            + "See https://developers.google.com/places/android-api/signup for more detail");
      }
    }
  }

  private void editLatLngAction() {
    PlacePicker.IntentBuilder builder = new PlacePicker.IntentBuilder();
    if (beacon.getLatLng() != null) {
      builder.setLatLngBounds(new LatLngBounds(beacon.getLatLng(), beacon.getLatLng()));
    }
    try {
      startActivityForResult(builder.build(getActivity()), Constants.REQUEST_CODE_PLACE_PICKER);
    }
    catch (GooglePlayServicesRepairableException e) {
      Log.e(TAG, "GooglePlayServicesRepairableException", e);
    }
    catch (GooglePlayServicesNotAvailableException e) {
      Log.e(TAG, "GooglePlayServicesNotAvailableException", e);
    }
  }

  private void updateBeacon() {
    // If the beacon hasn't been registered or was decommissioned, redraw the view and let the
    // commit happen in the parent action.
    if (beacon.status.equals(Beacon.UNREGISTERED)
        || beacon.status.equals(Beacon.STATUS_DECOMMISSIONED)) {
      redraw();
      return;
    }

    Callback updateBeaconCallback = new Callback() {
      @Override
      public void onFailure(Request request, IOException e) {
        logErrorAndToast("Failed request: " + request, e);
      }

      @Override
      public void onResponse(Response response) throws IOException {
        String body = response.body().string();
        if (response.isSuccessful()) {
          try {
            beacon = new Beacon(new JSONObject(body));
          } catch (JSONException e) {
            logErrorAndToast("Failed JSON creation from response: " + body, e);
            return;
          }
          redraw();
        } else {
          logErrorAndToast("Unsuccessful updateBeacon request: " + body);
        }
      }
    };

    JSONObject json;
    try {
      json = beacon.toJson();
    } catch (JSONException e) {
      logErrorAndToast("JSONException in creating update request", e);
      return;
    }

    client.updateBeacon(updateBeaconCallback, beacon.getBeaconName(), json);
  }

  private View.OnClickListener createActionButtonOnClickListener(final String status) {
    if (status == null) {
      return null;
    }
    if (!status.equals(Beacon.STATUS_ACTIVE) &&
        !status.equals(Beacon.STATUS_INACTIVE) &&
        !status.equals(Beacon.UNREGISTERED)) {
      return null;
    }
    return new View.OnClickListener() {
      @Override
      public void onClick(View v) {
        actionButton.setEnabled(false);

        Callback onClickCallback = new Callback() {
          @Override
          public void onFailure(Request request, IOException e) {
            logErrorAndToast("Failed request: " + request, e);
          }

          @Override
          public void onResponse(final Response response) throws IOException {
            String body = response.body().string();
            if (response.isSuccessful()) {
              try {
                JSONObject json = new JSONObject(body);
                if (json.length() > 0) {
                  // Activate, deactivate and decommission return empty responses. Register returns
                  // a beacon object.
                  beacon = new Beacon(json);
                }
                updateBeacon();
              } catch (JSONException e) {
                logErrorAndToast("Failed JSON creation from response: " + body, e);
              }
            } else {
              logErrorAndToast("Unsuccessful request: " + body);
            }
            actionButton.setEnabled(true);
          }
        };
        switch (status) {
          case Beacon.STATUS_ACTIVE:
            client.activateBeacon(onClickCallback, beacon.getBeaconName());
            break;
          case Beacon.STATUS_INACTIVE:
            client.deactivateBeacon(onClickCallback, beacon.getBeaconName());
            break;
          case Beacon.UNREGISTERED:
            try {
              JSONObject activeBeacon = beacon.toJson().put("status", Beacon.STATUS_ACTIVE);
              client.registerBeacon(onClickCallback, activeBeacon);
            }
            catch (JSONException e) {
              toast("JSONException: " + e);
              Log.e(TAG, "Failed to convert beacon to JSON", e);
              return;
            }
            break;
        }
      }
    };
  }

  private void enableActivate() {
    actionButton.setText("Activate");
    actionButton.setOnClickListener(createActionButtonOnClickListener(Beacon.STATUS_ACTIVE));
    enableAttachmentsView(true);
  }

  private void enableDeactivate() {
    actionButton.setText("Deactivate");
    actionButton.setOnClickListener(createActionButtonOnClickListener(Beacon.STATUS_INACTIVE));
    enableAttachmentsView(true);
  }

  private void enableRegister() {
    actionButton.setText("Register");
    actionButton.setOnClickListener(createActionButtonOnClickListener(Beacon.UNREGISTERED));
    enableAttachmentsView(false);
  }

  private void enableAttachmentsView(boolean b) {
    if (b) {
      attachmentsDivider.setVisibility(View.VISIBLE);
      attachmentsLabel.setVisibility(View.VISIBLE);
      attachmentsTable.setVisibility(View.VISIBLE);
    }
    else {
      attachmentsDivider.setVisibility(View.GONE);
      attachmentsLabel.setVisibility(View.GONE);
      attachmentsTable.setVisibility(View.GONE);
    }
  }

  private void redraw() {
    advertisedId_Type.setText(beacon.type);
    advertisedId_Id.setText(beacon.getHexId());

    status.setText(beacon.status);

    switch (beacon.status) {
      case Beacon.UNREGISTERED:
        enableRegister();
        break;
      case Beacon.STATUS_ACTIVE:
        enableDeactivate();
        decommissionButton.setEnabled(false);
        decommissionButton.setVisibility(View.GONE);
        break;
      case Beacon.STATUS_INACTIVE:
        enableActivate();
        decommissionButton.setEnabled(true);
        decommissionButton.setVisibility(View.VISIBLE);
        break;
      case Beacon.STATUS_DECOMMISSIONED:
        actionButton.setVisibility(View.GONE);
        decommissionButton.setEnabled(false);
        decommissionButton.setVisibility(View.GONE);
        break;
    }

    if (beacon.placeId != null) {
      placeId.setText(beacon.placeId);
    }
    else {
      placeId.setText(R.string.click_to_set);
    }

    if (beacon.getLatLng() != null) {
      latLng.setText(
        String.format("%.6f, %.6f", beacon.getLatLng().latitude, beacon.getLatLng().longitude));
      String url = String.format(
        "https://maps.googleapis.com/maps/api/staticmap?size=500x200&scale=2&markers=%.6f,%.6f",
        beacon.getLatLng().latitude, beacon.getLatLng().longitude);
      new FetchStaticMapTask(mapView).execute(url);
    }

    if (beacon.expectedStability != null) {
      expectedStability.setText(beacon.expectedStability);
    }
    else {
      expectedStability.setText(R.string.click_to_set);
    }

    if (beacon.description != null) {
      description.setText(beacon.description);
    }
    else {
      description.setText(R.string.click_to_set);
    }

    if (!beacon.status.equals(Beacon.UNREGISTERED)) {
      listAttachments();
    }
  }

  private TextView makeTextView(String text) {
    TextView textView = new TextView(getActivity());
    textView.setText(text);
    textView.setLayoutParams(FIXED_WIDTH_COLS_LAYOUT);
    return textView;
  }

  private EditText makeEditText() {
    EditText editText = new EditText(getActivity());
    editText.setLayoutParams(FIXED_WIDTH_COLS_LAYOUT);
    return editText;
  }

  private Button createAttachmentDeleteButton(final int viewId, final String attachmentName) {
    final Button button = new Button(getActivity());
    button.setLayoutParams(BUTTON_COL_LAYOUT);
    button.setText("-");
    button.setOnClickListener(new View.OnClickListener() {
      @Override
      public void onClick(View v) {
        Utils.setEnabledViews(false, button);
        Callback deleteAttachmentCallback = new Callback() {
          @Override
          public void onFailure(Request request, IOException e) {
            logErrorAndToast("Failed request: " + request, e);
          }

          @Override
          public void onResponse(Response response) throws IOException {
            if (response.isSuccessful()) {
              attachmentsTable.removeView(attachmentsTable.findViewById(viewId));
            } else {
              String body = response.body().string();
              logErrorAndToast("Unsuccessful deleteAttachment request: " + body);
            }
          }
        };
        client.deleteAttachment(deleteAttachmentCallback, attachmentName);
      }
    });
    return button;
  }

  private View.OnClickListener makeInsertAttachmentOnClickListener(final Button insertButton,
                                                                   final TextView namespaceTextView,
                                                                   final EditText typeEditText,
                                                                   final EditText dataEditText) {
    return new View.OnClickListener() {
      @Override
      public void onClick(View v) {
        final String namespace = namespaceTextView.getText().toString();
        if (namespace.length() == 0) {
          toast("namespace cannot be empty");
          return;
        }
        final String type = typeEditText.getText().toString();
        if (type.length() == 0) {
          toast("type cannot be empty");
          return;
        }
        final String data = dataEditText.getText().toString();
        if (data.length() == 0) {
          toast("data cannot be empty");
          return;
        }

        Utils.setEnabledViews(false, insertButton);
        JSONObject body = buildCreateAttachmentJsonBody(namespace, type, data);

        Callback createAttachmentCallback = new Callback() {
          @Override
          public void onFailure(Request request, IOException e) {
            logErrorAndToast("Failed request: " + request, e);
            Utils.setEnabledViews(false, insertButton);
          }

          @Override
          public void onResponse(Response response) throws IOException {
            String body = response.body().string();
            if (response.isSuccessful()) {
              try {
                JSONObject json = new JSONObject(body);
                attachmentsTable.addView(makeAttachmentRow(json), 2);
                namespaceTextView.setText(namespace);
                typeEditText.setText("");
                typeEditText.requestFocus();
                dataEditText.setText("");
                insertButton.setEnabled(true);
              } catch (JSONException e) {
                logErrorAndToast("JSONException in building attachment data", e);
              }
            } else {
              logErrorAndToast("Unsuccessful createAttachment request: " + body);
            }
            Utils.setEnabledViews(true, insertButton);
          }
        };

        client.createAttachment(createAttachmentCallback, beacon.getBeaconName(), body);
      }
    };
  }

  private JSONObject buildCreateAttachmentJsonBody(String namespace, String type, String data) {
    try {
      return new JSONObject().put("namespacedType", namespace + "/" + type)
        .put("data", Utils.base64Encode(data.getBytes()));
    }
    catch (JSONException e) {
      Log.e(TAG, "JSONException", e);
    }
    return null;
  }

  // Fetches attachments for this beacon and builds the list view showing the existing attachments
  // and a row to add more.
  private void listAttachments() {
    Callback listAttachmentsCallback = new Callback() {
      @Override
      public void onFailure(Request request, IOException e) {
        logErrorAndToast("Failed request: " + request, e);
      }

      @Override
      public void onResponse(Response response) throws IOException {
        String body = response.body().string();
        if (response.isSuccessful()) {
          try {
            JSONObject json = new JSONObject(body);
            attachmentsTable.removeAllViews();
            attachmentsTable.addView(makeAttachmentTableHeader());
            attachmentsTable.addView(makeAttachmentInsertRow());
            if (json.length() == 0) {  // No attachment data
              return;
            }
            JSONArray attachments = json.getJSONArray("attachments");
            for (int i = 0; i < attachments.length(); i++) {
              JSONObject attachment = attachments.getJSONObject(i);
              attachmentsTable.addView(makeAttachmentRow(attachment));
            }
          } catch (JSONException e) {
            Log.e(TAG, "JSONException in fetching attachments", e);
          }
        } else {
          logErrorAndToast("Unsuccessful listAttachments request: " + body);
        }
      }
    };
    client.listAttachments(listAttachmentsCallback, beacon.getBeaconName());
  }

  private LinearLayout makeAttachmentTableHeader() {
    LinearLayout headerRow = new LinearLayout(getActivity());
    headerRow.addView(makeTextView("Namespace"));
    headerRow.addView(makeTextView("Type"));
    headerRow.addView(makeTextView("Data"));

    // Attachment rows will have four elements, so insert a fake one here with the same
    // layout weight as the delete button.
    TextView dummyView = new TextView(getActivity());
    dummyView.setLayoutParams(BUTTON_COL_LAYOUT);
    headerRow.addView(dummyView);

    return headerRow;
  }

  private LinearLayout makeAttachmentInsertRow() {
    LinearLayout insertRow = new LinearLayout(getActivity());
    final TextView namespaceTextView = makeTextView(namespace);
    final EditText typeEditText = makeEditText();
    final EditText dataEditText = makeEditText();

    insertRow.addView(namespaceTextView);
    insertRow.addView(typeEditText);
    insertRow.addView(dataEditText);

    Button insertButton = new Button(getActivity());
    insertButton.setText("+");
    insertButton.setLayoutParams(BUTTON_COL_LAYOUT);
    insertButton.setOnClickListener(
      makeInsertAttachmentOnClickListener(insertButton, namespaceTextView, typeEditText,
                                          dataEditText));

    insertRow.addView(insertButton);
    return insertRow;
  }

  private LinearLayout makeAttachmentRow(JSONObject attachment) throws JSONException {
    LinearLayout row = new LinearLayout(getActivity());
    int id = View.generateViewId();
    row.setId(id);
    String[] namespacedType = attachment.getString("namespacedType").split("/");
    row.addView(makeTextView(namespacedType[0]));
    row.addView(makeTextView(namespacedType[1]));
    String dataStr = attachment.getString("data");
    String base64Decoded = new String(Utils.base64Decode(dataStr));
    row.addView(makeTextView(base64Decoded));
    row.addView(createAttachmentDeleteButton(id, attachment.getString("attachmentName")));
    return row;
  }

  private void logErrorAndToast(String message) {
    Log.e(TAG, message);
    toast(message);
  }

  private void logErrorAndToast(String message, Exception e) {
    Log.e(TAG, message, e);
    toast(message);
  }

  private void toast(String s) {
    Toast.makeText(getActivity(), s, Toast.LENGTH_LONG).show();
  }
}
