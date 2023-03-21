Import-Module .\ThunderbirdConfEditor.psm1

# Retrieving every thunderbird profile
$profiles = TBGetProfiles

foreach($profile in $profiles){
	# Retrieving Thunderbird profile conf (prefs.js' content)
	$conf = TBGetConfig $profile
	
	# Settings to set in conf
	$settings = @{"network.proxy.enable_wpad_over_dhcp" = "false";
				  "network.proxy.type" = 4;}
	
	# Storing current conf to compare later
	$newConf = $conf
	
	$newConf = TBSetGlobalSettings $newConf $settings
	
	if("$newConf" -ne "$conf"){
		Get-Process | Where-Object Name -like 'Thunderbird' | Stop-Process
		TBSaveConfig $profile $newConf
	}
}
