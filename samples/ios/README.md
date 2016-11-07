
# Beacon Service Demo App (iOS)

This is the demo application for the Google Proximity Beacon APIs for iOS. It
also includes a sample Eddystone scanner, which it uses to find beacons on live
devices.

### Building The Sample

Setting up this sample is mostly about getting set up with the various Google
APIs, their authentication keys, and OAuth stuff. The actual app itself is
CocoaPod based and quite easy to get running.

**FOLLOW THESE INSTRUCTIONS SUPER CAREFULLY!**

0. Make sure your computer has CocoaPods installed,
   [http://cocoapods.org](http://cocoapods.org), as well as Xcode 6 (We've
   had reports that Xcode 7 betas might be problematic at this point.)

1. To get all the component pieces.

        cd ~/the/folder/that/has/"Podfile"/in/it
        pod install
        open BeaconServiceDemoApp.xcworkspace/

	Don't try to build or run yet — it won't compile. We need to add a
  couple of _.plist_ files first.

	(Do NOT open the _.xcodeproj/_, only **use the _.xcworkspace/_** !!)

1. Go to Google API Cloud Developer Console thingie,
   [console.developers.google.com](https://console.developers.google.com).
   Note that these instructions assume you're still using the Developers
   Console without the material design ≣ at the top left. If you're on the
   newer console, things will be in slightly different places -- use the ≣
   menu to go to "API Manager" and look for the Overview page (adding APIs)
   or Credentials page (for managing credentials). We'll update these
   instructions as soon as the new console comes out of beta.

1. Create a new project (via the dropdown at the top). Enable the following
   APIs (on the left side, click '*APIs & auth*', then '*APIs*'):

    * Google Proximity Beacon API (*not* Proximity Pairing).
      * note that you have to search for this API; it's not included in the default selection list
    * Google Maps SDK for iOS.
    * Google Places API for iOS.

1. On the left of the Developers Console, click on "*APIs & auth*", and then on
   "*Credentials*". Press the "*Add Credentials*" button, then "*API key*" to
   create a Public API access key.
   1. Choose '*iOS Key*'.
   2. In the box where you specify acceptable bundle IDs, you can choose to
        either specify `com.google.sample.BeaconServiceDemoApp`, or just leave
        it blank (note, that for shipping apps, leaving it blank isn't a great
        idea).
   2. Click "*Create*".
   2. `Copy` *BeaconServiceDemoApp/APIKey.plist.sample* to
     *BeaconServiceDemoApp/APIKey.plist*  and replace
     `ENTER YOUR API KEY HERE` with this newly generated API key.
   2. This API key will now always be available on the running `AppDelegate`
      as `googleAPIKey`.

1. Go to [https://developers.google.com/identity/sign-in/ios/start-integrating](https://developers.google.com/identity/sign-in/ios/start-integrating)
   from a browser logged in to the account that created the API project you
   just created.

1. Go to the button "*Get a configuration file*" and click that.

1. For "*App Name*", Enter / select the project name you just created in API
   console.

1. For iOS BundleID, enter `com.google.sample.BeaconServiceDemoApp`. **IF YOU
   DO NOT ENTER EXACTLY THIS IT WILL NOT WORK**, it's case sensitive.

1. "*Continue to Choose and Configure Services*".

1. Enable Google SignIn (that's all).

1. "*Continue to Generate configuration Files*".

1. Download the configuration file, *GoogleService-Info.plist*.  Put it in the
   same folder as your Info.plist and APIKey.plist files.
   Make sure any other
   *GoogleService-Info.plist* files are deleted.

1. You now have to set your project's reversed client ID in Xcode:

   1. Click on the blue project "*BeaconServiceDemoApp*" at the top of the
        Project Navigator.
   1. Click on "*BeaconServiceDemoApp*" under "*Targets*" in the main part of
      Xcode.
   1. Click on "*Info*" across the top.
   1. Look for the scheme under "URL Types" that looks like:
        `com.googleusercontent.apps.234235235-fjboi3289ab89j4g89adsjfoasidfjs`
   1. Replace that scheme with the value of the `REVERSED_CLIENT_ID` from the
        GoogleService-Info.plist file
        (i.e. `com.googleusercontent.apps.2384234-35892859asdfashdoaiusdasf`)

1. XCode 7 users only: Cocoa has a new security model for URLs within your
   application, so we have to add some lines to the _Info.plist_ file to make
   sure that Google SignIn can open the URLs it needs to. You need to add the
   following to your Info.plist:

        <key>LSApplicationQueriesSchemes</key>
        <array>
           <string>com.google.sample.beaconservicedemoapp</string>
           <string>YOUR REVERSE CLIENT ID (com.googlusercontent.BLAH)</string>
        </array>

1. (Optional, but *very* cool). One of the best ways to make sure that
   everything is running properly is to run this app in the simulator. Since
   the simulator doesn't support Bluetooth scanning, we can, instead, have the
   app "see" some fake Eddystone devices when you click "*Scan*". To do this,
   you should run the following in your root *BeaconServiceDemoApp* folder:

       # php gen_fake_beacons.php

   Now when you build and run the simulator, there will be 10 beacons that
   you can play around with registering, activating, deactivating, etc, and
   be able to verify that everything is working properly before actually
   modifying real-world beacon hardware.


   Give it a whirl! Generate the fake beacons, build and run in the simulator.

1. If you see a linker error: library not found for -lPods`, You'll have to
   do the following:
   
   1. Click on `BeaconServiceDemoApp` in the Project Explorer.
   1. Click on the `BeaconServiceDemoApp` _target_ in the projects and targets
      list.
   1. Click on _Build Phases_ Across the top.
   1. Expand "Link binary with Libraries".
   1. Remove `libPods.a` by clicking on the `—` button below.

   Your app should link fine now. This appears to be some goofiness with
   CocoaPods. Hopefully it will get addressed soon.

**Phew**, we're done!
