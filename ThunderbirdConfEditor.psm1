# Get profile folders
function TBGetProfiles{
	param(
		[string]$profilesFolder = "$env:APPDATA" + "/Thunderbird/profiles"
	)

	# return every profile path for every profile found in Thunderbird profiles directory
	return (Get-ChildItem -Path $profilesFolder -Attributes Directory | ForEach-Object{ $_.FullName})
}

# Get prefs.js config content
function TBGetConfig{
	param(
		[Parameter(Mandatory=$true)]
		[string]$profilePath
	)
	
	# Verify that profilePath exists
	if(Test-Path $profilePath){
		# Check if prefs.js exists
		$prefsJS = $profilePath + "/prefs.js"
		if((Test-Path $prefsJS)){
			# Return content of prefs.js
			return (Get-Content -Path $prefsJS)
		}
	}
}

function TBRevertBackup{
	param(
		[string]$profilePath
	)
	# Searching for old backups
	$nums = Get-ChildItem -Path $profilePath | Where-Object Name -Like "prefs-*.js" | ForEach-Object {$_.Name.Split("-")[1].Split(".")[0]}
	if($nums.length -ne 0){
		$numlist = @()
		
		# getting backups number
		foreach($num in $nums){
			$numlist += [int]$num
		}
		
		# getting last backup number
		$lastbackup = $numlist | Sort-Object | Select-Object -Last 1
	}else{
		# no backup found
		Write-Host "No backup found."
	}
	Move-Item "$profilePath\prefs-$lastbackup.js" "$profilePath\prefs.js" -Force
}

# Get prefs.js config content
function TBSaveConfig{
	param(
		[Parameter(Mandatory=$true)]
		[string]$profilePath,
		[Parameter(Mandatory=$true)]
		[array]$configuration
	)
	
	# Verify that profilePath exists
	if(Test-Path $profilePath){
		# Check if prefs.js exists
		$prefsJS = $profilePath + "/prefs.js"
		if((Test-Path $prefsJS)){
			TBCreateConfigBackup $profilePath
		}
		Set-Content $configuration -Path $prefsJS
	}
}

# Create a backup of prefs.js with incrementing number
function TBCreateConfigBackup{
	param(
		[Parameter(Mandatory=$true)]
		[string]$profilePath
	)
	
	# Searching for old backups
	$nums = Get-ChildItem -Path $profilePath | Where-Object Name -Like "prefs-*.js" | ForEach-Object {$_.Name.Split("-")[1].Split(".")[0]}
	if($nums.length -ne 0){
		$numlist = @()
		
		# getting backups number
		foreach($num in $nums){
			$numlist += [int]$num
		}
		
		# getting last backup number
		$lastbackup = $numlist | Sort-Object | Select-Object -Last 1
		$lastbackup++
	}else{
		# no backup found
		$lastbackup = 1
	}
	
	$backupSource = $profilePath + "/prefs.js"
	$backupDestination = $profilePath + "/prefs-" + $lastbackup + ".js"
	
	# Creating new backup
	Copy-Item -Path $backupSource -Destination $backupDestination
}

# Retrieve every mail account settings for every account
# or only one with the optional "id" parameter
function TBGetMailAccountSettings{
	param(
		[Parameter(Mandatory=$true)]
		[array]$configuration,
		$id
	)
	
	# Pattern based on id set or every id
	if($id -ne $null){
		$searchPattern = "^user_pref\(`"mail\.identity\.id"+$id+"\."
	}else{
		$searchPattern = "^user_pref\(`"mail\.identity\.id[0-9]+\."
	}
	
	$lines = $configuration | Select-String $searchPattern | ForEach-Object{ $_.Line }
	
	$mailAccounts = [ordered]@{}
	
	foreach($line in $lines){
		# This allow us to used $matches to get account id, parameter name and parameter value
		if($line -match "^user_pref\(`"mail\.identity\.id([0-9]+)\.([^`"]+)`", ([^\)]+)\);"){
			$mailAccount = @{$matches[2] = $matches[3]}
		}
		# We add every account to a hashtable that will be returned
		$mailAccounts[$matches[1]] += $mailAccount
	}

	return $mailAccounts
}

# Update mail account setting in prefs.js
function TBSetMailAccountSettings{
	param(
		[Parameter(Mandatory=$true)]
		[array]$configuration,
		[Parameter(Mandatory=$true)]
		[string]$id,
		[Parameter(Mandatory=$true)]
		[hashtable]$settings
	)
	
	foreach($setting in $settings.getEnumerator()){
		$parameterName = $setting.key
		
		# Create search pattern with id and parameterName
		$searchPattern = "user_pref(`"mail.identity.id" + $id +"." + $parameterName + "`""
		# Search for matching line in conf
		$lineInConf = $configuration | Select-String $searchPattern -SimpleMatch | ForEach-Object{ $_.Line }
		
		# format new value based on type of value (boolean, int, string)
		if((($setting.value -ne "false") -and ($setting.value -ne "true")) -and ($setting.value -is [string])){
			# add "" for strings only
			$parameterValue = "`""+$setting.value+"`""
		}else{
			$parameterValue = $setting.value
		}
		
		# Create line to set in conf with new value
		$lineToSet = "user_pref(`"mail.identity.id" + $id + "." + $parameterName + "`", " + $parameterValue + ");"
		
		# Check if the line already exist in the conf with the same value
		# and replace it if it does and add it if it does not exist
		if($lineInConf -ne $null){	
			if($lineInConf -ne $lineToSet){
				$configuration = $configuration.replace($lineInConf, $lineToSet)
			}
		}else{
			$configuration += $lineToSet
		}
	}
	# return new conf
	return $configuration
}

function TBSetGlobalSettings{
	param(
		[Parameter(Mandatory=$true)]
		[array]$configuration,
		[Parameter(Mandatory=$true)]
		[hashtable]$settings
	)
	foreach($setting in $settings.getEnumerator()){
		$parameterName = $setting.key
		
		# Create search pattern with id and parameterName
		$searchPattern = "user_pref(`"" + $parameterName + "`""
		# Search for matching line in conf
		$lineInConf = $configuration | Select-String $searchPattern -SimpleMatch | ForEach-Object{ $_.Line }
		
		# format new value based on type of value (boolean, int, string)
		if((($setting.value -ne "false") -and ($setting.value -ne "true")) -and ($setting.value -is [string])){
			# add "" for strings only
			$parameterValue = "`""+$setting.value+"`""
		}else{
			$parameterValue = $setting.value
		}
		
		# Create line to set in conf with new value
		$lineToSet = "user_pref(`"" + $parameterName + "`", " + $parameterValue + ");"
		
		# Check if the line already exist in the conf with the same value
		# and replace it if it does and add it if it does not exist
		if($lineInConf -ne $null){	
			if($lineInConf -ne $lineToSet){
				$configuration = $configuration.replace($lineInConf, $lineToSet)
			}
		}else{
			$configuration += $lineToSet
		}
	}
	return $configuration
}

# Delete mail account setting in prefs.js
function TBDeleteMailAccountSettings{
	param(
		[Parameter(Mandatory=$true)]
		[array]$configuration,
		[Parameter(Mandatory=$true)]
		[string]$id,
		[Parameter(Mandatory=$true)]
		[array]$settings
	)
	
	foreach($setting in $settings.getEnumerator()){
		$parameterName = $setting
		
		# Create search pattern with id and parameterName
		$searchPattern = "user_pref(`"mail.identity.id" + $id +"." + $parameterName + "`""
		# Search for not matching line in conf
		$configuration = $configuration | Select-String $searchPattern -NotMatch -SimpleMatch | ForEach-Object{ $_.Line }
	}
	# return new conf
	return $configuration
}

# Delete setting in prefs.js
function TBDeleteGlobalSettings{
	param(
		[Parameter(Mandatory=$true)]
		[array]$configuration,
		[Parameter(Mandatory=$true)]
		[array]$settings
	)
	
	foreach($setting in $settings.getEnumerator()){
		$parameterName = $setting
		$setting
		
		# Create search pattern with id and parameterName
		$searchPattern = "user_pref(`"" + $parameterName + "`""
		# Search for not matching line in conf
		$configuration = $configuration | Select-String $searchPattern -NotMatch -SimpleMatch | ForEach-Object{ $_.Line }
	}
	# return new conf
	return $configuration
}
