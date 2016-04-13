# THE INFORMATION LAB HOUSEKEEPING SCRIPT
# Authored by Jonathan MacDonald
# Last updated 05/05/2015
# How to use this script
# The first part of this script contains all the variables that you should customize to your installation, for example what version of Tableau Server you are running, where you want to save your backup files to, etc.
# Once you've customised these variables, save the script somewhere in your Tableau Server installation directory, and then use a job scheduler to run it to the frequency you require.
# See here for more information: http://www.theinformationlab.co.uk/2014/07/25/tableau-server-housekeeping-made-easy/

##-- VARIABLES SECTION - PLEASE CUSTOMISE THESE VARIABLES TO YOUR SYSTEM HERE! --##

$S3BUCKET="til-tableau-backups"
## Please create a bucket in S3 and enter its name here

$VERSION=9.3
## Please customise this to the version of Tableau Server you are running.

$BINPATH="D:\Program Files\Tableau\Tableau Server\$VERSION\bin"
## In case you don't have tabadmin set in your Path environment variable, this command sets the path to the Tableau Server bin directory in order to use the tabadmin command.
## Customise this to match your the path of your Tableau Server installation. The version variable above is included.

$BACKUPPATH="D:\Tableau Backups"
## This command sets the path to the backup folder.
## Change this to match the location of the folder you would like to save your backups to

$LOGPATH="D:\Tableau Backups"
## This command sets the path to the log files folder
## Change this to match the location of the folder you would like to save your zipped log files to

$SAVESTAMP=Get-Date
$SAVESTAMP=$SAVESTAMP -replace " ","T"
$SAVESTAMP=$SAVESTAMP -replace "/",""
$SAVESTAMP=$SAVESTAMP -replace ":",""
## This command creates a variable called SAVESTAMP which grabs the system time and formats in to look like DDMMYYYYTmmhhss
## This gets rid of the slashes in the system date which messes up the commands later when we're trying to append the date to the filename

$LOGFILE="logs$SAVESTAMP.zip"

$RESTART=""
## Do you want to restart the Tableau Server after this script completes? If yes, leave this as is.
## If no, then remove the text between the quotation marks, and just leave "" in place.

## SCRIPT INITIATION
$A = Get-Date; Write-Output "[$A] *** Housekeeping started ***" | Tee-Object -file "$BACKUPPATH\BackupLog.txt" -Append

cd $BINPATH
## changes directory to the above path and takes into account a drive change with the /d command

## ROTATING THE LOG FILES
$A = Get-Date; Write-Output "[$A]  Cleaning out old log files..." | Tee-Object -file "$BACKUPPATH\BackupLog.txt" -Append

forfiles -p $LOGPATH -s -m *.logs /D -7 /C "cmd /c del @path"
## Cleans out files in the specified directory that end with a .zip extension and are older than 28 days
## If you are running this script weekly, this ensures that only 4 weeks of log files are saved.
## You will likely want to adjust this if you plan to run this script more frequently.

$A = Get-Date; Write-Output "[$A] Backing up log files..." | Tee-Object -file "$BACKUPPATH\BackupLog.txt" -Append

.\tabadmin ziplogs -l -n -f | Tee-Object -file "$BACKUPPATH\BackupLog.txt" -Append
Rename-Item logs.zip $LOGFILE
Move-Item $LOGFILE $LOGPATH
## Grabs the Tableau Server logfiles and zips them
## Then copies the zip file to the specified directory appending the system date to the filename

## BACKING UP THE TABLEAU SERVER
$A = Get-Date; Write-Output "[$A]  Cleaning out old backup files..." | Tee-Object -file "$BACKUPPATH\BackupLog.txt" -Append
forfiles -p $BACKUPPATH -s -m *.bak /D -3 /C "cmd /c del @path"
## Cleans out files in the specified directory that end in .tsbak extension and are older than 14 days
## If you are running this script weekly, this ensures that only 2 backup files are saved.
## You will likely want to adjust this if you plan to run this script more frequently.

$A = Get-Date; Write-Output "[$A]  Backing up data..." | Tee-Object -file "$BACKUPPATH\BackupLog.txt" -Append
.\tabadmin backup $BACKUPPATH\ts_backup -d | Tee-Object -file "$BACKUPPATH\BackupLog.txt" -Append
## Backs up the Tableau Server and creates a file ts_backup.tsbak with the system date appended to the filename

## CLEANUP AND RESTART
$A = Get-Date; Write-Output "[$A] Running cleanup and restarting Tableau server..." | Tee-Object -file "$BACKUPPATH\BackupLog.txt" -Append
.\tabadmin cleanup $RESTART | Tee-Object -file "$BACKUPPATH\BackupLog.txt" -Append
## Cleans out the Tableau server logs before and after restarting the server to ensure all logs are clean after backing up and housekeeping

$A = Get-Date; Write-Output "[$A] *** Housekeeping completed ***" | Tee-Object -file "$BACKUPPATH\BackupLog.txt" -Append

Import-Module "C:\Program Files (x86)\AWS Tools\PowerShell\AWSPowerShell\AWSPowerShell.psd1"
$files = Get-ChildItem $BACKUPPATH -Filter *.tsbak
for ($i=0; $i -lt $files.Count; $i++) {
    $filename = $files[$i].Name
    $A = Get-Date; Write-Output "[$A] Uploading $filename to S3" | Tee-Object -file "$BACKUPPATH\BackupLog.txt" -Append
    Write-S3Object -BucketName $S3BUCKET -File $files[$i].FullName -Key $files[$i].Name -CannedACLName private
    $oldfilename = $files[$i].Name
    $newfilename = $oldfilename -replace ".tsbak",".bak"
    Rename-Item $files[$i].FullName $newfilename
    $A = Get-Date; Write-Output "[$A] File $filename uploaded to S3" | Tee-Object -file "$BACKUPPATH\BackupLog.txt" -Append
}
$files = Get-ChildItem $BACKUPPATH -Filter *.zip
for ($i=0; $i -lt $files.Count; $i++) {
    $filename = $files[$i].Name
    $A = Get-Date; Write-Output "[$A] Uploading $filename to S3" | Tee-Object -file "$BACKUPPATH\BackupLog.txt" -Append
    Write-S3Object -BucketName $S3BUCKET -File $files[$i].FullName -Key $files[$i].Name -CannedACLName private
    $oldfilename = $files[$i].Name
    $newfilename = $oldfilename -replace ".zip",".logs"
    Rename-Item $files[$i].FullName $newfilename
    $A = Get-Date; Write-Output "[$A] File $filename uploaded to S3" | Tee-Object -file "$BACKUPPATH\BackupLog.txt" -Append
}
