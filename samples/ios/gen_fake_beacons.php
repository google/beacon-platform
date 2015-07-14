<?php
/**
 * This script generates fake beacons for use in the registration app. This way
 * you can play around with registering beacons and the like without actually
 * affecting any real hardware devices. Basically, this file just adds some 
 * entries to the list of scanned beacons in FirstViewController.m.
 */
function gen_uuid() {
    return sprintf( '%04x%04x%04x%04x%04x%04x%04x%04x',
        // 32 bits for "time_low"
        mt_rand( 0, 0xffff ), mt_rand( 0, 0xffff ),

        // 16 bits for "time_mid"
        mt_rand( 0, 0xffff ),

        // 16 bits for "time_hi_and_version",
        // four most significant bits holds version number 4
        mt_rand( 0, 0x0fff ) | 0x4000,

        // 16 bits, 8 bits for "clk_seq_hi_res",
        // 8 bits for "clk_seq_low",
        // two most significant bits holds zero and one for variant DCE1.1
        mt_rand( 0, 0x3fff ) | 0x8000,

        // 48 bits for "node"
        mt_rand( 0, 0xffff ), mt_rand( 0, 0xffff ), mt_rand( 0, 0xffff )
    );
}


/**
 * Generate the fake beacon IDs
 */
$new_uuids = array();
for ($i = 0; $i < 10; $i++) {
    $new_uuids[] = "  [_foundBeacons addObject:[ESSBeaconInfo testBeaconFromBeaconIDString:@\"" . gen_uuid() . "\"]];" . "\n";
}

/**
 * Open the FirstViewController.m file for reading.
 */
$src = file("./BeaconServiceDemoApp/FirstViewController.m");

/**
 * Create temp output file.
 */
$f = fopen("./BeaconServiceDemoApp/FirstViewController.m.new", 'w');

/**
 * Look for the fake beacon IFDEF and then insert the faked beacon ids after
 * we find it.
 */
$ifdef = "#ifdef SHOW_SOME_FAKE_BEACONIDS_FOR_TESTING";

foreach ($src as $line) {
    fwrite($f, $line);
    if (strpos($line, $ifdef) === 0) {
        // now write out our new uuids!!
        foreach ($new_uuids as $new_uuid) {
            fwrite($f, $new_uuid);
        }
    }
}


fclose($f);
rename("./BeaconServiceDemoApp/FirstViewController.m",
       "./BeaconServiceDemoApp/FirstViewController.m.old");
rename("./BeaconServiceDemoApp/FirstViewController.m.new",
       "./BeaconServiceDemoApp/FirstViewController.m");
echo "Done, thanks for playing!\n";
