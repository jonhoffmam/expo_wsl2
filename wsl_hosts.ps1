#[Static IP]
$getDate = (Get-Date -Format d).replace("/","-");
$getTime = (Get-Date -Format T);
$outPutFirewall = @();
$outFileLog = @();
#Set the interface name of IP address
$interfaceName = @('Ethernet','Wi-fi');

for ($i = 0; $i -lt $interfaceName.Length; $i++) {
$tempAddress = $interfaceName[$i];
$localAddress = iex "netsh interface ipv4 show ipaddresses $tempAddress normal | Select-String 'infinite'";
  if (![string]::IsNullOrEmpty($localAddress)) {
    $foundLocalAddress = $localAddress -match '\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}';
	if ($foundLocalAddress) {
      $localAddress = $matches[0];
	  $localAddress | out-file -encoding "ASCII" "C:\wsl_autostart\ipAddress.txt";
    } else{
      echo "The Script Exited, the ip address of WSL 2 cannot be found";
      exit;
    }
	$outPutInterface = @([pscustomobject]@{INTERFACE=$tempAddress; LOCAL_ADDRESS=$localAddress; STATUS="OK"; DATE = $getDate; TIME = $getTime});	
    #echo $outPutInterface;
	break;
  }
}

#[Remote IP]
$remoteAddress = bash.exe -c "ifconfig eth0 | grep 'inet '"
$foundRemoteAddress = $remoteAddress -match '\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}';

if ($foundRemoteAddress) {
  $remoteAddress = $matches[0];
} else{
  echo "The Script Exited, the ip address of WSL 2 cannot be found";
  exit;
}

#[Static IP]
#You can change the address to your ip config to listen to a specific address
#$address = '192.168.0.210';

#[FireWall]
$firewall = @(
  [pscustomobject]@{type="TCP"; name="WSL 2 Firewall Unlock TCP"; ports=@(19000,19001,19002,19003,19004,19005)}
  [pscustomobject]@{type="UDP"; name="WSL 2 Firewall Unlock UDP"; ports=@(53)}
);

$portsTCP = $firewall[0].ports -join ",";
$portsUDP = $firewall[1].ports -join "," ;

#Remove and adding Exception Rules for inbound and outbound Rules
for ($i = 0; $i -lt $firewall.Length; $i++) {
  $nameFirewall = $firewall[$i].name;  
  if ((!(Get-NetFireWallRule -DisplayName $firewall[$i].name -EV Err -EA SilentlyContinue)) -and ($firewall[$i].type -eq "TCP")) {    
    #iex "Remove-NetFireWallRule -DisplayName '$nameFirewall' ";  
    iex "New-NetFireWallRule -DisplayName '$nameFirewall' -Direction Outbound -LocalPort $portsTCP -Action Allow -Protocol TCP";
    iex "New-NetFireWallRule -DisplayName '$nameFirewall' -Direction Inbound -LocalPort $portsTCP -Action Allow -Protocol TCP";
    
	$outPutFirewall += @([pscustomobject]@{NAME=$nameFirewall; STATUS="CREATED"; DATE = $getDate; TIME = $getTime});
	#echo ($firewall[$i].name + " --> FireWall Created");
  } elseif ((!(Get-NetFireWallRule -DisplayName $firewall[$i].name -EV Err -EA SilentlyContinue)) -and ($firewall[$i].type -eq "UDP")) {    
    #iex "Remove-NetFireWallRule -DisplayName '$nameFirewall' ";
    iex "New-NetFireWallRule -DisplayName '$nameFirewall' -Direction Outbound -LocalPort $portsUDP -Action Allow -Protocol UDP";
    iex "New-NetFireWallRule -DisplayName '$nameFirewall' -Direction Inbound -LocalPort $portsUDP -Action Allow -Protocol UDP";
	
	$outPutFirewall += @([pscustomobject]@{NAME=$nameFirewall; STATUS="CREATED"; DATE = $getDate; TIME = $getTime});
    #echo ($firewall[$i].name + " --> FireWall Created");
  } else {
	$outPutFirewall += @([pscustomobject]@{NAME=$nameFirewall; STATUS="EXIST"; DATE = $getDate; TIME = $getTime});
    echo ($nameFirewall + " --> Exist");
  }
}

#Write-Output $outPutFirewall;


for ($i = 0; $i -lt $firewall[0].ports.length; $i++) {
  $port = $firewall[0].ports[$i];
  iex "netsh interface portproxy delete v4tov4 listenport=$port listenaddress=$localAddress" | Out-Null;
  iex "netsh interface portproxy add v4tov4 listenport=$port listenaddress=$localAddress connectport=$port connectaddress=$remoteAddress" | Out-Null;
  #$outFileLog = "$port - $localAddress | $remoteAddress";
  $outFileLog += @([pscustomobject]@{PORT= $port; LOCAL_ADDRESS = $localAddress; REMOTE_ADDRESS = $remoteAddress; DATE = $getDate; TIME = $getTime});
}

rm "C:\wsl_autostart\*.log" -EV Err -EA SilentlyContinue;
$timeStamp = (Get-Date -Format d).replace("/","_");
$pathLog = "C:\wsl_autostart\$timeStamp.log";

$outPutInterface | Format-Table -Property STATUS,INTERFACE,LOCAL_ADDRESS,DATE,TIME -AutoSize | out-file -encoding "ASCII" $pathLog -append;
$outPutFirewall | Format-Table -Property STATUS,NAME,DATE,TIME -AutoSize | out-file -encoding "ASCII" $pathLog -append;
$outFileLog | Format-Table -Property PORT,LOCAL_ADDRESS,REMOTE_ADDRESS,DATE,TIME -AutoSize | out-file -encoding "ASCII" $pathLog -append;

echo $outFileLog;
