# Print Manager
Print Manager is an OS X client application developed to assist end users in the installation of print drivers and enterprise networked printers. Both the print drivers and the printer listing are managed by an administrator and provided to the application via two (or more) plists that reside on a company web server. The first plist contains a list of print drivers required to be installed and the second contains a listing of available printers. Additional plists can be included to separate functional groupings of printers (this requires minor user interface and code changes). Print Manager includes the following additional features:

1. Sparkle updating (using either the old signing method or by checking the Apple Developer ID code signature)
2. Network availability checking before attempting to download and install anything
3. Verification of downloaded print drivers via md5 checksums, and prompts to attempt redownloads of packages that fail verification
4. Retina display support
5. OS X version compatibility of 10.6.8-10.8 

## Required Customizations
Find "school.edu" in the AppDelegate.applescript file and follow the instructions in the comments for making required edits. Line numbers aren't listed here as they're subject to change with code updates. Most changes involve simply pointing the application to correct URLs.

The text on both the welcome screen and the error screen needs changed to something appropriate for your organization.

Your company web server must also host at least two plists. The first is titled `PrintDrivers.plist` and the second is titled `Printers.plist`. Example plists are provided in the Example Plists folder. The `PrintDrivers.plist` contains an array of dicts like the following:
<pre><code>    &lt;dict&gt;
        &lt;key&gt;Name&lt;/key&gt;
        &lt;string&gt;Xerox&lt;/string&gt;
        &lt;key&gt;File&lt;/key&gt;
        &lt;string&gt;/Library/Printers/Xerox/PDEs/XeroxFeatures.plugin&lt;/string&gt;
        &lt;key&gt;Version&lt;/key&gt;
        &lt;string&gt;2.94.3&lt;/string&gt;
        &lt;key&gt;Version Location&lt;/key&gt;
        &lt;string&gt;/Library/Printers/Xerox/PDEs/XeroxFeatures.plugin/Contents/Info.plist&lt;/string&gt;
        &lt;key&gt;URL&lt;/key&gt;
        &lt;string&gt;http://school.edu/print-drivers/XeroxPrintDriver-2.94.3.pkg&lt;/string&gt;
        &lt;key&gt;MD5&lt;/key&gt;
        &lt;string&gt;f76177fee5fd07e3fc8e9bbf8a51ffff&lt;/string&gt;
        &lt;key&gt;Optional Installer Message&lt;/key&gt;
        &lt;string&gt;&lt;/string&gt;
    &lt;/dict&gt;
</code></pre>
Descriptions of the keys are as follows:

1. Name - This is used on the downloading and installation screens of the application. The labels have text of "Downloading xxxxxx driver package..." and "Installing xxxxxx drivers...". The value of the Name key is used to fill in xxxxxx.
2. File - This is any file that is installed by the driver package. The application checks for this file before checking for an installed version.
3. Version - This is used in combination with the next key, Version Location. The Version Location is checked for either a CFBundleShortVersionString key or a PackageVersion key. The value of the Version key is checked against the installed version. If it's less than the Version key, it is assumed the end user doesn't have the latest version of the print driver(s).
4. Version Location - This is where the application should look for the installed version of the print driver package.
5. URL - This is where the application can download the print driver package from.
6. MD5 - This is the checksum that the application should verify against when the driver package has finished downloading.
7. Optional Installer Message - This text is used to populate a label underneath the installation progress bar on the installation view of the application. This is useful for messages like "This install may take several minutes. Please be patient." for lengthy driver installations.

The `Printers.plist` file contains an array of dicts like the following:
<pre><code>    &lt;dict&gt;
        &lt;key&gt;Name&lt;/key&gt;
        &lt;string&gt;Printer 1&lt;/string&gt;
        &lt;key&gt;Queue Name&lt;/key&gt;
        &lt;string&gt;Printer1&lt;/string&gt;
        &lt;key&gt;Location&lt;/key&gt;
        &lt;string&gt;The interwebs&lt;/string&gt;
        &lt;key&gt;Driver Path&lt;/key&gt;
        &lt;string&gt;/Library/Printers/PPDs/Contents/Resources/HP\ LaserJet\ 4050\ Series.gz&lt;/string&gt;
        &lt;key&gt;URL&lt;/key&gt;
        &lt;string&gt;url://printserver.school.edu/Printer1&lt;/string&gt;
    &lt;/dict&gt;
</code></pre>

Descriptions of the keys are as follows:

1. Name - This is used in the table view shown to the end user. This is the user friendly name of the printer.
2. Queue Name - This is the CUPS queue name.
3. Location - This is the location of the printer, as displayed to the end user in System Preferences.
4. Driver Path - This is the location on the filesystem of the print driver for the printer.
5. URL - This is the URL of the printer. Depending on your environment, this might be "smb://" or "popup://" or even "lpd://"

Print Manager loops through both plists each time it runs, so requiring additional print drivers and/or updating the list of available printers is as simple as editing one or both of the plists.

## Optional Customizations
If you'd like to separate printers by functional groups, the easiest way to do this is to add menu bar items under "View" for each group. Each menu bar item would be linked to a property that holds a true or false value. Before populating the table listing of available printers, the application would check the values of these properties and only show printers for groups that are checked. Each group would have its own plist on the company web server.

A background image that includes a company logo should be added to the different views via modifying the existing NSImageViews. There are two Photoshop files included in the Background Images folder of the project. One is for regular displays and the other is for retina displays.

An application icon should be added.

## Sparkle Updating
The version of sparkle included with the project has the ability to verify application updates based on the Apple Developer ID code signature, or by signing updates with a key pair of which the public key [is included inside the application bundle](https://github.com/andymatuschak/Sparkle/wiki#3-segue-for-security-concerns). See "[Publishing an Update](https://github.com/andymatuschak/Sparkle/wiki/publishing-an-update)" on Andy Matuschak's GitHub for more information about publishing updates via Sparkle. The application, at a minimum, needs the `SUFeedURL` key of its Info.plist file modified to reflect the location of your appcast.

## Security Concerns
Because the application loops through every driver listed in the `PrintDrivers.plist` file and downloads and installs each one, it's important that at least this file be served over https. If a certificate verification problem occurs during the TLS negotiation, curl will exit with an error which will cause the application to present the error view (and not download and install the drivers). 

Downloaded drivers are verified against the MD5 checksums listed in the `PrintDrivers.plist` file. If you can ensure the integrity of this file at the time of download, you can be reasonably certain that the MD5 checksums that the downloads are being verified against are valid.

Sparkle updates are signed using either a custom private key or the private key linked to an Apple Developer ID Application certificate. They're verified using either a public key embedded inside the application or by verifying the Apple Developer ID code signature. More specifically, Sparkle will verify that the new version's author matches the old version's author. If you choose to use the custom keypair, because you already have the public key embedded in the application at your disposal, you could be clever and possibly sign your plist(s) and verify them using that key as well.

## Known Limitations
* **All** required drivers in the `PrintDrivers.plist` file are downloaded and installed before the printer listing is shown to the end user.
* The options portion of the `lpadmin` command is currently hardcoded as `-o printer-is-shared=false`. With minimal code changes and an extra key added to the `Printers.plist` file, this options string could become dynamic.
* If an end user clicks away from the application during a driver download or install, clicking the Dock icon for the application will not bring the window back to the forefront until the download or installation has finished. Using Mission Control or Expose can bring the window back. This is due to the locking nature of AppleScript Objective-C, but could be improved if code improvements were made to use NSTasks instead of "do shell script"s.

## License
This software is released under the MIT license.

Copyright (c) 2013 Mike Boylan

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.