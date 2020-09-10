$currentPathWin = (Get-Location).Path;
$diskDrive = $currentPathWin.Substring(0,1);
$currentPathWsl = $currentPathWin.Replace("$($diskDrive):\","/mnt/$($diskDrive.ToLower())/").Replace("\","/");
$getDate = (Get-Date -Format d).replace("/","-");
$getTime = (Get-Date -Format T);
$outPutFirewall = @();
$outFileLog = @();

#[GET THE INTERFACE NAME]
$interfaceName = @();
$interface = Invoke-Expression "netsh interface ipv4 show config | Select-String '`"'";
$interface = "$interface".split('"');

$i = 0;
foreach ($name in $interface) { 
	if ($i%2 -eq 1 -and 
			!$name.contains("vEthernet") -and 
			!$name.contains("Loopback")) {		
		$interfaceName += $name;
	} 
	$i += 1;
}

#[REG KEY ON WINDOWS]
$foundReg = Invoke-Expression "REG QUERY 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\wsl2host.exe' | findstr 'wsl2host.exe'";

if (!$foundReg) {
	Write-Output "'wsl2host' key registering on Windows...`n";
	Invoke-Expression "REG ADD 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\wsl2host.exe' /d '$currentPathWin\start.bat'" | Out-Null;
	Invoke-Expression "REG ADD 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\wsl2host.exe' /v 'Path' /d '$currentPathWin'" | Out-Null;
} else {
	Write-Output "'wsl2host' key already exist...`n";
}

#[SHEDULE TASK ON WINDOWS]
$foundTask = Invoke-Expression "SCHTASKS /QUERY /TN 'WSL2HOST' | findstr 'WSL'";

if (!$foundTask) {
	Write-Output "Schedule task creating...`n";
	Invoke-Expression "SCHTASKS /CREATE /TN 'WSL2HOST' /SC ONLOGON /TR 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy Bypass $currentPathWin\wsl_hosts.ps1'" | Out-Null;
} else {
	Write-Output "Schedule task already exist...";
}

#[INSERT env REACT_NATIVE_PACKAGER_HOSTNAME IN .bashrc AND .zshrc]
$foundEnv = @(
	[pscustomobject]@{
		value = bash.exe -c "grep 'REACT_NATIVE_PACKAGER_HOSTNAME' ~/.bashrc";
		path = "~/.bashrc";
	};	
	[pscustomobject]@{
		value = bash.exe -c "grep 'REACT_NATIVE_PACKAGER_HOSTNAME' ~/.zshrc";
		path = "~/.zshrc";
	};
);

foreach ( $item in $foundEnv ) {
	$path = $item.path;		
	if ([string]::IsNullOrEmpty($item.value)) {		
		if (![string]::IsNullOrEmpty((bash.exe -c "ls -l $path | grep 'root'"))) {
			$userWsl = bash.exe -c "whoami";
			bash.exe -c "sudo chown $userWsl`:$userWsl $path"
		}
		$keepAddress = "`n# Set env for EXPO `nlocalAddress=``awk 'NR==4 {print `$3}' $currentPathWsl/*.log | sed 's/\\r//g'`` `nexport REACT_NATIVE_PACKAGER_HOSTNAME=`$localAddress` `n# End";
		$keepAddress | out-file -encoding "ASCII" "$currentPathWin\temp.txt";
		bash.exe -c "cat $currentPathWsl/temp.txt >> $path ";
		Remove-Item "$currentPathWin\temp.txt" -EV Err -EA SilentlyContinue;
	}
}

#[STATIC/DHCP IP - WINDOWS]
foreach ( $tempAddress in $interfaceName ) {
	$localAddress = Invoke-Expression "netsh interface ipv4 show ipaddresses $tempAddress normal | Select-String 'infinite'";

	if (![string]::IsNullOrEmpty($localAddress)) {
		$foundLocalAddress = $localAddress -match "\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}";		
		break;
	}	
}

if ($foundLocalAddress) {
	$localAddress = $matches[0];	
	$outPutInterface = @([pscustomobject]@{INTERFACE=$tempAddress; LOCAL_ADDRESS=$localAddress; STATUS="OK"; DATE = $getDate; TIME = $getTime});

	} else {
	Write-Output "The Script Exited, the IP address of Windows cannot be found";
	exit;
}

#[REMOTE IP - WSL2]
$remoteAddress = bash.exe -c "ifconfig eth0 | grep 'inet '"
$foundRemoteAddress = $remoteAddress -match "\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}";

if ($foundRemoteAddress) {
	$remoteAddress = $matches[0];
} else {
	Write-Output "The Script Exited, the ip address of WSL2 cannot be found";	
	exit;
}

#[FIREWALL]
$firewall = @(
	[pscustomobject]@{
		type="TCP"; 
		name="WSL2 Firewall Unlock TCP"; 
		ports=@(19000,19001,19002,19003,19004,19005)}
	[pscustomobject]@{
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
		$outPutFirewall += @([pscustomobject]@{FIREWALL_NAME=$nameFirewall; STATUS="CREATED"; DATE = $getDate; TIME = $getTime});

	} elseif ((!(Get-NetFireWallRule -DisplayName $nameFirewall -EV Err -EA SilentlyContinue)) -and ($typeFirewall -eq "UDP")) {    
		Invoke-Expression "New-NetFireWallRule -DisplayName '$nameFirewall' -Direction Outbound -LocalPort $portsUDP -Action Allow -Protocol UDP";
		Invoke-Expression "New-NetFireWallRule -DisplayName '$nameFirewall' -Direction Inbound -LocalPort $portsUDP -Action Allow -Protocol UDP";
		$outPutFirewall += @([pscustomobject]@{FIREWALL_NAME=$nameFirewall; STATUS="CREATED"; DATE = $getDate; TIME = $getTime});
		
	} else {
		$outPutFirewall += @([pscustomobject]@{FIREWALL_NAME=$nameFirewall; STATUS="EXIST"; DATE = $getDate; TIME = $getTime});		
	}
}

#[REDIRECTING PORTS]
foreach ( $port in $firewall[0].ports) {		
	Invoke-Expression "netsh interface portproxy delete v4tov4 listenport=$port listenaddress=$localAddress" | Out-Null;
	Invoke-Expression "netsh interface portproxy add v4tov4 listenport=$port listenaddress=$localAddress connectport=$port connectaddress=$remoteAddress" | Out-Null;	
	$outFileLog += @([pscustomobject]@{PORT= $port; LOCAL_ADDRESS = $localAddress; REMOTE_ADDRESS = $remoteAddress; DATE = $getDate; TIME = $getTime});
}

#[LOG]
Remove-Item "$currentPathWin\*.log" -EV Err -EA SilentlyContinue;
$timeStamp = (Get-Date -Format d).replace("/","_");
$pathLog = "$currentPathWin\$timeStamp.log";

$outPutInterface | Format-Table -Property STATUS,INTERFACE,LOCAL_ADDRESS,DATE,TIME -AutoSize | out-file -encoding "ASCII" $pathLog -append;
$outPutFirewall | Format-Table -Property STATUS,FIREWALL_NAME,DATE,TIME -AutoSize | out-file -encoding "ASCII" $pathLog -append;
$outFileLog | Format-Table -Property PORT,LOCAL_ADDRESS,REMOTE_ADDRESS,DATE,TIME -AutoSize | out-file -encoding "ASCII" $pathLog -append;

Write-Output $outPutInterface | Format-Table -Property STATUS,INTERFACE,LOCAL_ADDRESS,DATE,TIME -AutoSize;
Write-Output $outPutFirewall | Format-Table -Property STATUS,FIREWALL_NAME,DATE,TIME -AutoSize;
Write-Output $outFileLog | Format-Table -Property PORT,LOCAL_ADDRESS,REMOTE_ADDRESS,DATE,TIME -AutoSize;
