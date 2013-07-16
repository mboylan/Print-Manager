--
--  AppDelegate.applescript
--  Print Manager
--
--  Copyright (c) 2013 Mike Boylan
--
--  Permission is hereby granted, free of charge, to any person obtaining a copy of
--  this software and associated documentation files (the "Software"), to deal in
--  the Software without restriction, including without limitation the rights to
--  use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
--  the Software, and to permit persons to whom the Software is furnished to do so,
--  subject to the following conditions:
--
--  The above copyright notice and this permission notice shall be included in all
--  copies or substantial portions of the Software.
--
--  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
--  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
--  FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
--  COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
--  IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
--  CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

script AppDelegate
	property parent : class "NSObject"
	
	-- General
	property mainWindow : missing value
	property isSchoolDotEDUAvailable : missing value
	-- For printer grouping
	--property shouldDownloadOtherPrinters : 0
	
	-- Drivers
	property driverErrors : 0
	
	-- Loading view screen
	property loadingView : missing value
	property loadingLbl : missing value
	property loadingProgressBar : missing value
	property loadingViewNextBtnEnabled : 0
	
	-- Downloading view screen
	property downloadingView : missing value
	property downloadingLbl : missing value
	property downloadingProgressBar : missing value
	property downloadingProgressCounter : 0
	property downloadingProgressMax : 100
	property downloadingETALbl : missing value
	property downloadingPercentLbl : missing value
	
	-- Installing a package screen
	property installerPkgView : missing value
	property installerViewLbl : missing value
	property installerStatusLbl : missing value
	property installerPhaseLbl : missing value
	property installerProgressBar : missing value
	property installerProgressBarCounter : 0
	property installerProgressBarMax : 100
	property largePkgInstallerMessageLbl : ""
	
	-- Printer selection screen
	property printerSelectionView : missing value
	property selectPrintersArrayController : missing value
	property selectedPrintersTableView : missing value
	property tableList : {}
	property printerNames : {}
	property printerQueueNames : {}
	property printerDrivers : {}
	property printerURLs : {}
	property printerLocations : {}
	property printerTableEnabled : true
	property printerFilterEnabled : true
	property installPrintersBtnEnabled : true
	
	-- Success screen
	property successView : missing value
	
	-- Error screen
	property errorView : missing value
	
	------------------ BEGIN APP SCRIPT ------------------------
	on beginBtnClick_(sender)
		-- Let's see if school.edu is reachable...
		-- Change school.edu here to your web server address
		-- Change the logging, too.
		try
			set scutilResult to (do shell script "/usr/sbin/scutil -r school.edu")
			if scutilResult is equal to "Reachable" or scutilResult is equal to "Reachable,Transient Connection" then
				set my isSchoolDotEDUAvailable to true
			end if
		on error theError
			log theError
			log "Unable to determine if school.edu is reachable or not. Bailing out."
		end try
		-- If it is, begin...
		if isSchoolDotEDUAvailable is true then
			set my loadingLbl to "Fetching latest driver info…"
			tell my loadingProgressBar to startAnimation_(true)
			tell mainWindow to setContentView_(loadingView)
			tell mainWindow to displayIfNeeded()
			performSelector_withObject_afterDelay_("beginBtnClickAfterDelay:", sender, 0.2)
		else
			display dialog "school.edu is unreachable. Are you sure you have an Internet connection?" buttons {"Ok"}
		end if
	end beginBtnClick_
	
	on beginBtnClickAfterDelay_(sender)
		-- Change school.edu here to the location of your web server
		if fetchLatestPlist("https://school.edu/downloads/PrintDrivers.plist") then
			processDownloadedDriversPlist()
		else
			log "Unable to download latest driver plist. Bailing out."
			loadErrorView()
		end if
	end beginBtnClickAfterDelay_
	
	on processDownloadedDriversPlist()
		do shell script "/bin/sleep 2"
		
		set totalDrivers to enumeratePlistDicts("Drivers", "/tmp/PrintDrivers.plist")
		
		repeat with i from 1 to totalDrivers
			set driverName to (do shell script "/usr/libexec/plistbuddy -c 'Print :Drivers:" & i - 1 & ":Name' /tmp/PrintDrivers.plist")
			set driverVersion to (do shell script "/usr/libexec/plistbuddy -c 'Print :Drivers:" & i - 1 & ":Version' /tmp/PrintDrivers.plist")
			set driverURL to (do shell script "/usr/libexec/plistbuddy -c 'Print :Drivers:" & i - 1 & ":URL' /tmp/PrintDrivers.plist")
			set driverMD5 to (do shell script "/usr/libexec/plistbuddy -c 'Print :Drivers:" & i - 1 & ":MD5' /tmp/PrintDrivers.plist")
			set fileToCheck to (do shell script "/usr/libexec/plistbuddy -c 'Print :Drivers:" & i - 1 & ":File' /tmp/PrintDrivers.plist")
			set versionLocation to (do shell script "/usr/libexec/plistbuddy -c 'Print :Drivers:" & i - 1 & ":Version\\ Location' /tmp/PrintDrivers.plist")
			set installerMessage to (do shell script "/usr/libexec/plistbuddy -c 'Print :Drivers:" & i - 1 & ":Optional\\ Installer\\ Message' /tmp/PrintDrivers.plist")
			set oldDelims to AppleScript's text item delimiters
			set AppleScript's text item delimiters to {"."}
			set driverType to text item -1 of driverURL
			set AppleScript's text item delimiters to oldDelims
			
			set alreadyHasLatest to checkIfExistsAndIsLatestVersion(fileToCheck, quoted form of versionLocation, driverVersion)
			
			if alreadyHasLatest is false then
				log "User does not have latest " & driverName & " installed. Attempting to download and install it..."
				attemptToDownloadAndInstallDriver(driverName, driverURL, driverType, driverMD5, installerMessage)
			else
				log "User already has the latest " & driverName & " installed."
			end if
		end repeat
		
		if my driverErrors is greater than 0 then
			log "Hit an error downloading and/or installing one or more driver packages. Bailing out."
			loadErrorView()
		else
			set my loadingLbl to "Fetching latest printer list..."
			tell mainWindow to setContentView_(loadingView)
			tell mainWindow to displayIfNeeded()
			set weHadAnError to 0
			-- Change school.edu to your web server here
			-- Commented out is how you might do printers by groups
			--if shouldDownloadOtherPrinters is 0 then
			if fetchLatestPlist("https://school.edu/downloads/Printers.plist") then
				processDownloadedPrinterList("/tmp/Printers.plist")
			else
				log "Error downloading printers list."
				set weHadAnError to 1
			end if
			--else
			--	if fetchLatestPlist("https://school.edu/downloads/Printers.plist") then
			--		processDownloadedPrinterList("/tmp/Printers.plist")
			--		if fetchLatestPlist("https://school.edu/downloads/OtherPrinters.plist") then
			--			processDownloadedPrinterList("/tmp/OtherPrinters.plist")
			--		else
			--			log "Error downloading other printers list, but successfully downloaded printers list."
			--			set weHadAnError to 1
			--		end if
			--	else
			--		log "Error downloading printers list. Skipping attempt to download other printers list."
			--		set weHadAnError to 1
			--	end if
			--end if
			if weHadAnError is not 0 then
				log "Bailing out due to an error downloading one or more printers list(s)."
				loadErrorView()
			else
				tell mainWindow to setContentView_(printerSelectionView)
				tell mainWindow to displayIfNeeded()
			end if
		end if
	end processDownloadedDriversPlist
	
	on sortListOfRecords_byKey_ascending_(recordList, theKey, theOrder)
		set anArray to current application's NSArray's arrayWithArray_(recordList)
		set aDescriptor to current application's NSSortDescriptor's sortDescriptorWithKey_ascending_selector_(theKey, theOrder, "localizedCaseInsensitiveCompare:")
		return anArray's sortedArrayUsingDescriptors_({aDescriptor})
	end sortListOfRecords_byKey_ascending_
	
	on enumeratePlistDicts(theName, thePlist)
		set x to 0
		repeat
			try
				do shell script "/usr/libexec/plistbuddy -c 'Print :" & theName & ":" & x & "' " & thePlist & ""
				set x to (x + 1)
			on error theError
				exit repeat
			end try
		end repeat
		return x
	end enumeratePlistDicts
	
	on processDownloadedPrinterList(plistPath)
		do shell script "/bin/sleep 2"
		
		set totalPrintersArrayLength to enumeratePlistDicts("Printers", plistPath)
		
		repeat with i from 1 to totalPrintersArrayLength
			set end of printerNames to (do shell script "/usr/libexec/plistbuddy -c 'Print :Printers:" & i - 1 & ":Name' " & plistPath & "")
			set end of printerQueueNames to (do shell script "/usr/libexec/plistbuddy -c 'Print :Printers:" & i - 1 & ":Queue\\ Name' " & plistPath & "")
			set end of printerLocations to (do shell script "/usr/libexec/plistbuddy -c 'Print :Printers:" & i - 1 & ":Location' " & plistPath & "")
			set end of printerDrivers to (do shell script "/usr/libexec/plistbuddy -c 'Print :Printers:" & i - 1 & ":Driver\\ Path' " & plistPath & "")
			set end of printerURLs to (do shell script "/usr/libexec/plistbuddy -c 'Print :Printers:" & i - 1 & ":URL' " & plistPath & "")
		end repeat
		
		-- Create the specially formatted list for the array controller
		set tableList to {}
		repeat with i from 1 to length of printerNames
			set end of tableList to {isSelected:false, thePrinter:(item i of printerNames) as text, theStatus:"Available to install..."}
		end repeat
		
		set sortedTableList to sortListOfRecords_byKey_ascending_(tableList, "thePrinter", true)
		
		-- Give it to the array controller
		tell my selectPrintersArrayController
			removeObjects_(arrangedObjects())
			addObjects_(sortedTableList)
		end tell
		
		tell my selectedPrintersTableView
			deselectAll_(me)
		end tell
	end processDownloadedPrinterList
	
	on fetchLatestPlist(theURL)
		set oldDelims to AppleScript's text item delimiters
		set AppleScript's text item delimiters to {"/"}
		set theFileName to text item -1 of theURL
		set AppleScript's text item delimiters to oldDelims
		----- Try and get the latest info from school.edu -----
		try
			do shell script "/usr/bin/curl -s " & theURL & " -o /tmp/" & theFileName
			log "Successfully downloaded " & theFileName & "."
			set weDidntHitAnError to true
		on error theError
			log theError
			log "Unable to download " & theFileName & " file."
			set weDidntHitAnError to false
		end try
		if weDidntHitAnError then
			return true
		else
			return false
		end if
	end fetchLatestPlist
	
	on attemptToDownloadAndInstallDriver(driverType, driverURL, driverPkgType, driverMD5, installerMessage)
		set downloadedAndVerified to downloadAndVerifyDriver(driverType, driverURL, driverPkgType, driverMD5)
		if downloadedAndVerified is false then
			set downloadTries to 1
			repeat while downloadedAndVerified is false and downloadTries is less than 3
				log "Verification of download for " & driverType & "failed. Asking user to attempt to download again."
				set buttonSelected to button returned of (display dialog "The verification of the download failed. Would you like to retry?" buttons {"Yes", "No"})
				log (buttonSelected as text)
				if buttonSelected is equal to "Yes" then
					set downloadedAndVerified to downloadAndVerifyDriver(driverType, driverURL, driverPkgType, driverMD5)
					if downloadedAndVerified is true then
						installDriverPkgFromPath(driverType, driverPkgType, driverMD5, installerMessage)
						exit repeat
					end if
					set downloadTries to downloadTries + 1
				else
					set my driverErrors to (my driverErrors) + 1
					exit repeat
				end if
				if downloadTries is 3 then
					set my driverErrors to (my driverErrors) + 1
				end if
			end repeat
		else
			installDriverPkgFromPath(driverType, driverPkgType, driverMD5, installerMessage)
		end if
	end attemptToDownloadAndInstallDriver
	
	to checkIfExistsAndIsLatestVersion(fileToCheck, plistToRead, versionToCompare)
		set isInstalled to false
		tell application "Finder" to if exists fileToCheck as POSIX file then set isInstalled to true
		if isInstalled is true then
			log "File exists - checking version"
			try
				set installedVersion to do shell script "/usr/libexec/plistbuddy -c 'Print :CFBundleShortVersionString' " & plistToRead & ""
			on error theError
				set installedVersion to do shell script "/usr/libexec/plistbuddy -c 'Print :PackageVersion' " & plistToRead & ""
			end try
			if installedVersion is greater than or equal to versionToCompare then
				log "User has latest version."
				return true
			else
				log "User does not have the latest version."
				return false
			end if
		else
			return false
		end if
	end checkIfExistsAndIsLatestVersion
	
	on downloadAndVerifyDriver(driverType, driverURL, driverPkgType, driverMD5)
		-- Begin downloading drivers
		set my downloadingProgressCounter to 0
		set my downloadingETALbl to missing value
		set my downloadingPercentLbl to missing value
		set my downloadingLbl to "Downloading " & driverType & " driver package…"
		tell mainWindow to setContentView_(downloadingView)
		tell mainWindow to displayIfNeeded()
		do shell script "/bin/sleep .5"
		try
			do shell script "/usr/bin/curl " & driverURL & " -o /tmp/" & driverMD5 & "." & driverPkgType & " 2> /tmp/" & driverMD5 & ".txt > /dev/null & "
			set weDidntHitAnError to true
		on error theError
			log "Unable to download " & driverType & " drivers"
			set weDidntHitAnError to false
		end try
		if weDidntHitAnError then
			do shell script "/bin/sleep 1"
			repeat while my downloadingProgressCounter is not "100"
				try
					set my downloadingProgressCounter to first word of paragraph -1 of (do shell script "/usr/bin/tail -1 /tmp/" & driverMD5 & ".txt")
					set my downloadingPercentLbl to (my downloadingProgressCounter as text) & "%"
				end try
				try
					set theTimeLeft to (words 15 thru 17 of paragraph -1 of (do shell script "/usr/bin/tail -1 /tmp/" & driverMD5 & ".txt") as text)
					set my downloadingETALbl to characters 1 thru ((count theTimeLeft) - 4) of theTimeLeft & ":" & characters -3 thru -4 of theTimeLeft & ":" & characters -1 thru -2 of theTimeLeft as text
				on error
					set my downloadingETALbl to "Unknown"
				end try
				tell mainWindow to displayIfNeeded()
			end repeat
			
			-- Verify the download
			set my loadingLbl to "Verifying " & driverType & " download…"
			tell mainWindow to setContentView_(loadingView)
			tell mainWindow to displayIfNeeded()
			
			-- See if it verifies
			set downloadedMD5 to (do shell script "/sbin/md5 -q /tmp/" & driverMD5 & "." & driverPkgType)
			if downloadedMD5 is equal to driverMD5 then
				return true
			else
				return false
			end if
		else
			return false
		end if
	end downloadAndVerifyDriver
	
	on installDriverPkgFromPath(driverType, driverPkgType, driverMD5, installerMessage)
		set my installerStatusLbl to missing value
		set my installerPhaseLbl to missing value
		set my installerProgressBarCounter to 0
		set my installerViewLbl to "Installing " & driverType & " drivers..."
		set my largePkgInstallerMessageLbl to installerMessage
		tell mainWindow to setContentView_(installerPkgView)
		tell mainWindow to displayIfNeeded()
		set stillInstalling to true
		try
			do shell script "/usr/sbin/installer -verboseR -pkg /tmp/" & driverMD5 & "." & driverPkgType & " -target / > /tmp/" & driverMD5 & "installprogress.txt 2>/dev/null & " with administrator privileges
			set oldDelims to AppleScript's text item delimiters
			repeat while stillInstalling is true
				set AppleScript's text item delimiters to {":"}
				set my installerPhaseLbl to text item -1 of (do shell script "/bin/cat /tmp/" & driverMD5 & "installprogress.txt | /usr/bin/egrep -v '(STATUS|: |:%)' | /usr/bin/tail -1") as text
				set my installerStatusLbl to text item -1 of (do shell script "/bin/cat /tmp/" & driverMD5 & "installprogress.txt | /usr/bin/egrep -v '(PHASE|: |:%)' | /usr/bin/tail -1") as text
				set my installerProgressBarCounter to do shell script "/bin/cat /tmp/" & driverMD5 & "installprogress.txt | /usr/bin/grep \":%\" | /usr/bin/cut -d \"%\" -f 2 | /usr/bin/tail -1"
				tell mainWindow to displayIfNeeded()
				if my installerPhaseLbl contains "The software" then
					set stillInstalling to false
				end if
			end repeat
			set AppleScript's text item delimiters to oldDelims
		on error theError
			log theError
			set my driverErrors to (my driverErrors) + 1
		end try
	end installDriverPkgFromPath
	
	-- Check to see which items of the list are selected
	on installSelectedPrintersBtnClick_(sender)
		set my printerFilterEnabled to false
		set my installPrintersBtnEnabled to false
		performSelector_withObject_afterDelay_("installSelectedPrintersBtnClickAfterDelay:", sender, 0.2)
	end installSelectedPrintersBtnClick_
	
	on installSelectedPrintersBtnClickAfterDelay_(sender)
		set totalInstallationErrors to 0
		tell selectPrintersArrayController to set theList to arrangedObjects() as list
		repeat with i from 1 to count of theList
			if isSelected of item i of theList is true then
				set listPosition to my list_position(thePrinter of item i of theList, printerNames)
				set alreadyInstalled to "1"
				try
					set alreadyInstalled to (do shell script "/usr/bin/lpstat -p " & quoted form of item listPosition of printerQueueNames & " > /dev/null 2>&1; /bin/echo $?")
				on error theError
					log theError
				end try
				if alreadyInstalled is not "0" then
					try
						do shell script "/usr/sbin/lpadmin -p " & item listPosition of printerQueueNames & " -L " & quoted form of item listPosition of printerLocations & " -D " & quoted form of item listPosition of printerNames & " -E -v " & item listPosition of printerURLs & " -P " & item listPosition of printerDrivers & " -o printer-is-shared=false"
						log "Printer " & (item listPosition of printerNames) & " successfully installed!"
						set item i of theList to {isSelected:true, thePrinter:(item listPosition of printerNames) as text, theStatus:"Installed!"}
						tell my selectPrintersArrayController
							removeObjectAtArrangedObjectIndex_(i - 1)
							insertObject_atArrangedObjectIndex_(item i of theList, i - 1)
						end tell
						scrollToVisibleAndRedraw(i - 1)
						do shell script "/bin/sleep .5"
					on error theError
						log theError
						set item i of theList to {isSelected:true, thePrinter:(item listPosition of printerNames) as text, theStatus:"Error installing!"}
						set totalInstallationErrors to totalInstallationErrors + 1
						tell my selectPrintersArrayController
							removeObjectAtArrangedObjectIndex_(i - 1)
							insertObject_atArrangedObjectIndex_(item i of theList, i - 1)
						end tell
						scrollToVisibleAndRedraw(i - 1)
						do shell script "/bin/sleep .5"
					end try
				else
					log "Printer " & (item listPosition of printerNames) & " is already installed."
					set item i of theList to {isSelected:true, thePrinter:(item listPosition of printerNames) as text, theStatus:"Already installed!"}
					tell my selectPrintersArrayController
						removeObjectAtArrangedObjectIndex_(i - 1)
						insertObject_atArrangedObjectIndex_(item i of theList, i - 1)
					end tell
					scrollToVisibleAndRedraw(i - 1)
					do shell script "/bin/sleep .5"
				end if
			end if
		end repeat
		do shell script "/bin/sleep .5"
		if totalInstallationErrors is greater than 0 then
			log "Showing error screen because one or more printers failed to install properly."
			loadErrorView()
		else
			log "All printers successfully installed!"
			tell mainWindow to setContentView_(successView)
			tell mainWindow to displayIfNeeded()
		end if
	end installSelectedPrintersBtnClickAfterDelay_
	
	on installMorePrintersBtnClick_(sender)
		set my printerFilterEnabled to true
		set my installPrintersBtnEnabled to true
		tell mainWindow to setContentView_(printerSelectionView)
		tell mainWindow to displayIfNeeded()
	end installMorePrintersBtnClick_
	
	on loadErrorView()
		tell mainWindow to setContentView_(errorView)
		tell mainWindow to displayIfNeeded()
	end loadErrorView
	
	on scrollToVisibleAndRedraw(rowIndex)
		-- Scroll the tableview to the row so you can see the staus
		tell my selectedPrintersTableView
			scrollRowToVisible_(rowIndex)
		end tell
		tell mainWindow to displayIfNeeded()
	end scrollToVisibleAndRedraw
	
	on list_position(this_item, this_list)
		repeat with i from 1 to the count of this_list
			if item i of this_list is this_item then return i
		end repeat
	end list_position
	
	-- Both exit buttons linked to the same handler
	on exitBtnClick_(sender)
		tell current application's NSApp to terminate_(me)
	end exitBtnClick_
	
	-- Close when clicking the red x since it's a one window app
	on applicationShouldTerminateAfterLastWindowClosed_(aNotification)
		return true
	end applicationShouldTerminateAfterLastWindowClosed_
	
	on applicationWillFinishLaunching_(aNotification)
		-- Insert code here to initialize your application before any files are 
		tell loadingProgressBar to setUsesThreadedAnimation_(true)
		tell downloadingProgressBar to setUsesThreadedAnimation_(true)
		tell installerProgressBar to setUsesThreadedAnimation_(true)
	end applicationWillFinishLaunching_
	
	on applicationShouldTerminate_(sender)
		-- Insert code here to do any housekeeping before your application quits 
		return current application's NSTerminateNow
	end applicationShouldTerminate_
	
end script