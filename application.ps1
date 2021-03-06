Import-Module applocker

#### Variable declaration
$app_path = ("\\CL11180.sunlifecorp.com\JavaDiscovery\" + $env:computername + "_application.txt")
$keywords_Path = ("C:\JavaDiscovery\keywords.txt")
$temp_Path = ("C:\JavaDiscovery\temp.txt")
$keyWordcontent = Get-Content -Path $keywords_Path
$driveArray = Get-PSDrive -PSProvider FileSystem 

$server = $env:computername
$date =  Get-Date
$FirstDiscovered = $date
$LastDiscovered = $date

### Create temp file
Remove-Item -Force -Path $temp_Path -ErrorAction 'silentlycontinue'
New-Item $temp_Path -ItemType file -Value "Server,Path,Type,Java_VERSION,Company,Install,LastAccessTime,FirstDiscovered,LastDiscovered`n" | Out-Null

##### Puts keywords in file into array
foreach ($keyword in $keyWordcontent)
{
  $keyword = $keyword -split(',')
}

function GetApplication {
    Param ([array]$driveArray)

    $words = "(java|jre|jvm|jdk)"
 
    for ($i = 0; $i -lt $driveArray.Length ; $i++)
    {
        if ($driveArray[$i].Free -eq $null) { ### Move on if the drive is a network drive
            continue
        }

         Write-Host 'Scanning start'
        ### Get paths based on regex search
        [array]$applicationArray += Get-ChildItem -Path $driveArray[$i].Root -Recurse -force -ErrorAction SilentlyContinue | 
                Where {$_.FullName -imatch $words -and $_.FullName -notlike '*recycle*' -and $_.FullName -notlike '*\temp\*' -and $_.FullName -notlike '*javascript*'}  
       
       Write-Host 'Scanning done'       
    } 

    for ($j = 0; $j -lt $applicationArray.Length ; $j++) ### Loop through each path
    {
        $path= $applicationArray[$j].FullName 

        if (Test-Path -Path "$path" -PathType Leaf) ### Check if path is a file (leaf = file)
        {
            $pathArray = ($path).split("\")
            
            if ($pathArray[-1] -imatch ".exe"){ ### If it is an exe file add it to temp file
                Add $path
            }
            else{
                continue
            }
        }
        else
        {
            $path = Trim $path ### Trim path 
            
            if ($path) { ### Make sure path is not empty
                $newPath =( $path | Out-String).Trim() ### Convert path object to string 
                if (!(Get-Content -Path $temp_Path | Select-String -SimpleMatch "$newPath" -Quiet)) { ### If trimmed path not found in temp file then add it
                    Add $newPath
                }
            }         
        } 
    }
}

function Trim { ### Trim paths
    Param ([string]$path)

    $pathArray = ($path).split("\")
    $cutNow = $false

    for ($a = ($pathArray.Length-1); $a -ge 1; $a--) {       
        for ($b = 0; $b -lt $keyword.Length; $b++) {
        
            if (($pathArray[$a] -like $keyword[$b]) -and $pathArray[$a] -notlike '*.*') {
                $cutNow = $True
                break
            }
        }

        if ($cutNow) { 
            break
        }
    }

    if ($a -ge 1) {    
        $path = ($pathArray | Select -first ($a+1)) -join "\"
        return $path
    }
    else {
        return $null
    }
}


function Add {
    Param ([string]$path)

    if (Test-Path -Path "$path" -PathType Leaf) { ### If it is an executable file
        $type="EXE" 
        $version='NONE'

        if ("$path" -imatch '\b\\java.exe\b') ### If it is a java file do a version check
        {
            $company=(((Get-AppLockerFileInformation -Path "$path").Publisher).PublisherName).Split(',')[0].Split('0=')[1]
            $type='JAVA'
            $version = (& $path -version 2>&1)[0].tostring()  

            if (($version -like '*Error*') -or ($version -like '*No*') -or ($version -like '*Registry*')) { ### If any errors come from version check revert back to normal EXE
                $type="EXE"
                $version='NONE'
            }
        }
    }
    else { ### If it is a folder
        $version='NONE'
        $type='FOLDER'
        $company='NONE'
    }

    $LastAccessTime=$(Get-Item $path).LastWriteTime
    $InstallDate = (Get-ChildItem $path).CreationTime

    if ($InstallDate -eq $null){
        $InstallDate = "N\A"
    }

    Add-Content -Path $temp_Path "$server,$path,$type,$version,$company,$InstallDate,$LastAccessTime,$date,$date"
}

function Create-File { ### Function to create file
     Copy-Item -Path $temp_Path -Destination $app_path
}

function Modify-File {
    Param ([array]$objectArray)
    [array]$existing = Import-Csv -Path $app_path |
                        Select-Object Server, Path, Type, Java_VERSION, Company, Install, LastAccessTime, FirstDiscovered, LastDiscovered
   $found = 0

   ForEach ($line in $objectArray) {

        for ($x = 0 ; $x -lt $existing.Length; $x++)
        {
            if ($line.Path -eq $existing[$x].Path) {
                $existing[$x].LastDiscovered=$date
                $found = 1
                break
            }
        }

        if ($found -ne 1)
        {
            [array]$existing+=$line
        }

        $found = 0
    }
  
    if ($existing[-1].Server -eq "Server") { ## Prevent addition headers getting added in to bottom of file 
        $existing = $existing[0..($existing.Length-2)]
    }
   
     $existing |
        Select-Object Server, Path, Type, Java_VERSION, Company, Install, LastAccessTime, FirstDiscovered, LastDiscovered |
        Export-Csv -Path $app_path -NoTypeInformation
}

############################## Main program ##########################################
##############################
### Matthew Tang           ###   
### Java Discovery Project ###
### Find java applciations ###
### November 22nd, 2018    ###
##############################

$stopWatch = [system.diagnostics.stopwatch]::startNew()
Write-Host 'Starting stop watch'

GetApplication $driveArray
$appArray = Get-Content -Path $temp_Path

foreach ($app in $appArray) ### Add each line of temp into an object array
{
    $fields = $app -split ","
    $object = New-Object PSObject -Property @{
            Server=$fields[0]
            Path=$fields[1]
            Type =$fields[2]
            Java_Version=$fields[3]
            Company =$fields[4]  
            Install = $fields[5]
            LastAccessTime=$fields[6]
            FirstDiscovered=$fields[7]
            LastDiscovered=$fields[8]         
    }
    [array]$objectArray += $object
} 

if (!(Test-Path $app_path)) ##### If file is not created
{
    Write-Host 'Creating file'
    Create-File $objectArray
}
else ### If file exists already
{
    Write-Host 'File exists'
    Modify-File $objectArray
}

$stopWatch.Stop()
Write-Host 'Stop watch ended (minutes): ' $stopWatch.Elapsed.TotalMinutes