Write-Output "`n*********************************************************"
Write-Output "                  WSL2 HOST - CONFIGURING									 "
Write-Output "                 DON'T CLOSE THE WINDOW!!!								 "
Write-Output "*********************************************************`n"

$getDate = (Get-Date -Format d).replace("/","-");
$getTime = (Get-Date -Format T);
$timeStamp = (Get-Date -Format d).replace("/","_");

$configFolderPath = "C:\Users\$env:USERNAME\AppData\Local\wsl2_host_config";
$configFilePath = "$configFolderPath\$timeStamp.config.log";

if (Test-Path "$configFolderPath\*.log") {
	$currentPathWin = (Get-Content "$configFolderPath\*.log")[-3]
} else {
	$currentPathWin = (Get-Location).Path;
}

$diskDrive = $configFolderPath.Substring(0,1);
$configFolderPathWsl = $configFolderPath.Replace("$($diskDrive):\","/mnt/$($diskDrive.ToLower())/").Replace("\","/");
# Escape spaces in the path. There may be spaces in user names unfortunately.
$configFolderPathWsl = $configFolderPathWsl.Replace(" ","\ ");
$outPutConfigPath = [PSCustomObject]@{
	SCRIPT_PATH = $currentPathWin;
};

if (!(Test-Path $configFolderPath)) {
	Write-Output "--> Creating config folder...`n"
	mkdir $configFolderPath | Out-Null;
}

Remove-Item "$configFolderPath\*.config.log" -EV Err -EA SilentlyContinue;

#[REG KEY ON WINDOWS]
$registryPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\wsl2host.exe';

if (!(Test-Path $registryPath)) {
	Write-Output "--> 'wsl2host' key registering on Windows...`n";	
	New-Item -Path $registryPath -Value "$currentPathWin\start.bat" -Force | Out-Null;
	New-ItemProperty -Path $registryPath -Name 'Path' -Value $currentPathWin -PropertyType string -Force | Out-Null;	
} else {
	Write-Output "--> 'wsl2host' key already exist...`n";
}

#[SHEDULE TASK ON WINDOWS]
$foundTask = Get-ScheduledTask -TaskName 'WSL2HOST' -EA SilentlyContinue;

if (!$foundTask) {
	Write-Output "--> Schedule task creating...`n";
	$taskAction = New-ScheduledTaskAction -Execute "Powershell.exe" -Argument "-ExecutionPolicy Bypass $currentPathWin\wsl_hosts.ps1";
	$taskTrigger = New-ScheduledTaskTrigger -AtLogon;
	$taskPrincipal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -RunLevel Highest;	
	$task = New-ScheduledTask -Action $taskAction -Principal $taskPrincipal -Trigger $taskTrigger;
	Register-ScheduledTask -TaskName "WSL2HOST" -InputObject $task | Out-Null;	
} else {
	Write-Output "--> Schedule task already exist...`n";
}

#[INSERT env REACT_NATIVE_PACKAGER_HOSTNAME IN .bashrc AND .zshrc]
$foundEnv = @(
	[PSCustomObject]@{
		value = bash.exe -c "grep 'REACT_NATIVE_PACKAGER_HOSTNAME' ~/.bashrc 2> /dev/null";
		path = "~/.bashrc";
	};	
	[PSCustomObject]@{
		value = bash.exe -c "grep 'REACT_NATIVE_PACKAGER_HOSTNAME' ~/.zshrc 2> /dev/null";
		path = "~/.zshrc";
	};
);

foreach ( $item in $foundEnv ) {
	$path = $item.path;		
	if ([string]::IsNullOrEmpty($item.value) -and ![string]::IsNullOrEmpty((bash.exe -c "ls -l $path 2> /dev/null"))) {		
		if (![string]::IsNullOrEmpty((bash.exe -c "ls -l $path | grep 'root'"))) {
			$userWsl = bash.exe -c "whoami";
			bash.exe -c "sudo chown $userWsl`:$userWsl $path"
		}
		$keepAddress = "`n# Set env for EXPO `nlocalAddress=``awk 'NR==4 {print `$3}' $configFolderPathWsl/*.config.log | sed 's/\\r//g'`` `nexport REACT_NATIVE_PACKAGER_HOSTNAME=`$localAddress` `n# End";
		$keepAddress | out-file -encoding "ASCII" "$configFolderPath\temp.txt";
		bash.exe -c "cat $configFolderPathWsl/temp.txt >> $path ";
		Remove-Item "$configFolderPath\temp.txt" -EV Err -EA SilentlyContinue;
	}
}

#[STATIC/DHCP IP - WINDOWS]
$localAddress = @();

foreach ($ipaddress in (Get-NetAdapter | 
												Where-Object InterfaceDescription -NotMatch "Hyper-V" | 
												Where-Object InterfaceDescription -NotMatch "VirtualBox" | 
												Where-Object InterfaceDescription -NotMatch "Virtual" | 
												Where-Object InterfaceDescription -NotMatch "VMware" | 
												Where-Object InterfaceDescription -NotMatch "VMnet" | 
												Where-Object Status -eq "Up" | Get-NetIPAddress |
												Where-Object AddressFamily -eq IPv4 | Sort-Object InterfaceIndex)) { 
		$localAddress += $ipaddress.IPAddress;
		$interfaceName = $ipaddress.InterfaceAlias;
}

$localAddress = $localAddress[0];

if (![string]::IsNullOrEmpty($localAddress)) {	
	$outPutInterface = @([PSCustomObject]@{
		INTERFACE = $interfaceName;
		LOCAL_ADDRESS = $localAddress;
		STATUS = "OK";
		DATE = $getDate;
		TIME = $getTime
	});

	} else {
	Write-Output "--> The Script Exited, the IP address of Windows cannot be found";
	exit;
}

#[REMOTE IP - WSL2]
$netTools = bash.exe -c "dpkg -l | grep 'net-tools'";

if ([string]::IsNullOrEmpty($netTools)) {
    Write-Output "--> The net-tools package is required to proceed, continue to install ...";
    bash.exe -c "sudo apt-get install net-tools -y";
}

$remoteAddress = bash.exe -c "ifconfig eth0 | grep 'inet '"
$foundRemoteAddress = $remoteAddress -match "\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}";

if ($foundRemoteAddress) {
	$remoteAddress = $matches[0];
} else {
	Write-Output "--> The Script Exited, the ip address of WSL2 cannot be found";	
	exit;
}

#[FIREWALL]
$firewall = @(
	[PSCustomObject]@{
		type="TCP"; 
		name="WSL2 Firewall Unlock TCP"; 
		ports=@(19000,19001,19002,19003,19004,19005)}
	[PSCustomObject]@{
		type="UDP"; 
		name="WSL2 Firewall Unlock UDP"; 
		ports=@(53)}
);

$portsTCP = $firewall[0].ports -join ",";
$portsUDP = $firewall[1].ports -join "," ;

#Adding Exception Rules for inbound and outbound Rules
foreach ( $item in $firewall) {
	$nameFirewall = $item.name;
	$typeFirewall = $item.type;
	
	if ((!(Get-NetFireWallRule -DisplayName $nameFirewall -EV Err -EA SilentlyContinue)) -and ($typeFirewall -eq "TCP")) {      
		Invoke-Expression "New-NetFireWallRule -DisplayName '$nameFirewall' -Direction Outbound -LocalPort $portsTCP -Action Allow -Protocol TCP";
		Invoke-Expression "New-NetFireWallRule -DisplayName '$nameFirewall' -Direction Inbound -LocalPort $portsTCP -Action Allow -Protocol TCP";    
		$outPutFirewall += @([PSCustomObject]@{
			FIREWALL_NAME = $nameFirewall;
			STATUS = "CREATED";
			DATE = $getDate;
			TIME = $getTime
		});

	} elseif ((!(Get-NetFireWallRule -DisplayName $nameFirewall -EV Err -EA SilentlyContinue)) -and ($typeFirewall -eq "UDP")) {    
		Invoke-Expression "New-NetFireWallRule -DisplayName '$nameFirewall' -Direction Outbound -LocalPort $portsUDP -Action Allow -Protocol UDP";
		Invoke-Expression "New-NetFireWallRule -DisplayName '$nameFirewall' -Direction Inbound -LocalPort $portsUDP -Action Allow -Protocol UDP";
		$outPutFirewall += @([PSCustomObject]@{
			FIREWALL_NAME = $nameFirewall;
			STATUS = "CREATED";
			DATE = $getDate;
			TIME = $getTime
		});
		
	} else {
		$outPutFirewall += @([PSCustomObject]@{
			FIREWALL_NAME = $nameFirewall;
			STATUS = "EXIST";
			DATE = $getDate;
			TIME = $getTime
		});		
	}
}

#[REDIRECTING PORTS]
foreach ( $port in $firewall[0].ports) {
	Invoke-Expression "netsh interface portproxy delete v4tov4 listenport=$port listenaddress=$localAddress" | Out-Null;
	Invoke-Expression "netsh interface portproxy add v4tov4 listenport=$port listenaddress=$localAddress connectport=$port connectaddress=$remoteAddress" | Out-Null;	
	$outPutPorts += @([PSCustomObject]@{
		PORT = $port;
		LOCAL_ADDRESS = $localAddress;
		REMOTE_ADDRESS = $remoteAddress;
		DATE = $getDate;
		TIME = $getTime
	});
}

#[LOG]
$outPutInterface | Format-Table -Property STATUS,INTERFACE,LOCAL_ADDRESS,DATE,TIME -AutoSize | Out-File -Encoding "ASCII" $configFilePath -Append;
$outPutFirewall | Format-Table -Property STATUS,FIREWALL_NAME,DATE,TIME -AutoSize | Out-File -Encoding "ASCII" $configFilePath -Append;
$outPutPorts | Format-Table -Property PORT,LOCAL_ADDRESS,REMOTE_ADDRESS,DATE,TIME -AutoSize | Out-File -Encoding "ASCII" $configFilePath -Append;
$outPutConfigPath | Format-Table -Property SCRIPT_PATH -AutoSize | Out-File -Encoding "UTF8" $configFilePath -Append;

Write-Output $outPutInterface | Format-Table -Property STATUS,INTERFACE,LOCAL_ADDRESS,DATE,TIME -AutoSize;
Write-Output $outPutFirewall | Format-Table -Property STATUS,FIREWALL_NAME,DATE,TIME -AutoSize;
Write-Output $outPutPorts | Format-Table -Property PORT,LOCAL_ADDRESS,REMOTE_ADDRESS,DATE,TIME -AutoSize;
Write-Output $outPutConfigPath | Format-Table -Property SCRIPT_PATH -AutoSize;
