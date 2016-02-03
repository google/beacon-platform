# Android Beacon Service Demo App
A simple app that demonstrates usage of the [Proximity Beacon API](https://developers.google.com/beacons/proximity/).
It contains a [reusable library module](BeaconServiceDemoApp/libproximitybeacon) that implements async HTTP communication with the proximity beacon service.

## Requirements
The app was developed with [Android Studio](http://developer.android.com/sdk/) and targets the Android Lollipop 5.1 (API 22) platform.

You must have at least one Google account on the device.

You *must* tie your version of the app to a project in the Google Developers Console. Failure to do this will mean that all your calls to the Proximity Beacon API will fail with 403 errors. In particular, when you launch the app and scan for devices, all sighted beacons will appear to be locked (that is, owned by someone else).

## Registering the app with the Google Developers Console

The Proximity Beacon API is associated with your Google Developers Console account and uses the standard GDC authorization mechanisms. Follow the instructions at the [Authorizing with Google for REST APIs](https://developers.google.com/android/guides/http-auth) guide carefully to create a project and register the app with your account.

- At step 4 where it says "Enable the API you'd like to use by setting the Status to ON", search for `Google Proximity Beacon API` and set its status to enabled.
- You must create both an Android API Key and an Android OAuth 2.0 client ID.
- The package name is `com.google.sample.beaconservice`
- Note that there's currently a typo in how to get the SHA1 hash. The command you need to run is `keytool -exportcert -alias androiddebugkey -keystore ~/.android/debug.keystore -list -v`. Note the space before the `-keystore` switch.

## Dependencies
Enumerated in the app's [build.gradle](BeaconServiceDemoApp/app/build.gradle), we require:

- [Android 5.1](http://developer.android.com/about/versions/lollipop.html)
- [Google Play Services](https://developers.google.com/android/guides/overview) (for account management and authorization utilities)
- [OkHttp](http://square.github.io/okhttp/) (Async HTTP library)
- [Joda-Time](http://www.joda.org/joda-time/)

If you use Android Studio these dependencies are managed automatically for you. (When you first import the project you'll be asked to sync the relevant modules from the SDK manager.)

## Building and Running
Import the BeaconServiceDemoApp folder into Android Studio as an existing project and select `Run > Run app`.

When launched click the `scan` button to discover any nearby [Eddystone](https://github.com/google/eddystone) devices broadcasting an Eddystone-UID frame. (If you don't have an Eddystone device around you can use the [TxEddystone-UID app](https://github.com/google/eddystone/tree/master/eddystone-uid/tools/txeddystone-uid) to turn a compatible phone into one.) Detected beacons will be listed with their IDs, ordered from strongest signal to weakest.

The app will then use the [beacons.get](https://developers.google.com/beacons/proximity/reference/rest/v1beta1/beacons/get) method to fetch the status of each beacon, updating the beacons icon as the results are returned. The icons correspond to the beacon's status:

- ![check-circle](BeaconServiceDemoApp/app/src/main/res/drawable-hdpi/ic_action_check_circle.png) Registered to you and currently active (green) or inactive (orange)
- ![highlight-off](BeaconServiceDemoApp/app/src/main/res/drawable-hdpi/ic_action_highlight_off.png) Registered to you and decommissioned
- ![lock-open](BeaconServiceDemoApp/app/src/main/res/drawable-hdpi/ic_action_lock_open.png) Unregistered
- ![lock](BeaconServiceDemoApp/app/src/main/res/drawable-hdpi/ic_action_lock.png) Registered to someone else
- ![help](BeaconServiceDemoApp/app/src/main/res/drawable-hdpi/ic_action_help.png) Unknown status

Clicking on an entry takes you to the management screen for that beacon. There you'll be able to register the beacon, update the location, stability, description, activation status, and create and delete simple attachment data. Fields that are editable are marked with the ![mode-edit](BeaconServiceDemoApp/app/src/main/res/drawable-mdpi/ic_action_mode_edit.png) icon.

## FAQ
Q. When I launch the app my beacons appear to be locked! Clicking on them says "Not Authorized"!

A. The app fetches the status of every sighted beacon with a [get](https://developers.google.com/beacons/proximity/reference/rest/v1beta1/beacons/get) call. A 403 means you don't have permission. If you're certain the beacon ID hasn't been registered by someone else, this is because you haven't done the Google Developers Console dance correctly. Check that you've followed all the steps outlined above. You need to have a dev console project, with an OAuth 2.0 Client ID that has the right package name and the SHA1 of the key that Android Studio is using to sign your app. If any piece of this puzzle is missing, the server will reject your calls with a 403 not authorized call.
