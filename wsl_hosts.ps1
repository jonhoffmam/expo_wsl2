#set here the interface names of IP address that's use on Windows
$interfaceName = @("Ethernet","Wi-fi");
$getDate = (Get-Date -Format d).replace("/","-");
$getTime = (Get-Date -Format T);
$outPutFirewall = @();
$outFileLog = @();
$wslReg = REG QUERY "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\wsl2host.exe" | findstr "wsl2host.exe";
$foundReg = $wslReg -match "wsl2host.exe";

#[REG KEY]
if (!$foundReg) {
	REG ADD "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\wsl2host.exe" /d "C:\wsl_autostart\start.bat";
	REG ADD "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\wsl2host.exe" /v "Path" /d "C:\wsl_autostart";
}

#[STATIC IP]
for ($i = 0; $i -lt $interfaceName.Length; $i++) {
$tempAddress = $interfaceName[$i];
$localAddress = Invoke-Expression "netsh interface ipv4 show ipaddresses $tempAddress normal | Select-String 'infinite'";
	if (![string]::IsNullOrEmpty($localAddress)) {
		$foundLocalAddress = $localAddress -match "\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}";
	if ($foundLocalAddress) {
			$localAddress = $matches[0];
		$localAddress | out-file -encoding "ASCII" "C:\wsl_autostart\ipAddress.txt";
		} else {
			Write-Output "The Script Exited, the ip address of WSL 2 cannot be found";
			exit;
		}
	$outPutInterface = @([pscustomobject]@{INTERFACE=$tempAddress; LOCAL_ADDRESS=$localAddress; STATUS="OK"; DATE = $getDate; TIME = $getTime});		
	break;
	}
}

#[REMOTE IP]
$remoteAddress = bash.exe -c "ifconfig eth0 | grep 'inet '"
$foundRemoteAddress = $remoteAddress -match "\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}";

if ($foundRemoteAddress) {
	$remoteAddress = $matches[0];
} else{
	Write-Output "The Script Exited, the ip address of WSL 2 cannot be found";
	exit;
}

#[FIREWALL]
$firewall = @(
	[pscustomobject]@{
		type="TCP"; 
		name="WSL 2 Firewall Unlock TCP"; 
		ports=@(19000,19001,19002,19003,19004,19005)}
	[pscustomobject]@{
		type="UDP"; 
		name="WSL 2 Firewall Unlock UDP"; 
		ports=@(53)}
);

$portsTCP = $firewall[0].ports -join ",";
$portsUDP = $firewall[1].ports -join "," ;

#Adding Exception Rules for inbound and outbound Rules
for ($i = 0; $i -lt $firewall.Length; $i++) {
	$nameFirewall = $firewall[$i].name;
	
	if ((!(Get-NetFireWallRule -DisplayName $firewall[$i].name -EV Err -EA SilentlyContinue)) -and ($firewall[$i].type -eq "TCP")) {      
		Invoke-Expression "New-NetFireWallRule -DisplayName '$nameFirewall' -Direction Outbound -LocalPort $portsTCP -Action Allow -Protocol TCP";
		Invoke-Expression "New-NetFireWallRule -DisplayName '$nameFirewall' -Direction Inbound -LocalPort $portsTCP -Action Allow -Protocol TCP";    
		$outPutFirewall += @([pscustomobject]@{FIREWALL_NAME=$nameFirewall; STATUS="CREATED"; DATE = $getDate; TIME = $getTime});

	} elseif ((!(Get-NetFireWallRule -DisplayName $firewall[$i].name -EV Err -EA SilentlyContinue)) -and ($firewall[$i].type -eq "UDP")) {    
		Invoke-Expression "New-NetFireWallRule -DisplayName '$nameFirewall' -Direction Outbound -LocalPort $portsUDP -Action Allow -Protocol UDP";
		Invoke-Expression "New-NetFireWallRule -DisplayName '$nameFirewall' -Direction Inbound -LocalPort $portsUDP -Action Allow -Protocol UDP";
		$outPutFirewall += @([pscustomobject]@{FIREWALL_NAME=$nameFirewall; STATUS="CREATED"; DATE = $getDate; TIME = $getTime});
		
	} else {
		$outPutFirewall += @([pscustomobject]@{FIREWALL_NAME=$nameFirewall; STATUS="EXIST"; DATE = $getDate; TIME = $getTime});		
	}
}

#[REDIRECTING PORTS]
for ($i = 0; $i -lt $firewall[0].ports.length; $i++) {
	$port = $firewall[0].ports[$i];	
	Invoke-Expression "netsh interface portproxy delete v4tov4 listenport=$port listenaddress=$localAddress" | Out-Null;
	Invoke-Expression "netsh interface portproxy add v4tov4 listenport=$port listenaddress=$localAddress connectport=$port connectaddress=$remoteAddress" | Out-Null;	
	$outFileLog += @([pscustomobject]@{PORT= $port; LOCAL_ADDRESS = $localAddress; REMOTE_ADDRESS = $remoteAddress; DATE = $getDate; TIME = $getTime});
}

#[INSERT env REACT_NATIVE_PACKAGER_HOSTNAME IN .bashrc AND .zshrc]


#[LOG]
Remove-Item "C:\wsl_autostart\*.log" -EV Err -EA SilentlyContinue;
$timeStamp = (Get-Date -Format d).replace("/","_");
$pathLog = "C:\wsl_autostart\$timeStamp.log";

$outPutInterface | Format-Table -Property STATUS,INTERFACE,LOCAL_ADDRESS,DATE,TIME -AutoSize | out-file -encoding "ASCII" $pathLog -append;
$outPutFirewall | Format-Table -Property STATUS,FIREWALL_NAME,DATE,TIME -AutoSize | out-file -encoding "ASCII" $pathLog -append;
$outFileLog | Format-Table -Property PORT,LOCAL_ADDRESS,REMOTE_ADDRESS,DATE,TIME -AutoSize | out-file -encoding "ASCII" $pathLog -append;

Write-Output $outPutInterface | Format-Table -Property STATUS,INTERFACE,LOCAL_ADDRESS,DATE,TIME -AutoSize;
Write-Output $outPutInterface | Format-Table -Property STATUS,INTERFACE,LOCAL_ADDRESS,DATE,TIME -AutoSize;
Write-Output $outFileLog | Format-Table -Property PORT,LOCAL_ADDRESS,REMOTE_ADDRESS,DATE,TIME -AutoSize;
