function MetadataPath{Join-Path $CaseDirectory 'case-metadata.json'}
function Metadata{if(-not (Test-Path (MetadataPath))){throw 'BeginCase required'};Get-Content -Raw (MetadataPath)|ConvertFrom-Json}
function AssertCase{
  $m=Metadata;if([string]$m.CaseType -ne $CaseType){throw 'CaseType mismatch'}
  if($TodoTitle -and [string]$m.TodoTitle -ne $TodoTitle){throw 'TodoTitle mismatch'}
  if($ExpectedTime -and (ParseTime $ExpectedTime 'ExpectedTime') -ne (ParseTime ([string]$m.ExpectedTime) 'metadata.ExpectedTime')){throw 'ExpectedTime mismatch'};$m
}
function LatestSummary{
  $f=Get-ChildItem $CaseDirectory -Filter snapshot-summary.json -Recurse -File|Sort-Object LastWriteTime;if(-not $f){return $null};Get-Content -Raw $f[-1].FullName|ConvertFrom-Json
}
function AlarmEvidence{[bool](Get-ChildItem $CaseDirectory -Filter alarm-filtered.txt -Recurse -File|Where-Object{$_.Length -gt 0}|Select-Object -First 1)}
function WaitCase{
  $m=AssertCase;RequirePreflight -RequireApp|Out-Null;$expected=ParseTime ([string]$m.ExpectedTime) 'ExpectedTime';$deadline=$expected.AddMinutes($FailureWaitMinutes)
  $d=Join-Path $CaseDirectory "$(Stamp)-wait";New-Item -ItemType Directory -Force $d|Out-Null;$heart=Join-Path $d 'wait-heartbeats.jsonl';$bootId=AdbText @('shell','cat','/proc/sys/kernel/random/boot_id');$last=[DateTimeOffset]::Now;$i=0
  while($true){$i++;$now=[DateTimeOffset]::Now;$gap=($now-$last).TotalSeconds;$last=$now;$state=AdbText @('get-state');$boot=AdbText @('shell','getprop','sys.boot_completed');$tz=AdbText @('shell','getprop','persist.sys.timezone');$perm=Permission;$bid=AdbText @('shell','cat','/proc/sys/kernel/random/boot_id');$fg=Foreground;$not=AdbText @('shell','dumpsys','notification','--noredact');$found=$not -match [regex]::Escape([string]$m.TodoTitle);$hostGap=$i -gt 1 -and $gap -gt (($PollSeconds*3)+10)
    $h=[ordered]@{Iteration=$i;HostTime=$now.ToString('o');DeviceTime=(DeviceTime);HostGapSeconds=[math]::Round($gap,2);HostGapDetected=$hostGap;State=$state;Boot=$boot;Timezone=$tz;Permission=$perm;BootId=$bid;BootIdUnchanged=($bid -eq $bootId);AppForeground=$fg.IsApp;TitleObserved=$found};($h|ConvertTo-Json -Compress)|Out-File $heart -Append -Encoding utf8
    if($state -ne 'device' -or $boot -ne '1' -or $tz -ne 'Asia/Tokyo' -or $perm -ne 'GRANTED' -or $bid -ne $bootId -or $fg.IsApp -or $hostGap){$snap=Snapshot 'wait-blocked';Json ([ordered]@{Result='BLOCKED';Heartbeat=$h;Snapshot=$snap}) (Join-Path $CaseDirectory 'wait-result.json');return}
    if($found){$snap=Snapshot 'notification-observed' -Shade;Json ([ordered]@{Result='NOTIFICATION_OBSERVED';ObservedAtHost=$now.ToString('o');ObservedAtDevice=(DeviceTime);ExpectedTime=$expected.ToString('o');Snapshot=$snap;AppOpenedByScript=$false}) (Join-Path $CaseDirectory 'wait-result.json');return}
    if($now -ge $deadline){$snap=Snapshot 'wait-timeout' -Shade;Json ([ordered]@{Result='TIMEOUT';Deadline=$deadline.ToString('o');CompletedAtHost=$now.ToString('o');CompletedAtDevice=(DeviceTime);Snapshot=$snap;AppOpenedByScript=$false}) (Join-Path $CaseDirectory 'wait-result.json');return};Start-Sleep $PollSeconds
  }
}
function FinalizeCase{
  $m=AssertCase;if($Verdict -notin @('PASS','FAIL','BLOCKED','INCONCLUSIVE')){throw 'invalid Verdict'}
  $expected=ParseTime ([string]$m.ExpectedTime) 'ExpectedTime';$waitPath=Join-Path $CaseDirectory 'wait-result.json';$wait=if(Test-Path $waitPath){Get-Content -Raw $waitPath|ConvertFrom-Json}else{$null};$actual=$ActualArrivalTime
  if(-not $actual -and $wait -and $wait.Result -eq 'NOTIFICATION_OBSERVED'){$actual=[string]$wait.ObservedAtDevice};if($actual){ParseTime $actual 'ActualArrivalTime'|Out-Null}
  $s=LatestSummary;$alarm=AlarmEvidence;$git=GitState;$perm=if($s){[string]$s.Permission}else{Permission};$title=[bool]($s -and $s.TitleEvidence);$visible=[bool]($s -and $s.TitleInUi) -or $ManualScreenshotVerified;$front=[bool]($s -and $s.AppForeground);$dir=if($s){(Get-ChildItem $CaseDirectory -Filter snapshot-summary.json -Recurse -File|Sort-Object LastWriteTime)[-1].Directory.FullName}else{''};$screen=$dir -and (Test-Path (Join-Path $dir 'screen.png'));$dump=$dir -and (Test-Path (Join-Path $dir 'notification.txt'))
  if($Verdict -eq 'PASS'){
    if(-not $actual -or $perm -ne 'GRANTED' -or -not $alarm -or -not $title -or -not $visible -or $front -or -not $screen -or -not $dump -or $git.Gate -ne 'PASS'){throw 'PASS evidence incomplete'}
    if($CaseType -eq 'reboot'){$r=Get-Content -Raw (Join-Path $CaseDirectory 'reboot-result.json')|ConvertFrom-Json;if($r.Result -ne 'PASS' -or -not $r.BootIdChanged){throw 'reboot evidence incomplete'}}
    if($CaseType -eq 'install-r'){$r=Get-Content -Raw (Join-Path $CaseDirectory 'install-result.json')|ConvertFrom-Json;if($r.Result -ne 'PASS'){throw 'install evidence incomplete'}}
    $reason='permission, alarm, visible title, screenshot, notification dump, foreground and git gates passed'
  }elseif($Verdict -eq 'FAIL'){
    if([DateTimeOffset]::Now -lt $expected.AddMinutes($FailureWaitMinutes) -or $perm -ne 'GRANTED' -or -not $alarm -or $front -or -not $screen -or -not $dump -or $git.Gate -ne 'PASS' -or $title -or -not $wait -or $wait.Result -ne 'TIMEOUT'){throw 'FAIL evidence incomplete'};$reason='wait deadline reached with valid environment and no notification title'
  }elseif($Verdict -eq 'BLOCKED'){$reason='environment conditions broke'}else{$reason=if($CaseType -eq 'install-r' -and $InstallBroadcastUnverified){'install and notification observed; MY_PACKAGE_REPLACED not uniquely proven'}else{'evidence or causality incomplete'}}
  $r=[pscustomobject][ordered]@{CaseName=$CaseName;CaseType=$CaseType;Verdict=$Verdict;TodoTitle=[string]$m.TodoTitle;SourceSha=[string]$m.SourceSha;ExpectedTime=[string]$m.ExpectedTime;ActualArrivalTime=$actual;Permission=$perm;AlarmEvidence=$alarm;TitleEvidence=$title;VisibleTitle=($visible);AppForeground=$front;Screen=$screen;NotificationDump=$dump;GitGate=$git.Gate;InstallBroadcastUnverified=$InstallBroadcastUnverified.IsPresent;Reason=$reason;Notes=$Notes;FinalizedAt=(Get-Date -Format o)}
  Json $r (Join-Path $CaseDirectory 'case-result.json')
  @("## Issue #60 Emulator実測: $CaseName",'',"- 判定: **$Verdict**","- Todo: ``$($r.TodoTitle)``","- Source SHA: ``$($r.SourceSha)``","- 予定時刻: ``$($r.ExpectedTime)``","- 到着時刻: ``$($r.ActualArrivalTime)``",'', '### 確認済みの事実',"- $reason",'', '### 未確認事項',$(if($Verdict -eq 'INCONCLUSIVE'){'- 因果関係または証跡の一部。'}else{'- なし。'}),'', '### 推測・仮説','- なし。','', '### 反証','- 静的確認、ビルド、起動成功だけではPASSとしていない。','', '### 判定根拠',"- $reason",'', '### 備考',"- $Notes") -join "`n"|Out-File (Join-Path $CaseDirectory 'issue-comment.md') -Encoding utf8
}
function Result([string]$Name,[string]$Type){$p=Join-Path (Join-Path $OutputRoot $Name) 'case-result.json';if(-not (Test-Path $p)){throw "missing $p"};$r=Get-Content -Raw $p|ConvertFrom-Json;if($r.CaseType -ne $Type){throw 'case type mismatch'};$r}
function Aggregate{
  if(-not $NormalCaseName -or -not $RebootCaseName -or -not $InstallCaseName){throw 'three case names required'};$n=Result $NormalCaseName 'normal';$r=Result $RebootCaseName 'reboot';$i=Result $InstallCaseName 'install-r';$ok=$n.Verdict -eq 'PASS' -and $r.Verdict -eq 'PASS' -and ($i.Verdict -eq 'PASS' -or ($i.Verdict -eq 'INCONCLUSIVE' -and $i.InstallBroadcastUnverified));$rec=if($ok){'ELIGIBLE_FOR_CLOSE_REVIEW'}else{'KEEP_OPEN'}
  Json ([ordered]@{Recommendation=$rec;Normal=$n;Reboot=$r;Install=$i;GeneratedAt=(Get-Date -Format o)}) (Join-Path $CaseDirectory 'issue60-summary.json')
  @('## Issue #60 Android Emulator実測結果','', '| ケース | Todo | 予定 | 到着 | 判定 |','|---|---|---|---|---|',"| 通常 | ``$($n.TodoTitle)`` | ``$($n.ExpectedTime)`` | ``$($n.ActualArrivalTime)`` | **$($n.Verdict)** |","| 再起動後 | ``$($r.TodoTitle)`` | ``$($r.ExpectedTime)`` | ``$($r.ActualArrivalTime)`` | **$($r.Verdict)** |","| install -r後 | ``$($i.TodoTitle)`` | ``$($i.ExpectedTime)`` | ``$($i.ActualArrivalTime)`` | **$($i.Verdict)** |",'', '### 確認済みの事実',"- Normal: $($n.Reason)","- Reboot: $($r.Reason)","- install-r: $($i.Reason)",'', '### 未確認事項',$(if($i.Verdict -eq 'INCONCLUSIVE'){'- MY_PACKAGE_REPLACED受信の一意な識別。'}else{'- なし。'}),'', '### 推測・仮説','- なし。','', '### 反証','- 静的確認だけを通知PASSにしていない。','', '### Close判定',"- **$rec**") -join "`n"|Out-File (Join-Path $CaseDirectory 'issue60-summary.md') -Encoding utf8
}
