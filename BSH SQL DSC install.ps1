#requires -Version 5

Configuration SQLSA
{
#    Import-DscResource -Module xCredSSP
    Import-DscResource -Module xSQLServer
    Import-DscResource –ModuleName ’PSDesiredStateConfiguration’ 
    Import-DSCResource -ModuleName xStorage

    # Set role and instance variables
    $Roles = $AllNodes.Roles | Sort-Object -Unique
    foreach($Role in $Roles)
    {
        $Servers = @($AllNodes.Where{$_.Roles | Where-Object {$_ -eq $Role}}.NodeName)
        Set-Variable -Name ($Role.Replace(" ","").Replace(".","") ) -Value $Servers
    } 

    Node $AllNodes.NodeName
    {
        # Set LCM to reboot if needed
        LocalConfigurationManager
        {
            RebootNodeIfNeeded = $true
        }

        # Install .NET Framework 3.5 on SQL and Web Console nodes
        if(
            ($SQL2012DatabaseServer | Where-Object {$_ -eq $Node.NodeName}) -or
            ($SQL2012ManagementTools | Where-Object {$_ -eq $Node.NodeName}) -or
            ($SQL2014DatabaseServer | Where-Object {$_ -eq $Node.NodeName}) -or 
            ($SQL2014ManagementTools | Where-Object {$_ -eq $Node.NodeName})

        )
        {
            WindowsFeature "NET-Framework-Core"
            {
                Ensure = "Present"
                Name = "NET-Framework-Core"
                Source = $Node.SourcePath + "\WindowsServer2012R2\sources\sxs"
            }
        }


        # Install SQL Instances
        if(
            ($SQL2012DatabaseServer | Where-Object {$_ -eq $Node.NodeName})
        )
        {

            xWaitforDisk Disk2
            {
                 DiskNumber = 2
                 RetryIntervalSec = 60
                 RetryCount = 60
            }
            xDisk DVolume
            {
                 DiskNumber = 2
                 DriveLetter = 'D'
                 AllocationUnitSize = 64kb
                 DependsOn = "[xWaitforDisk]Disk2"
            }

            xWaitforDisk Disk3
            {
                 DiskNumber = 3
                 RetryIntervalSec = 60
                 RetryCount = 60
            }
            xDisk EVolume
            {
                 DiskNumber = 3
                 DriveLetter = 'E'
                 AllocationUnitSize = 64kb
                 DependsOn = "[xWaitforDisk]Disk3"
            }

            xWaitforDisk Disk4
            {
                 DiskNumber = 3
                 RetryIntervalSec = 60
                 RetryCount = 60
            }
            xDisk FVolume
            {
                 DiskNumber = 3
                 DriveLetter = 'F'
                 AllocationUnitSize = 64kb
                 DependsOn = "[xWaitforDisk]Disk4"
            }

            xWaitforDisk Disk5
            {
                 DiskNumber = 3
                 RetryIntervalSec = 60
                 RetryCount = 60
            }
            xDisk TVolume
            {
                 DiskNumber = 3
                 DriveLetter = 'T'
                 AllocationUnitSize = 64kb
                 DependsOn = "[xWaitforDisk]Disk5"
            }

            foreach($SQLServer in $Node.SQLServers)
            {
                $SQLInstanceName = $SQLServer.InstanceName

                xSqlServerSetup ($Node.NodeName + $SQLInstanceName)
                {
                    DependsOn = @(
                                    "[WindowsFeature]NET-Framework-Core"
                                    "[xDisk]DVolume"
                                    "[xDisk]EVolume"
                                    "[xDisk]FVolume"
                                    "[xDisk]TVolume"
                                )
                    SourcePath = $Node.SourcePath
                    SourceFolder = "SQLServer2012.en"
                    SetupCredential = $Node.InstallerServiceAccount
                    InstanceName = $SQLInstanceName
                    Features = $sqlServer.Features
                    AgtSvcAccount = $Node.SQLAgtServiceAccount
                    SQLSvcAccount = $Node.SQLServiceAccount

                    SecurityMode = $node.SecurityMode
                    SAPwd = $node.SAPwd

                    SQLSysAdminAccounts = $Node.SQLAdmins

                    InstallSharedDir = "C:\Program Files\Microsoft SQL Server"
                    INSTALLSHAREDWOWDIR = "C:\Program Files (x86)\Microsoft SQL Server"

                    INSTANCEDIR = "C:\Program Files\Microsoft SQL Server"
                    INSTALLSQLDATADIR = "D:\"

                    SQLBACKUPDIR = "F:\SQLDumps"

                    SQLTempDBLogDir = "E:\sqlLogs"
                    SQLTEMPDBDIR = "t:\sqldb"

                    SQLUserDBDir = "d:\sqldb"
                    SQLUserDBLogDir = "E:\sqlLogs"

                    SQLCollation = "SQL_Latin1_General_CP1_CI_AS"
                    
                    UpdateEnabled = "True"
                    UpdateSource = $node.UpdateSource

                    PID = $Node.PID
                }

                xSQLServerPowerPlan ($Node.NodeName + $SQLInstanceName)
                {
                    DependsOn = ("[xSqlServerSetup]" + $Node.NodeName + $SQLInstanceName)
                    Ensure = "Present"
                }
    
                xSqlServerMemory  ($Node.NodeName + $SQLInstanceName)
                {
                    DependsOn = ("[xSqlServerSetup]" + $Node.NodeName + $SQLInstanceName)
                    Ensure = "Present"
                    DynamicAlloc = $true
                }
                
                xSQLServerMaxDop  ($Node.NodeName + $SQLInstanceName)
                {
                    Ensure = "Present"
                    DynamicAlloc = $true
                    DependsOn = ("[xSqlServerSetup]" + $Node.NodeName + $SQLInstanceName)
                }
                xSQLServerNetwork ($Node.NodeName + $SQLInstanceName)
                {
                    DependsOn = ("[xSqlServerSetup]" + $Node.NodeName + $SQLInstanceName)
                    InstanceName = $sqlInstanceName
                    ProtocolName = "tcp"
                    IsEnabled = $true
                    RestartService = $true 
                }   

                xSQLDatabaseRecoveryModel($Node.NodeName + $SQLInstanceName)
                {
                    DependsOn = ("[xSqlServerSetup]" + $Node.NodeName + $SQLInstanceName)
                    sqlServerInstance = "$($Node.NodeName)\$SQLInstanceName" 
                    DatabaseName='Model'
                    RecoveryModel='Simple'
                }
               
                xSqlServerFirewall ($Node.NodeName + $SQLInstanceName)
                {
                    DependsOn = ("[xSqlServerSetup]" + $Node.NodeName + $SQLInstanceName)
                    SourcePath = $Node.SourcePath
                    SourceFolder = "SQLServer2012.en"
                    InstanceName = $SQLInstanceName
                    Features = $sqlServer.Features
                }
                
            }
        }

        # Install SQL Management Tools
        if($SQL2012ManagementTools | Where-Object {$_ -eq $Node.NodeName})
        {
            xSqlServerSetup "SQLMT"
            {
                DependsOn = @(
                                "[WindowsFeature]NET-Framework-Core"
                            )
                SourcePath = $Node.SourcePath
                SourceFolder = "SQLServer2012.en"
                SetupCredential = $Node.InstallerServiceAccount
                InstanceName = "NULL"
                Features = "SSMS,ADV_SSMS"
            }
        }

        # Install SQL Instances
        if(
            ($SQL2014DatabaseServer | Where-Object {$_ -eq $Node.NodeName})
        )
        {

            xWaitforDisk Disk1
            {
                 DiskNumber = 1
                 RetryIntervalSec = 60
                 RetryCount = 60
            }
            xDisk DVolume
            {
                 DiskNumber = 1
                 DriveLetter = 'D'
                 AllocationUnitSize = 64kb
                 DependsOn = "[xWaitforDisk]Disk1"
            }

            xWaitforDisk Disk2
            {
                 DiskNumber = 2
                 RetryIntervalSec = 60
                 RetryCount = 60
            }
            xDisk EVolume
            {
                 DiskNumber = 2
                 DriveLetter = 'E'
                 AllocationUnitSize = 64kb
                 DependsOn = "[xWaitforDisk]Disk2"
            }

            xWaitforDisk Disk3
            {
                 DiskNumber = 3
                 RetryIntervalSec = 60
                 RetryCount = 60
            }
            xDisk FVolume
            {
                 DiskNumber = 3
                 DriveLetter = 'F'
                 AllocationUnitSize = 64kb
                 DependsOn = "[xWaitforDisk]Disk3"
            }

            xWaitforDisk Disk4
            {
                 DiskNumber = 4
                 RetryIntervalSec = 60
                 RetryCount = 60
            }
            xDisk TVolume
            {
                 DiskNumber = 4
                 DriveLetter = 'T'
                 AllocationUnitSize = 64kb
                 DependsOn = "[xWaitforDisk]Disk4"
            }


            foreach($SQLServer in $Node.SQLServers)
            {
                $SQLInstanceName = $SQLServer.InstanceName

                xSqlServerSetup ($Node.NodeName + $SQLInstanceName)
                {
                    DependsOn = @(
                                    "[WindowsFeature]NET-Framework-Core"
                                    "[xDisk]DVolume"
                                    "[xDisk]EVolume"
                                    "[xDisk]FVolume"
                                    "[xDisk]TVolume"
                                )
                    SourcePath = $Node.SourcePath
                    SourceFolder = "SQLServer2014.en"
                    SetupCredential = $Node.InstallerServiceAccount
                    InstanceName = $SQLInstanceName
                    Features = $sqlServer.Features
                    AgtSvcAccount = $Node.SQLAgtServiceAccount
                    SQLSvcAccount = $Node.SQLServiceAccount

                    SecurityMode = $node.SecurityMode
                    SAPwd = $node.SAPwd

                    SQLSysAdminAccounts = $Node.SQLAdmins

                    InstallSharedDir = "C:\Program Files\Microsoft SQL Server"
                    INSTALLSHAREDWOWDIR = "C:\Program Files (x86)\Microsoft SQL Server"

                    INSTANCEDIR = "C:\Program Files\Microsoft SQL Server"
                    INSTALLSQLDATADIR = "D:\"

                    SQLBACKUPDIR = "F:\SQLDumps"

                    SQLTempDBLogDir = "E:\sqlLogs"
                    SQLTEMPDBDIR = "t:\sqldb"

                    SQLUserDBDir = "d:\sqldb"
                    SQLUserDBLogDir = "E:\sqlLogs"

                    SQLCollation = "SQL_Latin1_General_CP1_CI_AS"
                    
                    UpdateEnabled = "True"
                    UpdateSource = $node.UpdateSource

                    PID = $Node.PID
                }

                xSQLServerPowerPlan ($Node.NodeName + $SQLInstanceName)
                {
                    Ensure = "Present"
                }
    
                xSqlServerMemory  ($Node.NodeName + $SQLInstanceName)
                {
                    DependsOn = ("[xSqlServerSetup]" + $Node.NodeName + $SQLInstanceName)
                    Ensure = "Present"
                    DynamicAlloc = $true
                }
                
                xSQLServerMaxDop($Node.Nodename)
                {
                    Ensure = "Present"
                    DynamicAlloc = $true
                    DependsOn = ("[xSqlServerSetup]" + $Node.NodeName + $SQLInstanceName)
                }

                xSQLServerNetwork ($Node.NodeName + $SQLInstanceName)
                {
                    DependsOn = ("[xSqlServerSetup]" + $Node.NodeName + $SQLInstanceName)
                    InstanceName = $sqlInstanceName
                    ProtocolName = "tcp"
                    IsEnabled = $true
                    RestartService = $true 
                }   

                xSqlServerFirewall ($Node.NodeName + $SQLInstanceName)
                {
                    DependsOn = ("[xSqlServerSetup]" + $Node.NodeName + $SQLInstanceName)
                    SourcePath = $Node.SourcePath
                    SourceFolder = "SQLServer2014.en"
                    InstanceName = $SQLInstanceName
                    Features = $sqlServer.Features
                }

                xSQLDatabaseRecoveryModel($Node.NodeName + $SQLInstanceName)
                {
                    DependsOn = ("[xSqlServerSetup]" + $Node.NodeName + $SQLInstanceName)
                    sqlServerInstance = "$($Node.NodeName)\$SQLInstanceName" 
                    DatabaseName='Model'
                    RecoveryModel='Simple'
                }

                
            }
        }

        # Install SQL Management Tools
        if($SQL2014ManagementTools | Where-Object {$_ -eq $Node.NodeName})
        {
            xSqlServerSetup "SQLMT"
            {
                DependsOn = @(
                                "[WindowsFeature]NET-Framework-Core"
                            )
                SourcePath = $Node.SourcePath
                SourceFolder = "SQLServer2014.en"
                SetupCredential = $Node.InstallerServiceAccount
                InstanceName = "NULL"
                Features = "SSMS,ADV_SSMS"
            }
        }
    }
}

$SecurePassword = ConvertTo-SecureString -String "P@ssw0rd" -AsPlainText -Force
$LocalSystemAccount = New-Object System.Management.Automation.PSCredential ("SYSTEM", $SecurePassword)

$SecurePassword = ConvertTo-SecureString -String "2TjxZkxGXnPjymUXxRFAVwG4" -AsPlainText -Force
$InstallerServiceAccount = New-Object System.Management.Automation.PSCredential ("SLLab\Installer", $SecurePassword)

$SecurePassword = ConvertTo-SecureString -String "quVYE8zJVQCjPScnYxtUDQt9" -AsPlainText -Force
$SQLServiceAccount = New-Object System.Management.Automation.PSCredential ("SLLab\SQL-SVC", $SecurePassword)

$SecurePassword = ConvertTo-SecureString -String "quVYE8zJVQCjPScnYxtUDQt9" -AsPlainText -Force
$SQLAgtServiceAccount = New-Object System.Management.Automation.PSCredential ("SLLab\SQL-SVC", $SecurePassword)

$SecurePassword = ConvertTo-SecureString -String "PFd_otm00n!" -AsPlainText -Force
$SQLSAAccount = New-Object System.Management.Automation.PSCredential ("SA", $SecurePassword)

$SQL2012StandardPID ="YFC4R-BRRWB-TVP9Y-6WJQ9-MCJQ7"
$SQL2012EnterprisePID ="748RB-X4T6B-MRM7V-RTVFF-CHC8H"
$SQL2012DeveloperPID = "YQWTX-G8T4R-QW4XX-BVH62-GP68Y"
$SQL2014StandardPID ="P7FRV-Y6X6Y-Y8C6Q-TB4QR-DMTTK"
$SQL2014DeveloperPID = ""


$ConfigurationData = @{
    AllNodes = @(
        @{
            NodeName = "*"

            SourcePath = "\\admin05\Installer$"
            InstallerServiceAccount = $InstallerServiceAccount
            LocalSystemAccount = $LocalSystemAccount

            SecurityMode = "SQL"
            SAPwd = $SQLSAAccount
            PSDscAllowDomainUser = $true

        }

        
        @{
            NodeName = "sql06"
            SQLAdmins = ("SLLab\SQL-Admins")
            SQLServiceAccount = $SQLServiceAccount 
            SqlAgtServiceAccount = $SQLAgtServiceAccount
            PID = $SQL2014StandardPID
            UpdateSource = ".\updates"

            PSDscAllowPlainTextPassword = $true
            Roles = @(
                "SQL 2014 Database Server"
            )
            SQLServers = @(
                @{
                    Features = "SQLENGINE,FULLTEXT,SSMS,ADV_SSMS"
                    Roles = @(
                        "SQL 2014 Database Server"
                    )
                    InstanceName = "MSSQLSERVER"
                }
            )
        }

    )
}

foreach($Node in $ConfigurationData.AllNodes)
{
    if($Node.NodeName -ne "*")
    {
        Start-Process -FilePath "robocopy.exe" -ArgumentList ("`"C:\Program Files\WindowsPowerShell\Modules`" `"\\" + $Node.NodeName + "\c$\Program Files\WindowsPowerShell\Modules`" /e /purge /xf") -NoNewWindow -Wait

    }
}

$ConfigurationPath = "D:\temp\sqlsa"

if (test-path $ConfigurationPath) {Remove-item $ConfigurationPath -recurse -force}

SQLSA -ConfigurationData $ConfigurationData -OutputPath $ConfigurationPath

Set-DscLocalConfigurationManager -Path $ConfigurationPath -Verbose

Start-DscConfiguration -Path $ConfigurationPath -Verbose -Wait -Force



foreach($Node in $ConfigurationData.AllNodes)
{
    if($Node.NodeName -ne "*")
    {
#        Test-DscConfiguration -ComputerName $node.nodename -Verbose


    }
}

