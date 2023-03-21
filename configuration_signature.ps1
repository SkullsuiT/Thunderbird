Import-Module .\ThunderbirdConfEditor.psm1

# Create or update signature in AppData\Roaming\Signature
$srcSignaturePath = "\\ac-brt-fsncy1\Signatures\"
$dstSignaturePath = $env:AppData + "\Signature"

if(Test-Path -Path $srcSignaturePath){
	if(-Not (Test-Path -Path $dstSignaturePath)){
		New-Item -ItemType "directory" -Path $dstSignaturePath | out-null
	}

	Get-ChildItem $srcSignaturePath | Copy-Item -Destination $dstSignaturePath -Force
}

# Updating Thunderbird conf

# Retrieving every thunderbird profile
$profiles = TBGetProfiles

foreach($profile in $profiles){
	
	# Retrieving Thunderbird profile conf (prefs.js' content)
	$conf = TBGetConfig $profile
	
	# Settings to set in conf
	$mailSettings = @{"sig_file" = $dstSignaturePath + "\" + $env:USERNAME + ".htm";
				  "sig_file-rel" = "[ProfD]../../../" + "Signature/" + $env:USERNAME + ".htm";
				  "attach_signature" = "true";
				  "sig_on_fwd" = "true";
				  "organization" = "Ministère de l'Education Nationale";}
				  
	$globalSettings = @{"network.proxy.type" = 4;
						"network.proxy.enable_wpad_over_dhcp" = "false";}
				  
	# Retrieving only mailAccounts conf to filter only non functionnal mail account
	$mailAccounts = TBGetMailAccountSettings $conf
	# Retrieving id for eachj mailAccount in profile's conf
	$ids = @()
	foreach($mailAccount in $mailAccounts.GetEnumerator()){
		if($mailAccount.value.useremail -like "`"*@ac-nancy-metz.fr`""){
			# Exception for mail account with functionnal email
			if($mailAccount.value.useremail -like "`"ce.*@ac-nancy-metz.fr`""){
				continue
			}else{
				# Storing id found
				$ids += @($mailAccount.key)
			}
		}
	}

	# Storing current conf to compare later
	$newConf = $conf
	
	# Applying settings for each mail account
	foreach($id in $ids){
		$newConf = TBSetMailAccountSettings $newConf $id $mailSettings
	}
	
	$newConf = TBSetGlobalSettings $newConf $globalSettings

	# Comparing old conf with newConf to see if there are any modification to save
	if("$newConf" -ne "$conf"){
		TBSaveConfig $profile $newConf
	}
}

Remove-Module ThunderbirdConfEditor

exit 0