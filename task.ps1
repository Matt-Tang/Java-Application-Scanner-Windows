$TaskName = "Java_Applications"
$TaskDescription = "Find Java Applications"
$TaskCommand = "c:\windows\system32\WindowsPowerShell\v1.0\powershell.exe"
$TaskScript = "C:\JavaDiscovery\application.ps1"
$TaskArg = "-WindowStyle Hidden -NonInteractive -Executionpolicy unrestricted -file $TaskScript"
$TaskStartTime = [datetime]::Now.AddMinutes(5)
$service = new-object -ComObject("Schedule.Service")
$service.Connect()
$rootFolder = $service.GetFolder("\")
$TaskDefinition = $service.NewTask(0)
$TaskDefinition.RegistrationInfo.Description = "$TaskDescription"
$TaskDefinition.Settings.Enabled = $true
$TaskDefinition.Settings.AllowDemandStart = $true

$triggers = $TaskDefinition.Triggers
$trigger = $triggers.Create(3)
$trigger.StartBoundary = $TaskStartTime.ToString("yyyy-MM-dd'T'HH:mm:ss")
$trigger.DaysOfWeek = 2
$trigger.Enabled = $true

$Action = $TaskDefinition.Actions.Create(0)
$action.Path = "$TaskCommand"
$action.Arguments = "$TaskArg"

$rootFolder.RegisterTaskDefinition("$TaskName",$TaskDefinition,6,"System",$null,5)