function PlanPath{Join-Path $CaseDirectory 'case-plan.json'}
function Plan{if(-not (Test-Path (PlanPath))){throw 'PlanCase required'};Get-Content -Raw -Encoding utf8 (PlanPath)|ConvertFrom-Json}
function MetadataPath{Join-Path $CaseDirectory 'case-metadata.json'}
function Metadata{if(-not (Test-Path (MetadataPath))){throw 'BeginCase required'};Get-Content -Raw -Encoding utf8 (MetadataPath)|ConvertFrom-Json}
function AssertPlan{
  $p=Plan;if([string]$p.CaseType -ne $CaseType){throw 'CaseType mismatch'}
  if($TodoTitle -and [string]$p.TodoTitle -ne $TodoTitle){throw 'TodoTitle mismatch'}
  if($ExpectedTime -and (ParseTime $ExpectedTime 'ExpectedTime') -ne (ParseTime ([string]$p.ExpectedTime) 'plan.ExpectedTime')){throw 'ExpectedTime mismatch'};$p
}
function AssertCase{
  $m=Metadata;if([string]$m.CaseType -ne $CaseType){throw 'CaseType mismatch'}
  if($TodoTitle -and [string]$m.TodoTitle -ne $TodoTitle){throw 'TodoTitle mismatch'}
  if($ExpectedTime -and (ParseTime $ExpectedTime 'ExpectedTime') -ne (ParseTime ([string]$m.ExpectedTime) 'metadata.ExpectedTime')){throw 'ExpectedTime mismatch'};$m
}
function LatestSummary{
  $f=Get-ChildItem $CaseDirectory -Filter snapshot-summary.json -Recurse -File|Sort-Object LastWriteTime;if(-not $f){return $null};Get-Content -Raw -Encoding utf8 $f[-1].FullName|ConvertFrom-Json
}
function AlarmEvidence{
  $p=Join-Path $CaseDirectory 'alarm-registration.json';if(-not (Test-Path $p)){return $false}
  $r=Get-Content -Raw -Encoding utf8 $p|ConvertFrom-Json;[bool]($r.Result -eq 'PASS' -and [int]$r.AddedLineCount -gt 0 -and $r.RelevantLineCountIncreased -eq $true -and [int]$r.AfterRelevantLineCount -gt [int]$r.BeforeRelevantLineCount)
}
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
function NotificationEvidenceComplete($Actual,$PermissionValue,$AlarmValue,$TitleValue,$VisibleValue,$ForegroundValue,$ScreenValue,$DumpValue,$GitGateValue){
  [bool]($Actual -and $PermissionValue -eq 'GRANTED' -and $AlarmValue -and $TitleValue -and $VisibleValue -and -not $ForegroundValue -and $ScreenValue -and $DumpValue -and $GitGateValue -eq 'PASS')
}
function FinalizeCase{
  $m=AssertCase;if($Verdict -notin @('PASS','FAIL','BLOCKED','INCONCLUSIVE')){throw 'invalid Verdict'}
  $expected=ParseTime ([string]$m.ExpectedTime) 'ExpectedTime';$waitPath=Join-Path $CaseDirectory 'wait-result.json';$wait=if(Test-Path $waitPath){Get-Content -Raw -Encoding utf8 $waitPath|ConvertFrom-Json}else{$null};$actual=$ActualArrivalTime
  if(-not $actual -and $wait -and $wait.Result -eq 'NOTIFICATION_OBSERVED'){$actual=[string]$wait.ObservedAtDevice};if($actual){ParseTime $actual 'ActualArrivalTime'|Out-Null}
  $s=LatestSummary;$alarm=AlarmEvidence;$git=GitState;$perm=if($s){[string]$s.Permission}else{Permission};$title=[bool]($s -and $s.TitleEvidence);$visible=[bool]($s -and $s.TitleInUi) -or $ManualScreenshotVerified;$front=[bool]($s -and $s.AppForeground);$summaryFile=(Get-ChildItem $CaseDirectory -Filter snapshot-summary.json -Recurse -File|Sort-Object LastWriteTime|Select-Object -Last 1);$dir=if($summaryFile){$summaryFile.Directory.FullName}else{''};$screen=[bool]($dir -and (Test-Path (Join-Path $dir 'screen.png')) -and (Get-Item (Join-Path $dir 'screen.png')).Length -gt 0);$dump=[bool]($dir -and (Test-Path (Join-Path $dir 'notification.txt')) -and (Get-Item (Join-Path $dir 'notification.txt')).Length -gt 0);$notificationComplete=NotificationEvidenceComplete $actual $perm $alarm $title $visible $front $screen $dump $git.Gate
  $installResult=$null;if($CaseType -eq 'install-r'){$installPath=Join-Path $CaseDirectory 'install-result.json';if(Test-Path $installPath){$installResult=Get-Content -Raw -Encoding utf8 $installPath|ConvertFrom-Json}}
  if($Verdict -eq 'PASS'){
    if(-not $notificationComplete){throw 'PASS evidence incomplete'}
    if($CaseType -eq 'reboot'){$reboot=Get-Content -Raw -Encoding utf8 (Join-Path $CaseDirectory 'reboot-result.json')|ConvertFrom-Json;if($reboot.Result -ne 'PASS' -or -not $reboot.BootIdChanged){throw 'reboot evidence incomplete'}}
    if($CaseType -eq 'install-r'){
      if(-not $installResult -or $installResult.Result -ne 'PASS'){throw 'install evidence incomplete'}
      if(-not $InstallBroadcastVerified -or $InstallBroadcastUnverified){throw 'install-r PASS requires verified MY_PACKAGE_REPLACED evidence'}
      $reason='notification evidence complete and MY_PACKAGE_REPLACED evidence explicitly verified'
    }else{$reason='permission, alarm registration delta, visible title, screenshot, notification dump, foreground and git gates passed'}
  }elseif($Verdict -eq 'FAIL'){
    if([DateTimeOffset]::Now -lt $expected.AddMinutes($FailureWaitMinutes) -or $perm -ne 'GRANTED' -or -not $alarm -or $front -or -not $screen -or -not $dump -or $git.Gate -ne 'PASS' -or $title -or -not $wait -or $wait.Result -ne 'TIMEOUT'){throw 'FAIL evidence incomplete'};$reason='wait deadline reached with valid environment and no notification title'
  }elseif($Verdict -eq 'BLOCKED'){$reason='environment conditions broke'}else{
    if($CaseType -eq 'install-r' -and $InstallBroadcastUnverified){
      if(-not $notificationComplete -or -not $installResult -or $installResult.Result -ne 'PASS' -or $InstallBroadcastVerified){throw 'install-r INCONCLUSIVE close-path evidence incomplete'}
      $reason='install and notification observed; MY_PACKAGE_REPLACED not uniquely proven'
    }else{$reason='evidence or causality incomplete'}
  }
  $r=[pscustomobject][ordered]@{CaseName=$CaseName;CaseType=$CaseType;Verdict=$Verdict;TodoTitle=[string]$m.TodoTitle;SourceSha=[string]$m.SourceSha;ExpectedTime=[string]$m.ExpectedTime;ActualArrivalTime=$actual;Permission=$perm;AlarmRegistrationEvidence=$alarm;TitleEvidence=$title;VisibleTitle=$visible;AppForeground=$front;Screen=$screen;NotificationDump=$dump;GitGate=$git.Gate;InstallBroadcastVerified=$InstallBroadcastVerified.IsPresent;InstallBroadcastUnverified=$InstallBroadcastUnverified.IsPresent;Reason=$reason;Notes=$Notes;FinalizedAt=(Get-Date -Format o)}
  Json $r (Join-Path $CaseDirectory 'case-result.json')
  @("## Issue #60 Emulator実測: $CaseName",'',"- 判定: **$Verdict**","- Todo: ``$($r.TodoTitle)``","- Source SHA: ``$($r.SourceSha)``","- 予定時刻: ``$($r.ExpectedTime)``","- 到着時刻: ``$($r.ActualArrivalTime)``",'','### 確認済みの事実',"- $reason",'','### 未確認事項',$(if($Verdict -eq 'INCONCLUSIVE'){'- 因果関係または証跡の一部。'}else{'- なし。'}),'','### 推測・仮説','- なし。','','### 反証','- 静的確認、ビルド、起動成功だけではPASSとしていない。','','### 判定根拠',"- $reason",'','### 備考',"- $Notes") -join "`n"|Out-File (Join-Path $CaseDirectory 'issue-comment.md') -Encoding utf8
}
function Result([string]$Name,[string]$Type){$p=Join-Path (Join-Path $OutputRoot $Name) 'case-result.json';if(-not (Test-Path $p)){throw "missing $p"};$r=Get-Content -Raw -Encoding utf8 $p|ConvertFrom-Json;if($r.CaseType -ne $Type){throw 'case type mismatch'};$r}
function Aggregate{
  if(-not $NormalCaseName -or -not $RebootCaseName -or -not $InstallCaseName){throw 'three case names required'};$n=Result $NormalCaseName 'normal';$r=Result $RebootCaseName 'reboot';$i=Result $InstallCaseName 'install-r';$sources=@($n.SourceSha,$r.SourceSha,$i.SourceSha)|Where-Object{$_}|Select-Object -Unique;$sourceConsistent=$sources.Count -eq 1;$git=GitState;$currentSourceMatches=$sourceConsistent -and $git.Gate -eq 'PASS' -and $git.Head -eq $sources[0];$installEligible=$i.Verdict -eq 'PASS' -and $i.InstallBroadcastVerified -or ($i.Verdict -eq 'INCONCLUSIVE' -and $i.InstallBroadcastUnverified);$ok=$sourceConsistent -and $currentSourceMatches -and $n.Verdict -eq 'PASS' -and $r.Verdict -eq 'PASS' -and $installEligible;$rec=if($ok){'ELIGIBLE_FOR_CLOSE_REVIEW'}else{'KEEP_OPEN'}
  Json ([ordered]@{Recommendation=$rec;SourceConsistency=$sourceConsistent;CurrentSourceMatches=$currentSourceMatches;CurrentGit=$git;Normal=$n;Reboot=$r;Install=$i;GeneratedAt=(Get-Date -Format o)}) (Join-Path $CaseDirectory 'issue60-summary.json')
  @('## Issue #60 Android Emulator実測結果','', '| ケース | Todo | 予定 | 到着 | 判定 |','|---|---|---|---|---|',"| 通常 | ``$($n.TodoTitle)`` | ``$($n.ExpectedTime)`` | ``$($n.ActualArrivalTime)`` | **$($n.Verdict)** |","| 再起動後 | ``$($r.TodoTitle)`` | ``$($r.ExpectedTime)`` | ``$($r.ActualArrivalTime)`` | **$($r.Verdict)** |","| install -r後 | ``$($i.TodoTitle)`` | ``$($i.ExpectedTime)`` | ``$($i.ActualArrivalTime)`` | **$($i.Verdict)** |",'','### 確認済みの事実',"- Normal: $($n.Reason)","- Reboot: $($r.Reason)","- install-r: $($i.Reason)","- Source SHA一致: $sourceConsistent","- 現在のorigin/masterとの一致: $currentSourceMatches",'','### 未確認事項',$(if($i.Verdict -eq 'INCONCLUSIVE'){'- MY_PACKAGE_REPLACED受信の一意な識別。'}else{'- なし。'}),'','### 推測・仮説','- なし。','','### 反証','- 静的確認だけを通知PASSにしていない。','','### Close判定',"- **$rec**") -join "`n"|Out-File (Join-Path $CaseDirectory 'issue60-summary.md') -Encoding utf8
}
