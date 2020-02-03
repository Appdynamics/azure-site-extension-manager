#Requires -Version 5

###############################################################################
##  AppDynamics - POWERSHELL - SCRIPT
##  NAME: AppD-Azure-SiteExtension-Manager.ps1
##  
##  AUTHOR:  Anurag Bajpai, AppDynamics Inc
##  DATE:  2018/01/17
##  EMAIL: abajpai@appdynamics.com
##  
##  Overview:  This script provides way to manage AppD Azure site extension. 
##  It provides following operations- 
##
##  1- AppDAzureSiteExtension-Install
##  2- AppDAzureSiteExtension-Uninstall
##  3- AppDAzureSiteExtension-UpdateAppSetting
##  4- AppDAzureSiteExtension-Status
## 
##  VERSION HISTORY
##  1.0 2018.01.17 Initial Version.
## 
## 
##  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
##  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
##  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
##  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
##  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
##  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
##  THE SOFTWARE.
## 
###############################################################################


#region CONFIG

$global:ResourceGroupName = "" 
$global:WebAppName = ""
##  Provide exact slotname to install appdynamics site extension on any specific
##  deployment slot. Empty string will target main webapp.

$global:SlotName = "" 

## Provide MSDN subscription name. Leave empty to use default scription, 
## if you have more than one MSDN subscriptions, please pass value of 
## -SubscriptioName as parameter or assign here
$global:SubscriptionName = ""

$global:AppDAgentID = "AppDynamics.WindowsAzure.SiteExtension.4.5.Release"
##  We can use different agent id to install different agent versions. 
##  4.3 controllers should use the 4.4 agent
##                    "AppDynamics.WindowsAzure.SiteExtension.4.4.Release"

##  AppDynamics agent configuration properties. 
##  Check "Configure the agent using environment variables" in following doc-
##  https://docs.appdynamics.com/display/PRO43/Install+the+AppDynamics+Azure+Site+Extension 

$global:AppDHostName="" #hostname.domain.com - do not use protocol
$global:AppDPort="" 
$global:AppDSslEnabled="" #true or false 443 use true
$global:AppDAccountName="" #customer account name from license page in your controller
$global:AppDAccountAccessKey="" #Access key from license page in your controller
$global:AppDApplicationName="" #your application name

#--- Execution Properties ---#
$Verbose = $false
$DryRun = $true

$OutFileName = $PSScriptRoot+"\AppD-AzureSiteExtension.log"
#endregion

#region Internal functions

function __WriteMessage{
    param(
    [object] $m, 
    [switch] $v, 
    [switch] $insertEmptyLine, 
    [switch] $append, 
    [System.ConsoleColor] $color="White"
    )
    
    if($Verbose -or !$v){

        if($insertEmptyLine){

            Write-Host "" 

            Add-Content $OutFileName -Value "" -NoNewline:$false 
            
        }

        $str = (Get-Date).ToString() +" "+ $m

        if($append){

            Write-Host $m -NoNewline -ForegroundColor $color

            Add-Content $OutFileName -Value $str -NoNewline

        }else{

            Write-Host $m -ForegroundColor $color

            Add-Content $OutFileName -Value $str -NoNewline:$false
        }

        
        if($insertEmptyLine){

            Write-Host ""

            Add-Content $OutFileName -Value "" -NoNewline:$false 
        }
    }
}

function __VerifySession{

    __WriteMessage "Verifying azure session" 

    $isContextEmpty = $true

    $str="" 

    try{
        $content = Get-AzureRmContext

        if ($content){
        
            $isContextEmpty = ([string]::IsNullOrEmpty($content.Account))
            
            $str = $content.Account
        } 
    } 
    catch {
        
        if ($_ -like "*Login-AzureRmAccount to login*") {
        
            $isContextEmpty = $true
        } 
        else {
        
            throw
        }
    }

    if ($isContextEmpty){

        __WriteMessage "User session not found. Initiating Azure account login-"
        
        $context = Login-AzureRmAccount

        $str = $context.Context.Account
        
        if($global:SubscriptionName)
        {
            Select-AzureRmSubscription -SubscriptionName $global:SubscriptionName
        }

    }
    else{

        __WriteMessage "Found active session."
    }

    __WriteMessage "  Logged in with Account = $str"    

}

function __ImportSettingFile{

    __WriteMessage "Reading publish setting file for $ResourceGroupName $WebAppName" -v

    ## Full path to temporary publish settings file.
    $publishFile = "$env:TEMP\AppDAzureSiteExtension.PublishSetting" 

    $publishDetails = @{} 
    
    if($SlotName){

    [xml]$publishFileXml = Get-AzureRmWebAppSlotPublishingProfile -ResourceGroupName $ResourceGroupName -Name $WebAppName -Slot $SlotName -Format "Ftp" -OutputFile $publishFile 
    
    }
    else{

    [xml]$publishFileXml = Get-AzureRmWebAppPublishingProfile -ResourceGroupName $ResourceGroupName -Name $WebAppName -Format "Ftp" -OutputFile $publishFile

    }
    
    foreach($profile in $publishFileXml.publishData){

        if($profile.FirstChild.publishMethod = "MSDeploy"){

            $publishDetails.publishUrl = $profile.FirstChild.publishUrl.Split(':')[0]

            $publishDetails.userName =  $profile.FirstChild.userName
            
            $publishDetails.userPWD = $profile.FirstChild.userPWD
            
            $publishDetails.siteName = $profile.FirstChild.msdeploySite
        }
    }

    if($publishDetails.Count -gt 0){

        __WriteMessage "Imported publish setting successfully. Publish URL-" -append -v

        __WriteMessage $publishDetails['publishUrl'] -v
    }
    else{

        throw [System.Exception] "***Error- could not import publish settings."
    } 
    
    Remove-Item $publishFile
           
    __WriteMessage "Deleted temp publish setting file." -v

    return $publishDetails
}

function __GetKuduExtUrl($publishURL){

    return "https://" + $publishURL + "/api/siteextensions";
}

function __GetBase64AuthInfo($user,$pwd){

    return [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $credentials.userName,$credentials.userPWD)))
}

function __IsInstalled($kuduExtURI, $base64AuthInfo){

    __WriteMessage "Checking if AppDynamics site extension is already installed" -v

    $currentInstallation = Invoke-RestMethod -Uri "$kuduExtURI/?filter=AppDynamics" -Headers @{Authorization=("Basic {0}" -f $base64AuthInfo)} -Method Get 
 
    if($currentInstallation){

        $str = $currentInstallation.title +" is installed on "+ $currentInstallation.installed_date_time

        __WriteMessage $str -color "Red" -insertEmptyLine

        return $currentInstallation.id
    }
    else{

        __WriteMessage "AppDynamics azure site extension is not installed."

        return ""
    }
}

function __InstallExtension($credentials){

    $kuduExtURI = __GetKuduExtUrl $credentials.publishUrl 
 
    $base64AuthInfo = __GetBase64AuthInfo $credentials.userName $credentials.userPWD 

    $installedAgentID = __IsInstalled $kuduExtURI $base64AuthInfo

    if( -not ([string]::IsNullOrWhiteSpace($installedAgentID))){

        throw [System.NotSupportedException] "AppDynamics azure site extension already installed. Please Uninstall manually and run again." 
    }

    if($DryRun){

        __WriteMessage "## DRY-RUN: Skipping - site extension installation for $ResourceGroupName $WebAppName $SlotName" 

    }
    else{

        #Adding extension via put api 
        $installation = Invoke-RestMethod -Uri "$kuduExtURI/$AppDAgentID" -Headers @{Authorization=("Basic {0}" -f $base64AuthInfo)} -Method Put

        $Status = ($installation.provisioningState).ToString() + "|" + ($installation.installed_date_time).ToString()  

        __WriteMessage "Extension Installation Status : $Status" -v
    }
}

function __UninstallExtension($credentials){

    $kuduExtURI = __GetKuduExtUrl $credentials.publishUrl
 
    $base64AuthInfo = __GetBase64AuthInfo $credentials.userName $credentials.userPWD 

    $installedAgentID = __IsInstalled $kuduExtURI $base64AuthInfo

    if([string]::IsNullOrWhiteSpace($installedAgentID)){

        throw [System.NotSupportedException] "AppDynamics azure site extension is not installed. No need to run uninstall." 

    }
    
    if($DryRun){

        __WriteMessage "## DRY-RUN: Skipping - site extension cleanup for $ResourceGroupName $WebAppName $SlotName" 

    }
    else{
        __WriteMessage " Removing $installedAgentID"

        #removing extension via delete api 
        $result = Invoke-RestMethod -Uri "$kuduExtURI/$installedAgentID" -Headers @{Authorization=("Basic {0}" -f $base64AuthInfo)} -Method DELETE

        if($result){

            __WriteMessage "Uninstalled AppD extension successfully." -v
        }
        else{

            __WriteMessage "Some problem happen during installation. Please check status and try again." -v
        }

    }
}

function __GetWebAppSettings{

    if($SlotName){

        $webApp = Get-AzureRmWebAppSlot -ResourceGroupName $ResourceGroupName -Name $WebAppName -Slot $SlotName

    }
    else{

        $webApp = Get-AzureRmWebApp -ResourceGroupName $ResourceGroupName -Name $WebAppName

    }
    
    return $webApp.SiteConfig.AppSettings
}

function __SetEnvVariables{

    $appSettingsLocal = @{} 

    $appSettings = __GetWebAppSettings

    __WriteMessage "Existing AppSettings-" -v
    
    $str = $appSettings | Out-String

    __WriteMessage $str -v

    #appending to app settings
    foreach($appSetting in $appSettings){

        $appSettingsLocal[$appSetting.Name] = $appSetting.Value
    }

    #adding or updating appd configuration

    $appSettingsLocal["appdynamics.controller.hostName"] = $AppDHostName
    
    $appSettingsLocal["appdynamics.controller.port"] = $AppDPort
    
    $appSettingsLocal["appdynamics.agent.accountName"] = $AppDAccountName
        
    $appSettingsLocal["appdynamics.agent.accountAccessKey"] = $AppDAccountAccessKey
    
    $appSettingsLocal["appdynamics.agent.applicationName"] = $AppDApplicationName
    
    $appSettingsLocal["appdynamics.controller.ssl.enabled"] = $AppDSslEnabled

    if($DryRun){

        __WriteMessage "## DRY-RUN: Skipping - Setting env variables to $ResourceGroupName $WebAppName $SlotName" 

    }
    else{

        __WriteMessage "Setting env variables to $ResourceGroupName - $WebAppName - $SlotName" -v 

        if($SlotName){
 
            $app = Set-AzureRMWebAppSlot -Name $WebAppName -ResourceGroupName $ResourceGroupName -AppSettings $appSettingsLocal -Slot $SlotName
    
        }else{

            $app = Set-AzureRMWebApp -Name $WebAppName -ResourceGroupName $ResourceGroupName -AppSettings $appSettingsLocal
        }
    }
    __WriteMessage "New AppSettings-" -v

    $str = $appSettingsLocal | Out-String

    __WriteMessage $str -v

}

function __RestartWebApp{

    if($DryRun){

        __WriteMessage "## DRY-RUN: Skipping - Restarting $ResourceGroupName $WebAppName $SlotName" 

    }
    else{

        __WriteMessage "Restarting azure webapp $ResourceGroupName $WebAppName $SlotName" -v

        if($SlotName){

                Restart-AzureRmWebAppSlot -ResourceGroupName $ResourceGroupName -Name $WebAppName -Slot $SlotName -Verbose:$Verbose
        }
        else{
    
                Restart-AzureRmWebApp -ResourceGroupName $ResourceGroupName -Name $WebAppName -Verbose:$Verbose
        }
    }
}

function __CheckStatus($credentials){

    $kuduExtURI = __GetKuduExtUrl $credentials.publishUrl
 
    $base64AuthInfo = __GetBase64AuthInfo $credentials.userName $credentials.userPWD 

    $installedAgentID = __IsInstalled $kuduExtURI $base64AuthInfo

    if( -not ([string]::IsNullOrWhiteSpace($installedAgentID))){

        #Check app settings

        $appSettings = __GetWebAppSettings

        __WriteMessage "Existing AppSettings-" 
    
        $str = $appSettings | Out-String

        __WriteMessage $str 

        return "Installed"
    }
    else{

        return "Not installed"
    }
}

function __PrintParameters {
Param(
    [switch] $all=$true
    )

    __WriteMessage "Initializing with following settings-" 
    __WriteMessage "  verbose=$Verbose "
    __WriteMessage "  DryRun=$DryRun "
    __WriteMessage "  resourceGroup=$ResourceGroupName "
    __WriteMessage "  webApp=$WebAppName "

    if($SlotName){

    __WriteMessage "  slot=$SlotName "
    }

    if($SubscriptionName){
    __WriteMessage "  SubscriptionName=$SubscriptionName "
    }

    if($all){

        __WriteMessage "  hostName=$AppDHostName "
        __WriteMessage "  port=$AppDPort "
        __WriteMessage "  ssl_enabled=$AppDSslEnabled "
        __WriteMessage "  accountName=$AppDAccountName "
        __WriteMessage "  accountAccessKey=$AppDAccountAccessKey "
        __WriteMessage "  applicationName=$AppDApplicationName "
    }

}

function __ValidateParameters{
    
    ## Validating for empty reource group name / webapp name
    if(!$ResourceGroupName -or !$WebAppName){

        throw [System.ArgumentNullException] "Can not proceed without resourcegroup and webapp name."
    }
}

function __PrintInitializationMessage {
 
    __WriteMessage -m "Initialized, available functions-" -insertEmptyLine 
    __WriteMessage -m "   AppDAzureSiteExtension-Install" -color Green
    __WriteMessage -m "   AppDAzureSiteExtension-Uninstall" -color Green
    __WriteMessage -m "   AppDAzureSiteExtension-UpdateAppSetting" -color Green
    __WriteMessage -m "   AppDAzureSiteExtension-Status" -color Green
    __WriteMessage -m "Please check readme.txt for more details. or contact help@appdynamics.com" -insertEmptyLine
    __WriteMessage "Writing logs at $OutFileName"
    __WriteMessage ""
}

#endregion

#region Global Functions

function GLOBAL:AppDAzureSiteExtension-Install{
    Param(
        [switch] $Verbose, 
        [switch] $NoDryRun,
        [String] $ResourceGroupName=$ResourceGroupName, 
        [String] $WebAppName=$WebAppName,
        [String] $SlotName=$SlotName,
        [String] $AppDHostName=$AppDHostName,
        [String] $AppDPort=$AppDPort, 
        [String] $AppDSslEnabled=$AppDSslEnabled,
        [String] $AppDAccountName=$AppDAccountName,
        [String] $AppDAccountAccessKey=$AppDAccountAccessKey,
        [String] $AppDApplicationName=$AppDApplicationName,
        [String] $SubscriptionName=$SubscriptionName
    )

    $DryRun = !$NoDryRun

    __PrintParameters
    __ValidateParameters

    __WriteMessage "*** Initializing azure site extension installation for ResourceGroup= $ResourceGroupName WebApp= $WebAppName $SlotName SubscriptionName= $SubscriptionName" -insertEmptyLine Green

    try{

        if($SubscriptionName){
            Select-AzureRmSubscription -SubscriptionName $SubscriptionName
        }

        __WriteMessage "*** Importing publish settings." -insertEmptyLine Green
    
        $creds = __ImportSettingFile 

        __WriteMessage "*** Installing Azure Site Extension : $AppDAgentID" -insertEmptyLine Green

        __InstallExtension $creds

        __WriteMessage "*** Adding appdynamics configuration using AppSettings." -insertEmptyLine Green

        __SetEnvVariables

        __WriteMessage "*** Restarting webapp." -insertEmptyLine Green

        __RestartWebApp
         
        __WriteMessage "*** Appdynamics extension installed successfully and restarted azure webapp!!" -insertEmptyLine Green
    }
    catch{
        $str = $_ | Out-String

        __WriteMessage $str -color Red
    }
}

function GLOBAL:AppDAzureSiteExtension-Uninstall{
    Param(
        [switch] $Verbose=$Verbose, 
        [switch] $NoDryRun,
        [String] $ResourceGroupName=$ResourceGroupName, 
        [String] $WebAppName=$WebAppName,
        [String] $SlotName=$SlotName,
        [String] $SubscriptionName=$SubscriptionName
    )

    $DryRun = !$NoDryRun

    __PrintParameters -all:$false

    __WriteMessage "*** Initializing azure site extension uninstallation for ResourceGroup= $ResourceGroupName WebApp= $WebAppName $SlotName SubscriptionName= $SubscriptionName" -insertEmptyLine Green

    try{

        if($SubscriptionName){
            Select-AzureRmSubscription -SubscriptionName $SubscriptionName
        }

        __WriteMessage "*** Importing publish settings." -insertEmptyLine Green
    
        $creds = __ImportSettingFile

        __WriteMessage "*** Removing Azure Site Extension." -insertEmptyLine Green

        __UninstallExtension $creds

        __WriteMessage "*** Restarting webapp." -insertEmptyLine Green

        __RestartWebApp
         
        __WriteMessage "*** Appdynamics extension removed successfully and restarted azure webapp!!" -insertEmptyLine Green
    }
    catch{
        $str = $_ | Out-String

            __WriteMessage $str -color Red
    }
}

function GLOBAL:AppDAzureSiteExtension-UpdateAppSetting{
    Param(
        [switch] $Verbose=$Verbose, 
        [switch] $NoDryRun,
        [String] $ResourceGroupName=$ResourceGroupName, 
        [String] $WebAppName=$WebAppName,
        [String] $SlotName=$SlotName,
        [String] $AppDHostName=$AppDHostName,
        [String] $AppDPort=$AppDPort, 
        [String] $AppDSslEnabled=$AppDSslEnabled,
        [String] $AppDAccountName=$AppDAccountName,
        [String] $AppDAccountAccessKey=$AppDAccountAccessKey,
        [String] $AppDApplicationName=$AppDApplicationName,
        [String] $SubscriptionName=$SubscriptionName
    )
    $DryRun = !$NoDryRun

    __PrintParameters

    __WriteMessage "*** Updating app settings for ResourceGroup= $ResourceGroupName WebApp= $WebAppName $SlotName SubscriptionName= $SubscriptionName" -insertEmptyLine Green

    try{

        if($SubscriptionName){
            Select-AzureRmSubscription -SubscriptionName $SubscriptionName
        }

        __WriteMessage "*** Adding appdynamics configuration using AppSettings." -insertEmptyLine Green

        __SetEnvVariables 

        __WriteMessage "*** Restarting webapp." -insertEmptyLine Green

        __RestartWebApp 
         
        __WriteMessage "*** Appdynamics extension appsettings updated successfully and restarted azure webapp!!" -insertEmptyLine Green
    }
    catch{
        $str = $_ | Out-String

        __WriteMessage $str -color Red
    }
}

function GLOBAL:AppDAzureSiteExtension-Status{
    Param(
        [switch] $Verbose=$Verbose,
        [String] $ResourceGroupName=$ResourceGroupName, 
        [String] $WebAppName=$WebAppName,
        [String] $SlotName=$SlotName,
        [String] $SubscriptionName=$SubscriptionName
    )

    __WriteMessage "*** Checking status of AppD Azure Site Extension for ResourceGroup= $ResourceGroupName WebApp= $WebAppName $SlotName SubscriptionName= $SubscriptionName " -insertEmptyLine Green

    try{
        
        if($SubscriptionName){
            Select-AzureRmSubscription -SubscriptionName $SubscriptionName
        }


        __WriteMessage "*** Importing publish settings." -insertEmptyLine Green
    
        $creds = __ImportSettingFile 

        __WriteMessage "*** Checking appd site extension for ResourceGroup= $ResourceGroupName WebApp= $WebAppName $SlotName SubscriptionName= $SubscriptionName" -insertEmptyLine Green

        $status = __CheckStatus $creds

        __WriteMessage "*** AppD Site extension is $status for ResourceGroup= $ResourceGroupName WebApp= $WebAppName $SlotName SubscriptionName= $SubscriptionName " -insertEmptyLine Green

        }
    catch{
        $str = $_ | Out-String

        __WriteMessage $str -color Red
    }
}

#endregion

#region EXECUTION
clear

__WriteMessage -m "Initializing AppDynamics Azure Site Extension Manager using azure powershell api" -insertEmptyLine

$psVersion = $PSVersionTable.PSVersion.ToString() 

__WriteMessage -m "Running powershell version: $psVersion"

__VerifySession

__PrintInitializationMessage

#endregion
