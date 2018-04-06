# AppDynamics Azure Site Extension Manager
AppDynamicd Azure Site Extension Manager is a powershell script to manage AppDynamics .NET agent installation on Azure WebApps. Manual installation steps are explained in folllowing document- 
https://docs.appdynamics.com/display/PRO43/Install+the+AppDynamics+Azure+Site+Extension

This script makes use of azure powershell cmdlets and kudu rest api. It provides an easy way to manage AppD Azure site extension. Presently the script supports following operations- 
1. AppDAzureSiteExtension-Install
2. AppDAzureSiteExtension-Uninstall
3. AppDAzureSiteExtension-UpdateAppSetting
4. AppDAzureSiteExtension-Status
  
### Prerequisite 
AppDynamics Azure Site Extension Manager requires powershell version 5 or newer to be installed. Also it uses [azure powershell](https://docs.microsoft.com/en-us/powershell/azure/overview?view=azurermps-5.2.0) cmdlets to manage site extension. Please verify by running `Login-AzureRmAccount` in windows powershell. If the azure powershell is installed, it will popup to authenticate with your azure account. 

### How to use

1. Download file "AppD-Azure-SiteExtension-Manager.ps1" and copy in an empty folder.
2. Open file `script/ps/AppD-Manager-Azure-SiteExtension.ps1` to edit 
3. locate `#region CONFIG` and optionally provide appropriate values as highlighted here- 
```
 $global:ResourceGroupName = "" 
 $global:WebAppName = ""
 ##  Provide exact slotname to install appdynamics site extension on any specific
 ##  deployment slot. Empty string will target main webapp.

 $global:SlotName = "" 

 ## Provide MSDN subscription name
$global:SubscriptionName = ""

 $global:AppDAgentID = "AppDynamics.WindowsAzure.SiteExtension.4.3.Release"
 ##  We can use different agent id to install different agent versions. 
 ##  Following value need to be used for agent version 4.4
 ##                    "AppDynamics.WindowsAzure.SiteExtension.4.4.Release"

 ##  AppDynamics agent configuration properties. 
 ##  Check "Configure the agent using environment variables" in following doc-
 ##  https://docs.appdynamics.com/display/PRO43/Install+the+AppDynamics+Azure+Site+Extension 

 $global:AppDHostName="" 
 $global:AppDPort="" 
 $global:AppDSslEnabled="" 
 $global:AppDAccountName="" 
 $global:AppDAccountAccessKey="" 
 $global:AppDApplicationName="" 
```
   :bulb: We can also provide or change these values while calling cmdlet. 

4. Save file and run following command in powershell.exe window- 

   `Import-Module .\Azure-siteExtension.ps1`
 
   :bulb: This will verify powershell version and azure session. Powershell will popup azure login window if user is not logged in to azure session.

5. Now we can run any of the following commands-
      - AppDAzureSiteExtension-Install
      - AppDAzureSiteExtension-Uninstall
      - AppDAzureSiteExtension-UpdateAppSetting
      - AppDAzureSiteExtension-Status

#### AppDAzureSiteExtension-Install
This cmdlet will try to install appdynamics azure site extension, set application settings for appdynamics then restart webapp instance. Following is usage of this cmdlet with all optional parameters.
```
AppDAzureSiteExtension-Install
-Verbose 
-NoDryRun 
-ResourceGroupName "..." 
-SubscriptionName "..." 
-WebAppName "..." 
-SlotName "" 
-AppDHostName "..." 
-AppDPort "..." 
-AppDSslEnabled "..." 
-AppDAccountName "..." 
-AppDAccountAccessKey "..." 
-AppDApplicationName "..." 
```

#### AppDAzureSiteExtension-Uninstall
This cmdlet will try to remove appdynamics azure site extension and then restart webapp instance. Following is usage of this cmdlet with all optional parameters.
```
AppDAzureSiteExtension-UnInstall 
-Verbose 
-NoDryRun 
-ResourceGroupName "..." 
-SubscriptionName "..."
-WebAppName "..." 
-SlotName "" 
```

#### AppDAzureSiteExtension-UpdateAppSetting
This cmdlet will try to update existing application setting with provided values and then restart webapp instance. Following is usage of this cmdlet with all optional parameters.
```
AppDAzureSiteExtension-UpdateAppSetting
-Verbose 
-NoDryRun 
-ResourceGroupName "..." 
-SubscriptionName "..."
-WebAppName "..." 
-SlotName "" 
-AppDHostName "..." 
-AppDPort "..." 
-AppDSslEnabled "..." 
-AppDAccountName "..." 
-AppDAccountAccessKey "..." 
-AppDApplicationName "..."  
```

#### AppDAzureSiteExtension-Status
This cmdlet will check if AppDynamics Azure site extension is installed or not. It will also print existing AppSettigs if installed. Following is usage of this cmdlet with all optional parameters.
```
AppDAzureSiteExtension-Install 
-Verbose 
-NoDryRun 
-ResourceGroupName "..." 
-SubscriptionName "..."
-WebAppName "..." 
-SlotName "" 
```


##### Description of parameters 

Parameter Name | Type | Decription | Usage
---------------|------|------------|-------
Verbose | switch | Enables additional logging | -Verbose  
NoDryRun | switch | Allows actual execution | -NoDryRun  
ResourceGroupName | String | Name of resource group | -ResourceGroupName "mygroup" 
WebAppName | String | Name of WebAppName | -WebAppName "myapp"  
SlotName | String | Name of slot for webapp | -SlotName "qa"  
AppDHostName | String | Host of appd controller | -AppDHostName "account.saas.appd.com"  
AppDPort | String | Port of appd controller | -AppDPort "443"  
AppDSslEnabled | String | To connect using http or https | -AppDSslEnabled "true"  
AppDAccountName | String | account name for appd controller | -AppDAccountName "account"   
AppDAccountAccessKey | String | account key for appd controller | -AppDAccountAccessKey "some-guid"  
AppDApplicationName | String | App name for appd controller | -AppDApplicationName "myapp"   
SubscriptionName | String | MSDN Subscription Name | -SubscriptionName "Your-MSDN-SubscriptionName"


Please Note, 
- All these parameters can be set in CONFIG section as previously mentioned. 
- Parameter value passed with command will get precedence over value set in CONFIG section.
- By default **DryRun mode is ON**. In this mode no actual changes will be made. Switch -NoDryRun is needed to make actual changes. We recommend to run with Dry mode first to make sure the settings are correct and to avoid accidental changes. 
- By default all execution is getting recorded in file "AppD-AzureSiteExtension.log", in same directory as ps1 script file. This can be changed via "OutFileName" in CONFIG section. The file size is not capped, it needs to be checked. 
- For more details about AppDynamics controller related configuration properties, please check "Configure the agent using environment variables" in following doc- 
https://docs.appdynamics.com/display/PRO43/Install+the+AppDynamics+Azure+Site+Extension 

### Notice and Disclaimer
All Extensions published by AppDynamics are governed by the Apache License v2 and are excluded from the definition of covered software under any agreement between AppDynamics and the User governing AppDynamics Pro Edition, Test & Dev Edition, or any other Editions.
