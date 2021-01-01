<#
    .SYNOPSIS
        AlexK build tools.
    .DESCRIPTION
        This module contains functions to service powershell build process. Linter, functional test runner, script updater, comment base help generator, function change log generator and etc.
        Use inside AlexkFramework.
    .COMPONENT
        AlexKUtils
    .LINK
        https://github.com/Alex-0293/AlexKBuildTools.git
    .NOTES
        AUTHOR  Alexk
        CREATED 29.10.20
        MOD     05.11.20
        VER     7
#>


Function New-ModuleMetaData {
<#
    .SYNOPSIS
        New module meta data
    .DESCRIPTION
        Create new module metadata file (*.psd1).
    .EXAMPLE
        New-ModuleMetaData -FilePath $FilePath -AuthorName $AuthorName -AuthorEmail $AuthorEmail -License $License [-Description $Description] [-RequiredModules $RequiredModules] [-Tags $Tags] [-LogPath $LogPath=$Global:gsScriptLogFilePath] [-PassThru $PassThru]
    .NOTES
        AUTHOR  Alexk
        CREATED 08.04.20
        VER     1
#>
        [OutputType([bool])]
        [CmdletBinding()]
        Param (
            [Parameter( Mandatory = $true, Position = 0, HelpMessage = "Full path to module file." )]
            [ValidateNotNullOrEmpty()]
            [string] $FilePath,
            [Parameter( Mandatory = $true, Position = 1, HelpMessage = "Module author." )]
            [ValidateNotNullOrEmpty()]
            [string] $AuthorName,
            [Parameter( Mandatory = $true, Position = 2, HelpMessage = "Module author email." )]
            [ValidateNotNullOrEmpty()]
            [string] $AuthorEmail,
            [Parameter( Mandatory = $false, Position = 3, HelpMessage = "Module description." )]
            [string] $Description,
            [Parameter( Mandatory = $true, Position = 4, HelpMessage = "Module license." )]
            [ValidateSet("Apache 2.0")]
            [string] $License,
            [Parameter( Mandatory = $false, Position = 5, HelpMessage = "Exported functions array." )]
            [array] $RequiredModules,
            [Parameter( Mandatory = $false, Position = 6, HelpMessage = "Tags." )]
            [array] $Tags,
            [Parameter( Mandatory = $false, Position = 7, HelpMessage = "Log file path." )]
            [string] $LogPath = $Global:gsScriptLogFilePath,
            [Parameter( Mandatory = $false, Position = 8, HelpMessage = "Return object." )]
            [switch] $PassThru
        )

        $res = $false

        $FileExt     = Split-Path -path $FilePath -Extension

        if ( $FileExt -eq ".psm1" ) {
            $Location = Split-Path -path $FilePath
        }
        Else {
            $Location = Split-Path -path (Split-Path -path $FilePath -Parent) -parent
        }

        $BaseFileName = Split-Path -path $FilePath -LeafBase
        $FileExt      = Split-Path -path $FilePath -Extension

        if ( !(Get-ChildItem -path $Location -File -Filter "*.psd1") ){
            if ( $FileExt -eq ".psm1" ) {
                import-module -name $BaseFileName -force
                $Module = get-module -name $BaseFileName
            }
            if ( $Module ) {
                Add-ToLog -Message "Starting module [$($Module.name)] metadata creating."  -logFilePath $LogPath -Display -Status "info"

                switch ( $license ) {
                    "Apache 2.0" {
                        $Copyright = "Copyright (c) $AuthorName($AuthorEmail) $(get-date -Format "yyyy"), licensed under Apache 2.0 License."
                        $LicenseUri = "http://www.apache.org/licenses/LICENSE-2.0.html"
                    }
                    Default {
                        $Copyright = "(c) $AuthorName($AuthorEmail) $(get-date -Format "yyyy"). All rights reserved."
                    }
                }

                $RequiredModulesArray = @()
                $RequiredOriginArray  = @()

                $ModuleParameters = @{}

                $ModuleParameters += @{ Path               = "$Location\$BaseFileName.psd1" }
                $ModuleParameters += @{ ModuleVersion              = "0.0.0.1" }
                $ModuleParameters += @{ Author                     = $AuthorName }
                $ModuleParameters += @{ PowerShellVersion          = $PSVersionTable.PSVersion }
                $ModuleParameters += @{ ClrVersion                 = $PSVersionTable.CLRVersion }
                $ModuleParameters += @{ DotNetFrameworkVersion     = $PSVersionTable.DotNetFrameworkVersion }
                $ModuleParameters += @{ RootModule                 = "$BaseFileName.psm1" }
                $ModuleParameters += @{ Copyright                  = $Copyright }
                $ModuleParameters += @{ FunctionsToExport          = '*' }
                $ModuleParameters += @{ CmdletsToExport            = '*' }
                $ModuleParameters += @{ VariablesToExport          = '*' }
                $ModuleParameters += @{ AliasesToExport            = '*' }
                $ModuleParameters += @{ GUID                       = New-Guid }
                $ModuleParameters += @{ Description                = $Description }
                $ModuleParameters += @{ ProjectUri                 = Get-ProjectOrigin -FilePath $FilePath }
                foreach ( $item in $RequiredModules ){
                    $RequiredModulesArray += $item.Module
                    $RequiredOriginArray  += Get-ProjectOrigin -FilePath  ( get-module $item.module ).path
                }
                if ( $RequiredModules ){
                    $ModuleParameters += @{ RequiredModules            = ( $RequiredModulesArray -join ", " ) }
                    $ModuleParameters += @{ ExternalModuleDependencies = $RequiredOriginArray }
                }
                if ( $LicenseUri ){
                    $ModuleParameters += @{ LicenseUri             = $LicenseUri }
                }
                if ( $tags ){
                    if ( !('powershell' -in $tags) ){
                        $tags += 'powershell'
                    }
                    if ( !('AlexK' -in $tags) ){
                        $tags += 'AlexK'
                    }
                    $ModuleParameters += @{ Tags                   = $Tags }
                }


                New-ModuleManifest @ModuleParameters
                Add-ToLog -Message "Module [$($Module.name)] successfully created."  -logFilePath $LogPath -Display -Status "info"
                $res = $true
            }
            Else {
                Add-ToLog -Message "Module [$($Module.name)] not found."  -logFilePath $LogPath -Display -Status "warning"
            }
        }
        Else {
            Add-ToLog -Message "Module [$($Module.name)] manifest already exist."  -logFilePath $LogPath -Display -Status "warning"
        }
        if ( $PassThru ){
            return $res
        }
}
function Get-FunctionDetails {
<#
    .SYNOPSIS
        Get function details
    .DESCRIPTION
        Get AST function detail.
    .EXAMPLE
        Get-FunctionDetails -FilePath $FilePath
    .NOTES
        AUTHOR  Alexk
        CREATED 02.11.20
        VER     1
#>
    [CmdletBinding()]
    [OutputType([PsObject])]
    param (
        [Parameter( Mandatory = $true, Position = 0, HelpMessage = "Powershell file path." )]
        [ValidateNotNullOrEmpty()]
        [string] $FilePath
    )

    function Get-AttributeDetails {
    <#
        .SYNOPSIS
            Get attribute details
        .DESCRIPTION
            Internal. Get function AST attribute detail.
        .EXAMPLE
            Get-AttributeDetails [-Attributes $Attributes]
        .NOTES
            AUTHOR  Alexk
            CREATED 02.11.20
            VER     1
    #>
        [CmdletBinding()]
        param (
            $Attributes
        )

        $Res = @()
        foreach ( $Item in $Attributes ) {
            switch ( $Item.TypeName ) {
                "Parameter" {
                    foreach ( $Item1 in $Item.NamedArguments ) {
                        $PSO = [PSCustomObject]@{
                            TypeName          = $Item.TypeName
                            ArgumentName      = $Item1.ArgumentName
                            Argument          = $Item1.Argument
                            ExpressionOmitted = $Item1.ExpressionOmitted
                        }
                        $Res += $PSO
                    }
                }
                "ValidateSet" {
                    $PSO = [PSCustomObject]@{
                        TypeName          = $Item.TypeName
                        Value             = $Item.PositionalArguments
                    }
                    $Res += $PSO
                }
                "ValidateNotNullOrEmpty" {
                    $PSO = [PSCustomObject]@{
                        TypeName          = $Item.TypeName
                    }
                    $Res += $PSO
                }
                "ValidateNotNull" {
                    $PSO = [PSCustomObject]@{
                        TypeName          = $Item.TypeName
                    }
                    $Res += $PSO
                }
                "CmdletBinding" {
                    $PSO = [PSCustomObject]@{
                        TypeName          = $Item.TypeName
                    }
                    $Res += $PSO
                }
                "OutputType" {
                    $PSO = [PSCustomObject]@{
                        TypeName          = $Item.TypeName
                        Value             = $Item.PositionalArguments
                    }
                    $Res += $PSO
                }
                Default {
                    $PSO = [PSCustomObject]@{
                        TypeName          = $Item.TypeName
                    }
                    $Res += $PSO
                }
            }
        }

        Return $Res
    }
    function Get-ParameterDetails {
    <#
        .SYNOPSIS
            Get parameter details
        .DESCRIPTION
            Internal. Get function AST parameter detail.
        .EXAMPLE
            Get-ParameterDetails [-Parameters $Parameters]
        .NOTES
            AUTHOR  Alexk
            CREATED 02.11.20
            VER     1
    #>
        [CmdletBinding()]
        param (
            $Parameters
        )

        $res = @()
        foreach ( $Item in $Parameters ) {
            $ParamAttribute = Get-AttributeDetails -Attributes $Item.Attributes
            $PSO = [PSCustomObject]@{
                Name         = $Item.name
                DefaultValue = $Item.DefaultValue
                StaticType   = $Item.StaticType
            }
            foreach ( $Attribute in $ParamAttribute ){
                switch ( $Attribute.TypeName ) {
                    "Parameter" {
                        $PSO | Add-Member -NotePropertyName $Attribute.ArgumentName -NotePropertyValue $Attribute.Argument
                    }
                    "ValidateSet" {
                        $PSO | Add-Member -NotePropertyName $Attribute.TypeName -NotePropertyValue $Attribute.Value
                    }
                    "ValidateNotNullOrEmpty" {
                        $PSO | Add-Member -NotePropertyName $Attribute.TypeName -NotePropertyValue $Attribute.TypeName
                    }

                    Default {
                        if ( $Attribute.TypeName.name -ne "psobject") {
                            $PSO | Add-Member -NotePropertyName $Attribute.TypeName.name -NotePropertyValue $Attribute.TypeName.name
                        }
                        Else {
                            $PSO | Add-Member -NotePropertyName "psobject1" -NotePropertyValue "psobject"
                        }
                    }
                }
            }

            $res += $PSO
        }
        Return $Res
    }
    function Get-HelpContent {
    <#
        .SYNOPSIS
            Get help content
        .DESCRIPTION
            Internal. Get function AST help content.
        .EXAMPLE
            Get-HelpContent [-Function $Function]
        .NOTES
            AUTHOR  Alexk
            CREATED 02.11.20
            VER     1
    #>
        [CmdletBinding()]
        param (
            $Function
        )

        $HelpContent = $Function.GetHelpContent()

        Return $HelpContent
    }

    $VarToken = $Null
    $VarError = $Null

    $Ast = [System.Management.Automation.Language.Parser]::ParseFile( $FilePath, [ref] $VarToken , [ref] $VarError )

    $Res = $Ast.FindAll({ $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true )

    $FunctionArray = @()

    foreach ( $Item in $Res ){
        $FuncParam  = Get-ParameterDetails -Parameters $Item.body.ParamBlock.Parameters
        $FuncAttrib = Get-AttributeDetails -Attributes $Item.body.ParamBlock.Attributes
        $FuncHelp   = Get-HelpContent      -Function $Item
        $PSO        = [PSCustomObject]@{
            FunctionName        = [string] $Item.Name
            ParentFunctionName  = ""
            StartLineNumber     = [int] $Item.extent.StartLineNumber
            EndLineNumber       = [int] $Item.extent.EndLineNumber
            StartColumnNumber   = [int] $Item.extent.StartColumnNumber
            EndColumnNumber     = [int] $Item.extent.EndColumnNumber
            LineCount           = [long] ($Item.extent.EndLineNumber - $Item.extent.StartLineNumber)
            Parameters          = $FuncParam
            Attributes          = $FuncAttrib
            HelpContent         = $FuncHelp
            Description         = $FuncHelp.Description
            Examples            = $FuncHelp.Examples
            Text                = [string[]] $Item.extent.text
            IsNew               = [bool] $false
            IsChanged           = [bool] $false
        }

        foreach ( $Line in $PSO.Text ){
            $Line = $Line.trim()
        }

        $FunctionArray += $PSO
    }
    $FunctionArray = $FunctionArray | Sort-Object "StartLineNumber"

    if ( $FunctionArray.count -gt 1 ){
        foreach ( $Item in ( 1..( $FunctionArray.count ) ) ){
            foreach ( $Item1 in ( 1..$item ) ){
                if ( ( $FunctionArray[$item].StartLineNumber -gt  $FunctionArray[($item1)].StartLineNumber ) -and ( $FunctionArray[$item].EndLineNumber -lt  $FunctionArray[($item1)].EndLineNumber ) ){
                    $FunctionArray[$item].ParentFunctionName = $FunctionArray[($item1)].FunctionName
                }
            }
        }
    }
    return $FunctionArray #| Sort-Object ParentFunctionName , FunctionName -Descending
}
Function Get-FunctionChanges {
<#
    .SYNOPSIS
        Get function changes
    .DESCRIPTION
        Get changes between two functions.
    .EXAMPLE
        Get-FunctionChanges [-Functions $Functions] [-PrevFunctions $PrevFunctions]
    .NOTES
        AUTHOR  Alexk
        CREATED 02.11.20
        VER     1
#>
    [OutputType([PsObject])]
    [CmdletBinding()]
    param (
        [Parameter( Mandatory = $false, Position = 0, HelpMessage = "Function to compare." )]
        [PsObject] $Functions,
        [Parameter( Mandatory = $false, Position = 1, HelpMessage = "Function to compare." )]
        [PsObject] $PrevFunctions
    )

    Function Test-Changes {
    <#
        .SYNOPSIS
            Test changes
        .DESCRIPTION
            Internal. Test function parameter and attribute changes.
        .EXAMPLE
            Test-Changes -Function $Function -PrevFunction $PrevFunction
        .NOTES
            AUTHOR  Alexk
            CREATED 04.11.20
            VER     1
    #>
        [OutputType([PsObject])]
        Param (
            [Parameter( Mandatory = $true, Position = 0, HelpMessage = "Function to compare." )]
            [ValidateNotNullOrEmpty()]
            [PsObject] $Function,
            [Parameter( Mandatory = $true, Position = 1, HelpMessage = "Function to compare." )]
            [ValidateNotNullOrEmpty()]
            [PsObject] $PrevFunction
        )

        $Changed = @()
        $Attributes = @()
        $Parameters = @()

        foreach ( $Item in $PrevFunction.Parameters ) {
            foreach ( $Item1 in $Function.Parameters ) {
                [string[]]$ChangedString = @()
                $PrevParamName = $Item.name.Extent.Text
                $ParamName     = $Item1.name.Extent.Text
                if ( $PrevParamName -eq $ParamName ){
                    $ChangedString = @()
                    [string[]]$Parameters  = $Item1.psobject.Properties.name
                    $Parameters += $Item.psobject.Properties.name
                    $Parameters = $Parameters | Select-Object -Unique

                    foreach ( $Parameter in $Parameters ) {
                        if ( $Item.$Parameter.extent.text -ne $Item1.$Parameter.extent.text ){
                            if ( $Parameter -ne $Item1.$Parameter.extent.text ){
                                $ChangedString += "$Parameter [$($Item.$Parameter.extent.text)->$($Item1.$Parameter.extent.text)]"
                            }
                            Else{
                                $ChangedString += "$Parameter [$($Item.$Parameter.extent.text)->`$true]"
                            }
                        }
                    }
                    if ( $ChangedString.count ) {
                        $Changed += "[$($Item1.StaticType.name)] $ParamName ( $($ChangedString -join ", ") )"
                    }
                }
            }
        }

        [string[]]$ChangedString = @()
        [string[]]$AddString = @()
        [string[]]$RemString = @()
        if ( !$PrevFunction.Attributes -and $Function.Attributes ){
            foreach ( $Item1 in $Function.Attributes ) {
                if ( $Item1.value.extent.text ) {
                    $AttribName     = $Item1.TypeName.Extent.Text
                    $AddString += "$AttribName  [->$($Item1.value.extent.text)]"
                }
                Else {
                    $AddString += "->$PrevAttribName"
                }
            }

        }
        foreach ( $Item in $PrevFunction.Attributes ) {
            $PrevAttribName = $Item.TypeName.Extent.Text
            if ( !$Function.Attributes -and $PrevFunction.Attributes ){
                if ( $Item.value.extent.text ) {
                    $RemString += "$PrevAttribName [$($Item.value.extent.text)->]"
                }
                Else {
                    $RemString += "$PrevAttribName->"
                }
            }
            foreach ( $Item1 in $Function.Attributes ) {
                $AttribName     = $Item1.TypeName.Extent.Text

                if  ( $PrevAttribName -notin $Function.Attributes.TypeName.Extent.Text ) {
                    if ( $Item.value.extent.text ) {
                        $RemString += "$PrevAttribName [$($Item.value.extent.text)->]"
                    }
                    Else {
                        $RemString += "$PrevAttribName->"
                    }
                }
                if  ( $AttribName -notin $PrevFunction.Attributes.TypeName.Extent.Text ) {
                    if ( $Item1.value.extent.text ) {
                        $AttribName     = $Item1.TypeName.Extent.Text
                        $AddString += "$AttribName  [->$($Item1.value.extent.text)]"
                    }
                    Else {
                        $AddString += "->$PrevAttribName"
                    }
                }
                if ( ($PrevAttribName -eq $AttribName) -and ( $Item.value.extent.text ) ){
                    $ChangedString = @()
                    if ( $Item.value.extent.text -ne $Item1.value.extent.text ){
                        $ChangedString += "$AttribName [$($Item.value.extent.text)->$($Item1.value.extent.text)]"
                    }
                }
                if ( $ChangedString.count ) {
                    $Changed += "$($ChangedString -join ", ")"
                    [string[]]$ChangedString = @()
                }
            }
        }

        if ( $RemString.count ) {
            $Rem = "$($RemString -join ", ")"
        }
        if ( $AddString.count ) {
            $Add = "$($AddString -join ", ")"
        }

        $PSO = [PSCustomObject]@{
            Changed = $Changed
            Add     = $Add
            Rem     = $Rem
        }

        return $PSO
    }

    if ( $PrevFunctions ) {
        if ( $Functions ) {
            $DeletedFunctions = $PrevFunctions | Where-Object { $_.name -notin $Functions.Name }
            $AddedFunctions   = $Functions     | Where-Object { $_.name -notin $PrevFunctions.Name }
        }
        Else {
            $DeletedFunctions = $PrevFunctions
            $AddedFunctions   = @()
        }
    }
    Else {
        if ( $Functions ) {
            $AddedFunctions   = $Functions
            $DeletedFunctions = @()
        }
        Else {
            $AddedFunctions   = @()
            $DeletedFunctions = @()
        }
    }

    if ( $Functions ) {
        $AddedFunctions   = $Functions
    }

    foreach ( $Item in $AddedFunctions ){
        $Item.IsNew = $true
    }

    $ChangesArray = @()

    if ( $PrevFunctions -and $Functions ) {


        foreach ( $Function in $Functions ){
            foreach ( $PrevFunction in $PrevFunctions ){
                if ( ( $Function.FunctionName -eq $PrevFunction.FunctionName ) -and ( $Function.ParentFunctionName -eq $PrevFunction.ParentFunctionName ) ){
                    If ( $Function.text.trim() -ne $PrevFunction.text.trim() ){
                        if  ( $Function.FunctionName -notin $ChangesArray.FunctionName ) {
                            $PSO = [PSCustomObject]@{
                                ParentFunctionName = $Function.ParentFunctionName
                                FunctionName       = $Function.FunctionName
                            }

                            if ( $Function.LineCount -ne  $PrevFunction.LineCount ){
                                $PSO | Add-Member -NotePropertyName LineDiff -NotePropertyValue ($Function.LineCount - $PrevFunction.LineCount)
                                $PSO | Add-Member -NotePropertyName LineCount -NotePropertyValue $Function.LineCount
                                $PSO | Add-Member -NotePropertyName PrevLineCount -NotePropertyValue $PrevFunction.LineCount
                            }
                            if ( $Function.Parameters -ne  $PrevFunction.Parameters ){
                                $Add = @()
                                foreach ( $Item in $Function.Parameters ) {
                                    $ParamName = $Item.name.Extent.Text
                                    if ( !( $ParamName -in $PrevFunction.Parameters.name.Extent.Text ) ){
                                        if ( $Item.DefaultValue ){
                                            $Add += "[$($Item.StaticType)] $ParamName = $($Item.DefaultValue)"
                                        }
                                        Else{
                                            $Add += "[$($Item.StaticType)] $ParamName"
                                        }
                                    }
                                }
                                $Rem = @()
                                foreach ( $Item in $PrevFunction.Parameters ) {
                                    $ParamName = $Item.name.Extent.Text
                                    if ( !( $ParamName -in $Function.Parameters.name.Extent.Text ) ){
                                        $Rem += "[$($Item.StaticType)] $ParamName"
                                    }
                                }
                                $Changed = @()
                                $Changed = Test-Changes -PrevFunction $PrevFunction -Function $Function

                                if ( $Add ) {
                                    $PSO | Add-Member -NotePropertyName "ParametersAdd" -NotePropertyValue $Add
                                }
                                if ( $Rem ) {
                                    $PSO | Add-Member -NotePropertyName "ParametersRemove" -NotePropertyValue $Rem
                                }
                                if ( $Changed ) {
                                    if ( $Changed.Changed ){
                                        $PSO | Add-Member -NotePropertyName "ParametersChanged" -NotePropertyValue $Changed.Changed
                                    }
                                    if ( $Changed.Add ){
                                        $PSO | Add-Member -NotePropertyName "AttributesAdded" -NotePropertyValue $Changed.Add
                                    }
                                    if ( $Changed.Rem ){
                                        $PSO | Add-Member -NotePropertyName "AttributesRemoved" -NotePropertyValue $Changed.Rem
                                    }
                                    $Function.IsChanged =  $true
                                }

                                if ( $Add -or $Rem -or $Changed ) {
                                    $PSO | Add-Member -NotePropertyName "Parameters"     -NotePropertyValue $Function.Parameters
                                    $PSO | Add-Member -NotePropertyName "PrevParameters" -NotePropertyValue $PrevFunction.Parameters

                                }
                            }
                            if ( ( $PSO.psobject.Properties | Measure-Object ).count -gt 2 ){
                                $ChangesArray       += $PSO
                            }
                        }
                    }
                }
            }
        }
    }


    $Res = [PSCustomObject]@{
        Added             = $AddedFunctions
        Deleted           = $DeletedFunctios
        ChangedFunctions  = $ChangesArray
        FunctionList      = $Functions
    }

    return $res
}
function Get-CommitInfo {
<#
    .SYNOPSIS
        Get commit info
    .DESCRIPTION
        Get last git commit info.
    .EXAMPLE
        Get-CommitInfo -FilePath $FilePath
    .NOTES
        AUTHOR  Alexk
        CREATED 02.11.20
        VER     1
#>
    [OutputType([PsObject])]
    [CmdletBinding()]
    param (
        [Parameter( Mandatory = $true, Position = 0, HelpMessage = "Powershell file path." )]
        [ValidateNotNullOrEmpty()]
        [string] $FilePath
    )
    $FileExt     = Split-Path -path $FilePath -Extension

    if ( $FileExt -eq ".psm1" ) {
        $Location = Split-Path -path $FilePath
    }
    Else {
        $Location = Split-Path -path (Split-Path -path $FilePath -Parent) -parent
    }

    $FileName = Split-Path -path $FilePath -Leaf

    Set-Location -path $Location


    $GitConsoleData = & git log --name-only

    $CommitCounter = 0
    $lineCounter = 0
    foreach ( $Line in $GitConsoleData ){
        if ( $line.contains("commit ") ){
            $CommitCounter++
        }
        if ( $CommitCounter -eq 2 ){
            $GitData = $GitConsoleData[0..($lineCounter - 1)]
            break
        }
        $lineCounter++
    }
    if ( $CommitCounter -eq 1 ){
        $GitData = $GitConsoleData
    }

    foreach ( $Line in $GitData ) {
        switch -wildcard ( $Line ) {
            "commit*" {
                $Commit = $Line.split(" ")[1].Trim()
            }
            "Merge*" {
                $Merge = $Line.split(" ")[1].Trim()
            }
            "Author*" {
                $Author = $Line.split(" ")[1].Trim()
            }
            "Date*" {
                $Date = ($Line.split(" ") | Select-Object -last 6) -join " "
            }
            Default {
                if ( $Line.trim() -ne $Line ){
                    if ( $line -like "    *" ){
                        $Message = $line.trim()
                    }
                }
            }
        }
    }
    $ModifiedData  = @()
    if ( $Message ) {
        $Start = $GitData | Select-String -Pattern $Message
    }
    $Modified = $GitData[($Start.LineNumber)..($GitData.count-1)]
    foreach ( $line in $Modified ){
        if ( $line.Trim() ) {
            $ModifiedData += $line.Trim()
        }
    }
    $LastCommitData = [PSCustomObject]@{
        Hash     = $Commit
        Merge    = $Merge
        Author   = $Author
        Date     = $Date
        Modified = $ModifiedData
        Message  = $Message
    }

    Return $LastCommitData
}
function Get-ChangeLog {
<#
    .SYNOPSIS
        Get change log
    .DESCRIPTION
        Get changes between two functions and save to log file.
    .EXAMPLE
        Get-ChangeLog -FilePath $FilePath [-LogFileName $LogFileName] [-SaveLog $SaveLog] [-LogPath $LogPath=$Global:gsScriptLogFilePath]
    .NOTES
        AUTHOR  Alexk
        CREATED 02.11.20
        VER     1
#>
    [OutputType([PsObject],[AllowNull])]
    [CmdletBinding()]
    param (
        [Parameter( Mandatory = $true, Position = 0, HelpMessage = "Powershell file path." )]
        [ValidateNotNullOrEmpty()]
        [string] $FilePath,
        [Parameter( Mandatory = $false, Position = 1, HelpMessage = "Path to save log file" )]
        [string] $LogFileName,
        [Parameter( Mandatory = $false, Position = 2, HelpMessage = "Save log to file." )]
        [switch] $SaveLog,
        [Parameter( Mandatory = $false, Position = 3, HelpMessage = "Common log file path." )]
        [string] $LogPath = $Global:gsScriptLogFilePath
    )

    function Invoke-DataFormat {
    <#
        .SYNOPSIS
            Invoke data format
        .DESCRIPTION
            Internal. Format data.
        .EXAMPLE
            Invoke-DataFormat -Data $Data
        .NOTES
            AUTHOR  Alexk
            CREATED 02.11.20
            VER     1
    #>
        [OutputType([PsObject])]
        [CmdletBinding()]
        param (
            [Parameter( Mandatory = $true, Position = 0, HelpMessage = "String to format." )]
            [string[]] $Data
        )

        $NewData = @()

        if ( $Data.count -gt 1 ) {
            $PSO = [PSCustomObject]@{
                Typelen  = 0
                VarLen   = 0
            }

            foreach ( $Item in $data ){
                $Array1  = $Item.split("(")
                $Array2  = $Array1[0].split(" ")
                $TypeLen = $Array2[0].length
                $VarLen  = $Array2[1].length

                if ( $TypeLen -gt $PSO.Typelen ){
                    $PSO.Typelen = $TypeLen
                }
                if ( $VarLen -gt $PSO.VarLen ){
                    $PSO.VarLen = $VarLen
                }
            }

            foreach ( $Item in $data ){
                $Array1  = $Item.split("(")
                $Array2  = $Array1[0].split(" ")

                $Type  = [string]$Array2[0]
                $Var   = [string]$Array2[1]
                if ( $Array1.count -eq 2 ) {
                    $Other = [string]$Array1[1]
                    $Item = $Type.PadRight($PSO.Typelen, " ") + " " + $Var.PadRight($PSO.VarLen, " ") + " (" + $Other
                }
                Else {
                    $Item = $Type.PadRight($PSO.Typelen, " ") + " " + $Var
                }
                $NewData += $item

            }
        }
        if ( $NewData ) {
            Return $NewData
        }
        Else {
            Return $Data
        }
    }
    $FileExt     = Split-Path -path $FilePath -Extension

    if ( $FileExt -eq ".psm1" ) {
        $Location = Split-Path -path $FilePath
        $FileName = Split-Path -path $FilePath -Leaf
        $PrevFile = "$Location\tmp.prev.$FileName"
    }
    Else {
        $Location = Split-Path -path (Split-Path -path $FilePath -Parent) -parent

        $FileName = "$($Global:gsSCRIPTSFolder)\$(Split-Path -path $FilePath -Leaf)"
        $PrevFile = "$Location\$($Global:gsSCRIPTSFolder)\tmp.prev.$(Split-Path -path $FilePath -Leaf)"
    }


    Set-Location -path $Location

    $LastCommitData    = Get-CommitInfo -FilePath $FilePath
    $LastGitCommitHash = $LastCommitData.Hash


    if ( $LastGitCommitHash ) {
        Add-ToLog -Message "Getting change log for [$FilePath] and previous version [$($LastCommitData.Date)] with commit message [$($LastCommitData.Message)]." -logFilePath $LogPath -Display -Status "info"
        $Prev = ( & git show "$LastGitCommitHash`:./$FileName" )
        out-file -FilePath $PrevFile -InputObject $Prev
        $PrevFunctionDetails = Get-FunctionDetails $PrevFile
        $FunctionDetails     = Get-FunctionDetails $FilePath

        Remove-Item -Path $PrevFile -force

        $Changes = Get-FunctionChanges -Functions $FunctionDetails -PrevFunctions $PrevFunctionDetails

        if ( $Changes ) {
            Add-ToLog -Message "Got change log."  -logFilePath $LogPath -Display -Status "info"
            [string[]] $Log = ""
            $Log = "Changes $(Get-date -format "dd.MM.yy hh:mm:ss")"
            $Log += "================"
            $Log += ""
            if ( $Changes.Added ) {
                $Log += "Added functions:"
                foreach ( $Item in $Changes.Added ){
                    if ( $Item.ParentFunctionName ){
                        $Log += "   Function: $($Item.ParentFunctionName)\$($Item.FunctionName)"
                    }
                    Else {
                        $Log += "   Function: $($Item.FunctionName)"
                    }
                }
            }
            if ( $Changes.Deleted ) {
                $Log += "Removed functions:"
                foreach ( $Item in $Changes.Deleted ){
                    if ( $Item.ParentFunctionName ){
                        $Log += "   Function: $($Item.ParentFunctionName)\$($Item.FunctionName)"
                    }
                    Else {
                        $Log += "   Function: $($Item.FunctionName)"
                    }
                }
            }
            if ( $Changes.ChangedFunctions ) {
                $Log += "Changed functions:"
                foreach ( $Item in $Changes.ChangedFunctions ){
                    if ( $Item.ParentFunctionName ){
                        $Log += "   Function: $($Item.ParentFunctionName)\$($Item.FunctionName)"
                    }
                    Else {
                        $Log += "   Function: $($Item.FunctionName)"
                    }
                    If ( $Item.LineDiff ){
                        $Log += "       Line difference [$($Item.LineDiff)]"
                    }
                    If ( $Item.ParametersAdd -or $Item.ParametersRemove -or $Item.ParametersChanged ){
                        If ( $Item.ParametersRemove ){
                            $Data = Invoke-DataFormat -Data $Item.ParametersRemove
                            $Log += "       - Removed parameters"
                            foreach ( $Item1 in $Data ){
                                    $Log += "                $($Item1.trim())"
                            }
                        }
                        If ( $Item.ParametersAdd ){
                            $Data = Invoke-DataFormat -Data $Item.ParametersAdd
                            $Log += "       - Add parameters"
                            foreach ( $Item1 in $Data ){
                                    $Log += "                $($Item1.trim())"
                            }
                        }
                        If ( $Item.ParametersChanged ){
                            $Data = Invoke-DataFormat -Data $Item.ParametersChanged
                            $Log += "       - Changed parameters"
                            foreach ( $Item1 in $Data ){
                                    $Log += "                $($Item1.trim())"
                            }
                        }

                        $Log += ""
                    }
                }
            }
            if ( $SaveLog ){
                if ( !$LogFileName ){
                    $LogPathParent = Split-Path -path $LogPath -Parent
                    $LogFileName   = "$LogPathParent\Changes.log"
                }

                Out-File -FilePath $LogFileName -InputObject $Log -force
                Add-ToLog -Message "Saved log file [$LogFileName]" -logFilePath $LogPath -Display -Status "info"
            }
            return $Changes
        }
        Else {
            Add-ToLog -Message "No changes detected."  -logFilePath $LogPath -Display -Status "info"
        }
    }
}
function Get-ModuleVersion {
<#
    .SYNOPSIS
        Get module version
    .DESCRIPTION
        Get script or module version.
    .EXAMPLE
        Get-ModuleVersion -FilePath $FilePath
    .NOTES
        AUTHOR  Alexk
        CREATED 02.11.20
        VER     1
#>
    [OutputType([PsObject],[AllowNull])]
    [CmdletBinding()]
    param(
        [Parameter( Mandatory = $true, Position = 0, HelpMessage = "Powershell file path." )]
        [ValidateNotNullOrEmpty()]
        [string] $FilePath
    )

    # Version number of this module.
    # Version A.B.C.D
    # A<1 Beta, A>1 release
    # B Add/remove functions
    # C build
    # D revision

    $FileExt     = Split-Path -path $FilePath -Extension

    if ( $FileExt -eq ".psm1" ) {
        $Location = Split-Path -path $FilePath
    }
    Else {
        $Location = Split-Path -path (Split-Path -path $FilePath -Parent) -parent
    }
    $FileName = Split-Path -path $FilePath -LeafBase

    switch ( $FileExt.ToLower() ) {
        ".psm1" {
            $Res = (import-Module -Name $FileName -PassThru).Version
            # $PSDFilePath = "$Location\$FileName.psd1"
            # $Content     = Get-Content -Path $PSDFilePath
            # foreach ( $line in $Content ) {

            # }

        }
        Default {}
    }
    Return $Res
}
Function Start-FunctionTest {
<#
    .SYNOPSIS
        Start function test
    .DESCRIPTION
        Start Pester function test.
    .EXAMPLE
        Start-FunctionTest -FilePath $FilePath [-LogFileName $LogFileName] [-SaveLog $SaveLog] [-LogPath $LogPath=$Global:gsScriptLogFilePath]
    .NOTES
        AUTHOR  Alexk
        CREATED 02.11.20
        VER     1
#>
    [OutputType([bool])]
    [CmdletBinding()]
    param (
        [Parameter( Mandatory = $true, Position = 0, HelpMessage = "Powershell file path." )]
        [ValidateNotNullOrEmpty()]
        [string] $FilePath,
        [Parameter( Mandatory = $false, Position = 1, HelpMessage = "Path to save log file" )]
        [string] $LogFileName,
        [Parameter( Mandatory = $false, Position = 2, HelpMessage = "Save log to file." )]
        [switch] $SaveLog,
        [Parameter( Mandatory = $false, Position = 3, HelpMessage = "Common log file path." )]
        [string] $LogPath = $Global:gsScriptLogFilePath
    )

    $FileExt     = Split-Path -path $FilePath -Extension

    if ( $FileExt -eq ".psm1" ) {
        $Location = Split-Path -path $FilePath
    }
    Else {
        $Location = Split-Path -path (Split-Path -path $FilePath -Parent) -parent
    }
    $File     = split-path -Path $FilePath -LeafBase

    # import module before creating the object
    Import-Module Pester
    # get default from static property
    $configuration = [PesterConfiguration]::Default
    # assing properties & discover via intellisense
    $configuration.Run.Path                  = "$Location\$($Global:gsTESTSFolder)\$File.tests.ps1"
    $configuration.Run.Exit                  = $true
    $configuration.Run.PassThru              = $true
    #$configuration.CodeCoverage.OutputPath   = "$Location\$($Global:gsTESTSFolder)\$File.tests.coverage.xml"
    #$configuration.CodeCoverage.Enabled      = $true
    #$configuration.CodeCoverage.OutputFormat = "NUnitXml"
    #$configuration.CodeCoverage.Path         = $FilePath
    $configuration.Should.ErrorAction        = 'Continue'
    $configuration.Output.Verbosity          = "Detailed"
    # $configuration.TestResult.Enabled = $true
    # $configuration.TestResult.OutputPath



    if ( test-path -path $configuration.Run.Path.Value ) {
        Add-ToLog -Message "Starting pester tests [$($configuration.Run.Path.value)]"  -logFilePath $LogPath -Display -Status "info"
        $Res = Invoke-Pester -Configuration $configuration
        #$Res | Export-Clixml -Path "$Location\$($Global:gsTESTSFolder)\testres.xml" -Force
        #$Res = Import-Clixml -Path "$Location\$($Global:gsTESTSFolder)\testres.xml"

        $Sections = [ordered] @{
            Failed  = $Res.Failed
            Skipped = $Res.Skipped
            NotRun  = $Res.NotRun
            Passed  = $Res.Passed
        }

        $Log = @()

        $Log += "Pester test log $(Get-date -format "dd.MM.yy HH:mm:ss")"
        $Log += "==========================="
        $Log += ""

        foreach ( $Section in $Sections.Keys ){
            $Time         =  [TimeSpan]::FromMilliseconds(($Sections.$Section.Duration | Select-Object -ExpandProperty totalmilliseconds | Measure-Object -sum).sum)
            $Time         =  Format-TimeSpan -TimeSpan $time -round 2
            $Log         += "    $($Section) ($Time):"
            $PrevTestPath =  ""
            $PrevPath     =  ""

            foreach ( $test in $Sections.$Section ) {
                $Time = [TimeSpan]::FromMilliseconds(($test.Duration | Select-Object -ExpandProperty totalmilliseconds))
                $Time = Format-TimeSpan -TimeSpan $time -round 2

                switch ( $test.Result ) {
                    "Passed" {
                        $Sign = "[+]"
                    }
                    "Failed" {
                        $Sign = "[-]"
                    }
                    "Skipped" {
                        $Sign = "[!]"
                    }
                    Default {
                        $Sign = "[ ]"
                    }
                }

                $TestPath = $Test.path | select -first ( $Test.path.count - 1 )
                if ( !$PrevPath ){
                    foreach ( $Item in $Testpath ){
                        $ItemLevel = [array]::IndexOf($Test.path, $Item) + 2
                        $Log      += "$( ''.PadLeft( $ItemLevel * 4, ' ' ))$Item"
                    }
                    $ItemLevel ++
                    $Log += "$( ''.PadLeft( $ItemLevel * 4 , ' ') )$Sign $($test.name) ($Time)"
                    $ItemLevel --
                }
                Else {
                    if ( ($PrevPath -join ",") -eq ($TestPath -join ",") ){
                        $ItemLevel ++
                        $Log += "$( ''.PadLeft( $ItemLevel * 4 , ' ') )$Sign $($test.name) ($Time)"
                        $ItemLevel --
                    }
                    Else {
                        if ( $PrevPath.count -gt $TestPath.count ){
                            foreach ( $Item in (0..($TestPath.count - 1) )){
                                if ( $PrevPath[$item] -ne $TestPath[$item] ){
                                    $ItemLevel = [array]::IndexOf($TestPath, $TestPath[$item]) + 2
                                    $Log      += "$( ''.PadLeft( $ItemLevel * 4, ' ' ))$($TestPath[$Item])"
                                }
                            }
                            $ItemLevel ++
                            $Log += "$( ''.PadLeft( $ItemLevel * 4 , ' ') )$Sign $($test.name) ($Time)"
                            $ItemLevel --
                        }
                        Else {
                            if ( $PrevPath.count -eq $TestPath.count ) {
                                foreach ( $Item in ( 0..($TestPath.count -1) ) ){
                                    if ( $PrevPath[$item] -ne $TestPath[$item] ){
                                        $ItemLevel = [array]::IndexOf($TestPath, $TestPath[$item]) + 2
                                        $Log      += "$( ''.PadLeft( $ItemLevel * 4, ' ' ))$($TestPath[$item])"
                                    }
                                }
                                $ItemLevel ++
                                $Log += "$( ''.PadLeft( $ItemLevel * 4 , ' ') )$Sign $($test.name) ($Time)"
                                $ItemLevel --
                            }
                            Else {
                                foreach ( $Item in (0..($TestPath.count -1) )){
                                    if ( $PrevPath[$item] -ne $TestPath[$item] ){
                                        $ItemLevel = [array]::IndexOf($TestPath, $TestPath[$item]) + 2
                                        $Log      += "$( ''.PadLeft( $ItemLevel * 4, ' ' ))$($TestPath[$item])"
                                    }
                                }
                                $ItemLevel ++
                                $Log += "$( ''.PadLeft( $ItemLevel * 4 , ' ') )$Sign $($test.name) ($Time)"
                                $ItemLevel --
                            }
                        }
                    }
                }
                $PrevPath = $TestPath
            }
        }
        $Log += ""
        $Log += "Total time: $(Format-TimeSpan -TimeSpan $res.duration -round 2)"
        $Log += ""

        if ( $res.FailedCount ){
            $res = $false
            Add-ToLog -Message "Failed pester tests [$($configuration.Run.Path)]"  -logFilePath $LogPath -Display -Status "error"
        }
        Else {
            $res = $true
            Add-ToLog -Message "Successfully Completed pester tests [$($configuration.Run.Path)]"  -logFilePath $LogPath -Display -Status "info"
        }
        if ( $SaveLog ){
            if ( !$LogFileName ){
                $LogPathParent = Split-Path -path $LogPath -Parent
                $LogFileName   = "$LogPathParent\Pester.log"
            }

            if ( $Log ){
                $Log | Out-File -FilePath $LogFileName -force
                Add-ToLog -Message "Saved log file [$LogFileName]" -logFilePath $LogPath -Display -Status "info"
            }
        }
    }
    Else {
        Add-ToLog -Message "Test file [$( $configuration.Run.Path.Value )] not found!" -logFilePath $LogPath -Display -Status "warning"
        $res = $true
    }

    Return $res
}
Function Remove-RightSpace {
<#
    .SYNOPSIS
        Remove right space
    .DESCRIPTION
        Remove trailing spaces from file.
    .EXAMPLE
        Remove-RightSpace -FilePath $FilePath [-LogPath $LogPath=$Global:gsScriptLogFilePath]
    .NOTES
        AUTHOR  Alexk
        CREATED 02.11.20
        MOD     04.11.20
        VER     2
#>
    [OutputType([bool])]
    [CmdletBinding()]
    param (
        [Parameter( Mandatory = $true, Position = 0, HelpMessage = "Powershell file path." )]
        [ValidateNotNullOrEmpty()]
        [string] $FilePath,
        [Parameter( Mandatory = $false, Position = 1, HelpMessage = "Common log file path." )]
        [string] $LogPath = $Global:gsScriptLogFilePath
    )

    Add-ToLog -Message "Start removing right spaces for [$FilePath]"  -logFilePath $LogPath -Display -Status "info"

    $Res = $true

    $Content    = Get-Content -Path $FilePath
    $NewContent = @()
    $HasChanged = $False

    foreach( $line in $content ) {
        if ( $line -ne $line.TrimEnd() ){
            $NewContent += $line.TrimEnd() + "`n"
            $HasChanged = $True
        }
        Else {
            $NewContent += $line + "`n"
        }
    }
    $lastLine = ($NewContent[($NewContent.count -1)]).Replace("`n","")
    $NewContent = $NewContent[0..($NewContent.count -2)]
    $NewContent = $NewContent + $lastLine
    If ( $HasChanged ){

        if ( $DebugMode ){
            $FileExt     = Split-Path -path $FilePath -Extension

            if ( $FileExt -eq ".psm1" ) {
                $Location = Split-Path -path $FilePath
            }
            Else {
                $Location = Split-Path -path (Split-Path -path $FilePath -Parent) -parent
            }
            $FileName     = Split-Path -path $FilePath -Leaf
            $TmpFilename  = "$Location\tmp.$FileName"

            $NewContent | Out-File -FilePath $TmpFilename -NoNewline -force
            Open-InVscode -ReuseOpenWindow -Compare -FilePath $FilePath -FilePath1 $TmpFilename
            $Answer = ""
            do {
                $Answer = read-host "Do you want to proceed with this changes?[y/n]"
            }  Until  ( ($Answer.ToLower() -ne "y") -or ($Answer.ToLower() -ne "n"))

            if ( $Answer.ToLower() -eq "y" ){
                $NewContent | Out-File -FilePath $FilePath  -NoNewline  -force
                Add-ToLog -Message "Removed right spaces for [$FilePath]"  -logFilePath $LogPath -Display -Status "info"
                Remove-Item -path $TmpFilename -Force
            }
            Else {
                Add-ToLog -Message "Removing right spaces for [$FilePath] aborted!"  -logFilePath $LogPath  -Display -Status "warning"
                $res = $false
            }
        }
        Else {
           $NewContent | Out-File -FilePath $FilePath  -NoNewline  -Force
        }
        Add-ToLog -Message "Removed right spaces for [$FilePath]"  -logFilePath $LogPath -Display -Status "info"
    }
    else {
        Add-ToLog -Message "Nothing to remove for [$FilePath]"  -logFilePath $LogPath -Display -Status "info"
    }

    return $res
}
Function Start-ScriptAnalyzer {
<#
    .SYNOPSIS
        Start script analyzer
    .DESCRIPTION
        Start PSScriptAnalyzer.
    .EXAMPLE
        Start-ScriptAnalyzer -FilePath $FilePath [-LogFileName $LogFileName] [-SaveLog $SaveLog] [-LogPath $LogPath=$Global:gsScriptLogFilePath]
    .NOTES
        AUTHOR  Alexk
        CREATED 02.11.20
        VER     1
#>
    [OutputType([bool])]
    [CmdletBinding()]
    param (
        [Parameter( Mandatory = $true, Position = 0, HelpMessage = "Powershell file path." )]
        [ValidateNotNullOrEmpty()]
        [string] $FilePath,
        [Parameter( Mandatory = $false, Position = 1, HelpMessage = "Path to save log file" )]
        [string] $LogFileName,
        [Parameter( Mandatory = $false, Position = 2, HelpMessage = "Save log to file." )]
        [switch] $SaveLog,
        [Parameter( Mandatory = $false, Position = 3, HelpMessage = "Common log file path." )]
        [string] $LogPath = $Global:gsScriptLogFilePath
    )

    $res = $True
    Add-ToLog -Message "Starting linter [PSScriptAnalyzer] for [$FilePath]."  -logFilePath $LogPath -Display -Status "info"
    import-module -Name "PSScriptAnalyzer" -force
    $Rules = @{
        ExcludeRules = @('PSAvoidUsingWriteHost',
            'PSAvoidGlobalVars',
            'PSUseShouldProcessForStateChangingFunctions',
            'PSAvoidUsingConvertToSecureStringWithPlainText'
        )
    }

    $AnalyzerLog = ( & Invoke-ScriptAnalyzer -Path $FilePath -Settings $Rules )

    $Groups = $AnalyzerLog | Group-Object Severity | Sort-Object Severity
    $Log = @()

    $Log += "PSAnalyzer log"
    $Log += "=============="
    $Log += ""

    foreach ( $item in $Groups ){
        $Log += "   $($Item.Name):"
        $Group1 = $Item | Select-Object -ExpandProperty group | Group-Object RuleName | Sort-Object RuleName
        foreach ( $item1 in $Group1 ){
            $Log += "       $($Item1.Name):"
            $Group2 = $Item1 | Select-Object -ExpandProperty group | Select-Object ScriptName, Line,  Message
            foreach ( $item2 in $Group2 ){
                if ( $item2.line ) {
                    $Log += "           $($Item2.ScriptName):$($Item2.Line.tostring().PadRight(5, " ") ) $($Item2.Message)"
                }
                Else {
                    $Log += "           $($Item2.ScriptName)$(''.PadRight(6, " ") ) $($Item2.Message)"
                }
            }
            $Log += ""

        }
    }

    Add-ToLog -Message "Finish linter [PSScriptAnalyzer] for [$FilePath]."  -logFilePath $LogPath -Display -Status "info"

    if ( "Error" -in $AnalyzerLog.Severity ){
        Add-ToLog -Message "PSScript analyzer found errors in the script. Testing aborted!" -logFilePath $LogPath -Display -Status "Error"
        $res = $false
    }
    if ( $SaveLog ) {
        if ( !$LogFileName ){
            $LogPathParent = Split-Path -path $LogPath -Parent
            $LogFileName   = "$LogPathParent\PSAnalyzer.log"
        }
        if ( $Log ){
            $Log | Out-File -FilePath $LogFileName -force
            Add-ToLog -Message "Saved log file [$LogFileName]" -logFilePath $LogPath -Display -Status "info"
        }
    }

    Return $Res
}
Function Update-HelpContent {
<#
    .SYNOPSIS
        Update help content
    .DESCRIPTION
        Update module or script help content.
    .EXAMPLE
        Update-HelpContent -FilePath $FilePath -Changes $Changes [-UpdateVersion $UpdateVersion] [-LogPath $LogPath=$Global:gsScriptLogFilePath]
    .NOTES
        AUTHOR  Alexk
        CREATED 02.11.20
        MOD     05.11.20
        VER     5
#>
    [OutputType([bool])]
    [CmdletBinding()]
    param (
        [Parameter( Mandatory = $true, Position = 0, HelpMessage = "Powershell file path." )]
        [ValidateNotNullOrEmpty()]
        [string] $FilePath,
        [Parameter( Mandatory = $true, Position = 1, HelpMessage = "Path to save log file" )]
        [PsObject] $Changes,
        [Parameter( Mandatory = $false, Position = 2, HelpMessage = "Save log to file." )]
        [switch] $UpdateVersion,
        [Parameter( Mandatory = $false, Position = 3, HelpMessage = "Common log file path." )]
        [string] $LogPath = $Global:gsScriptLogFilePath
    )

    Function Get-NewExamples {
    <#
        .SYNOPSIS
            Get new examples
        .DESCRIPTION
            Internal. Generate new examples from AST.
        .EXAMPLE
            Get-NewExamples -Function $Function
        .NOTES
            AUTHOR  Alexk
            CREATED 02.11.20
            VER     1
    #>
        [OutputType([string])]
        [CmdletBinding()]
        Param(
            [Parameter( Mandatory = $true, Position = 0, HelpMessage = "AST Function." )]
            $Function
        )

        [array] $Examples = @()
        [array] $ParameterSets = $Function.Parameters.ParameterSetName |  Where-Object { $null -ne $_ } | Select-Object -Unique

        if ( !$ParameterSets ) {
            $ParameterSets += ""
        }

        Foreach ( $ParameterSet in $ParameterSets ){
            $ExampleParams = @()
            if ( $ParameterSet ){
                $examples += "Parameter set: $ParameterSet"
            }
            foreach ( $Item in $Function.Parameters ){
                $ExampleParam = $null
                if ( $ParameterSet ) {
                    if ( ( $Item.ParameterSetName.Value -eq $ParameterSet.Value ) -or ( $null -eq $Item.ParameterSetName ) ){
                        $ExampleParam = [PSCustomObject]@{
                            Name      = [string] $Item.name.extent.text.substring(1)
                            Mandatory = [string] $Item.Mandatory.ToString()
                            Default   = [string] $Item.DefaultValue
                        }
                    }
                }
                Else {
                    if ( $Item.ParameterSetName.Value -eq $ParameterSet.Value ) {
                        if ( $Item.Mandatory){
                            $Mandatory = [string] $Item.Mandatory.ToString()
                        }
                        Else {
                            $Mandatory = [string] '$false'
                        }
                        $ExampleParam = [PSCustomObject]@{
                            Name      = [string] $Item.name.extent.text.substring(1)
                            Mandatory = $Mandatory
                            Default   = [string] $Item.DefaultValue
                        }
                    }
                }
                if ( $ExampleParam ) {
                    $ExampleParams += $ExampleParam
                }
            }
            $example = "$($Function.FunctionName) "
            foreach ( $item in ( $ExampleParams | Sort-Object Mandatory -Descending ) ){
               if ( $item.Default ) {
                   $DefaultValue = "=$($item.Default)"
               }
               Else {
                   $DefaultValue = ""
               }
               if ( $item.Mandatory -eq '$true' ){
                    $example += "-$($item.Name) `$$($item.Name)$DefaultValue "
               }
               Else{
                    $example += "[-$($item.Name) `$$($item.Name)$DefaultValue] "
               }
            }

            if ( $ParameterSet ){
                $Examples += "    $($example.TrimEnd())"
                $examples  += ""
            }
            Else {
                $Examples += $example.TrimEnd()
            }
        }

        Return $Examples.trim()
    }
    Function Get-NewDescription {
    <#
        .SYNOPSIS
            Get new description
        .DESCRIPTION
            Internal. Generate new description from AST.
        .EXAMPLE
            Get-NewDescription -Function $Function -FilePath $FilePath
        .NOTES
            AUTHOR  Alexk
            CREATED 02.11.20
            MOD     04.11.20
            VER     2
    #>
        [OutputType([string])]
        [CmdletBinding()]
        Param(
            [Parameter( Mandatory = $true, Position = 0, HelpMessage = "AST Function." )]
            $Function,
            [Parameter( Mandatory = $true, Position = 1, HelpMessage = "Powershell file path." )]
            [string] $FilePath
        )

        if ( $FilePath ) {
            $FileExt     = Split-Path -path $FilePath -Extension

            if ( $FileExt -eq ".psm1" ) {
                $Location = Split-Path -path $FilePath
            }
            Else {
                $Location = Split-Path -path (Split-Path -path $FilePath -Parent) -parent
            }
            $DescriptionPath = "$Location\$($Global:gsTESTSFolder)\Functions.csv"

            if ( test-path -path $DescriptionPath ) {
                $FuncArray = Import-Csv -Path $DescriptionPath -Delimiter ";"

                $FunctionDescription = ($FuncArray | Where-Object { ($_.FunctionName -eq $Function.FunctionName) -and ($_.ParentFunctionName -eq $Function.ParentFunctionName) }).Description
            }
        }
        if ( $FunctionDescription ){
            $res = $FunctionDescription
        }
        Else {
            $res = $Function.HelpContent.Description
        }

        $res = $res -split "`n"
        return $res
    }
    Function Get-NewNotes {
    <#
        .SYNOPSIS
            Get new notes
        .DESCRIPTION
            Internal. Generate new notes from AST.
        .EXAMPLE
            Get-NewNotes -Function $Function [-UpdateVersion $UpdateVersion] [-DefaultAuthor $DefaultAuthor="Alexk"]
        .NOTES
            AUTHOR  Alexk
            CREATED 02.11.20
            VER     1
    #>
        [OutputType([string])]
        [CmdletBinding()]
        Param(
            [Parameter( Mandatory = $true, Position = 0, HelpMessage = "AST Function." )]
            $Function,
            [switch] $UpdateVersion,
            [string] $DefaultAuthor = "Alexk"
        )

        $Notes = $Function.HelpContent.Notes
        $PSO = [PSCustomObject]@{
            Author  = $null
            Created = $null
            Mod     = $null
            Ver     = 0
            Other   = @()
        }

        if ( $Notes -notlike "*AUTHOR*" -and $Function.HelpContent.Synopsis ){
            $Notes = $Function.HelpContent.Synopsis
        }

        if ( $Notes ){
            $Notes = $Notes.trim()
            $Notes = $Notes.split("`n")
            foreach ( $item in $Notes ){

                switch -wildcard ( $item ) {
                    "*AUTHOR*" {
                        $Author     = $item.replace("AUTHOR","").trim()
                        $PSO.Author = $Author
                    }
                    "*DATE*" {
                        $Date     = $item.replace("DATE","").trim()
                        $PSO.Created= $Date
                        try {
                            $PSO.Created= $Date
                            $Date = (get-date $Date -Format "dd.MM.yy")
                            $PSO.Created= $Date
                        }
                        Catch {}
                    }
                    "*CREATED*" {
                        $Date     = $item.replace("CREATED","").trim()
                        $PSO.Created= $Date
                        try {
                            $PSO.Created= $Date
                            $Date = (get-date $Date -Format "dd.MM.yy")
                            $PSO.Created= $Date
                        }
                        Catch {}
                    }
                    "*MOD*" {
                        $Mod     = $item.replace("MOD","").trim()
                        try {
                            $PSO.Mod = $Mod
                            $Mod = (get-date $Mod -Format "dd.MM.yy")
                            $PSO.Mod = $Mod
                        }
                        Catch {}
                    }
                    "*VER*" {
                        $Ver     = $item.replace("VER","").trim()
                        try {
                            $Ver = [int]$Ver
                            $PSO.Ver = $Ver
                        }
                        Catch {}
                    }
                    Default {
                        $Other     = $item.trim()
                        $PSO.Other += $Other
                    }
                }
            }
        }

        if ( $Function.IsNew ){
            if ( !$PSO.Author ){
                $PSO.Author = $DefaultAuthor
            }
            if ( !$PSO.Created){
                $PSO.Created= Get-Date -Format "dd.MM.yy"
            }
            if ( !$PSO.Ver ){
                $PSO.Ver = 1
            }
        }
        ElseIf ( $Function.IsChanged ){
            if ( !$PSO.Author ){
                $PSO.Author = $DefaultAuthor
            }
            if ( !$PSO.Created){
                $PSO.Created= Get-Date -Format "dd.MM.yy"
            }

            if ( $PSO.Created-ne (Get-Date -Format "dd.MM.yy") ){
                if ($UpdateVersion){
                    $PSO.Mod = Get-Date -Format "dd.MM.yy"
                }
            }
            if ( !$PSO.Ver ){
                $PSO.Ver = "1"
            }
            Else {
                if ( $PSO.Mod ){
                    if ($UpdateVersion){
                       $PSO.Ver ++
                    }
                }
            }
        }
        Else {
            if ( !$PSO.Author ){
                $PSO.Author = $DefaultAuthor
            }
            if ( !$PSO.Created){
                $PSO.Created= Get-Date -Format "dd.MM.yy"
            }
            if ( !$PSO.Ver ){
                $PSO.Ver = "1"
            }
        }
        $Res = @()
        if ( $PSO.Mod ) {
            $res += "AUTHOR  $($PSO.Author)"
            $res += "CREATED $($PSO.Created)"
            $res += "MOD     $($PSO.Mod)"
            $res += "VER     $($PSO.Ver)"
        }
        Else {
            $res += "AUTHOR  $($PSO.Author)"
            $res += "CREATED $($PSO.Created)"
            $res += "VER     $($PSO.Ver)"
        }

        return $res
    }
    Function Get-NewSynopsis {
    <#
        .SYNOPSIS
            Get new synopsis
        .DESCRIPTION
            Internal. Generate new synopsis from AST.
        .EXAMPLE
            Get-NewSynopsis -Function $Function [-UpdateVersion $UpdateVersion]
        .NOTES
            AUTHOR  Alexk
            CREATED 02.11.20
            VER     1
    #>
        [OutputType([string])]
        [CmdletBinding()]
        Param(
            [Parameter( Mandatory = $true, Position = 0, HelpMessage = "AST Function." )]
            $Function,
            [switch] $UpdateVersion
        )

        $Res = ""
        $Synopsis = $Function.HelpContent.Synopsis
        if ( $Synopsis ) {
            if ( @($Synopsis.split("`n")).count -gt 2 ){
                if ( $Function.FunctionName ){
                    $res = Split-words -word $Function.FunctionName
                }
            }
            Else {
                $res = $Synopsis.trim()
            }
        }
        Else {
            if ( $Function.FunctionName ){
                $res = Split-words -word $Function.FunctionName
            }
        }

        return $res
    }
    Function Get-NewComponent {
    <#
        .SYNOPSIS
            Get new component
        .DESCRIPTION
            Internal. Generate new component from AST.
        .EXAMPLE
            Get-NewComponent -Function $Function
        .NOTES
            AUTHOR  Alexk
            CREATED 02.11.20
            VER     1
    #>
        [OutputType([string])]
        [CmdletBinding()]
        Param(
            [Parameter( Mandatory = $true, Position = 0, HelpMessage = "AST Function." )]
            $Function
        )

        $Res = ""
        $Component = $Function.HelpContent.Component
        if ( $Component ) {
            $res = $Component.trim()
        }
        Else {
            $res = ( $Global:gsImportedModule| Select-Object module -Unique ).module  -join ", "

        }

        return $res
    }
    Function Get-NewLink {
    <#
        .SYNOPSIS
            Get new links
        .DESCRIPTION
            Internal. Generate new links from AST.
        .EXAMPLE
            Get-NewLink -Function $Function -FilePath $FilePath
        .NOTES
            AUTHOR  Alexk
            CREATED 06.11.20
            VER     1
    #>
        [OutputType([string])]
        [CmdletBinding()]
        Param(
            [Parameter( Mandatory = $true, Position = 0, HelpMessage = "AST Function." )]
            $Function,
            [Parameter( Mandatory = $true, Position = 1, HelpMessage = "Powershell file path." )]
            [string] $FilePath
        )

        $Res = ""
        $Links = $Function.HelpContent.Links
        if ( $Links ) {
            $res = $Links.trim()
        }
        Else {
            $res = Get-ProjectOrigin -FilePath $FilePath
        }

        return $res
    }
    Function Get-UpdatedHelpContent {
    <#
        .SYNOPSIS
            Get updated help content
        .DESCRIPTION
            Internal. Generate new help content.
        .EXAMPLE
            Get-UpdatedHelpContent -Function $Function -FilePath $FilePath [-Synopsis $Synopsis] [-Role $Role] [-RemoteHelpRunspace $RemoteHelpRunspace] [-Parameters $Parameters] [-Notes $Notes] [-MamlHelpFile $MamlHelpFile] [-Link $Link] [-Inputs $Inputs] [-Functionality $Functionality] [-ForwardHelpTargetName $ForwardHelpTargetName] [-ForwardHelpCategory $ForwardHelpCategory] [-Examples $Examples] [-Description $Description] [-Component $Component] [-UpdateVersion $UpdateVersion] [-CreateEmpty $CreateEmpty]
        .NOTES
            AUTHOR  Alexk
            CREATED 02.11.20
            VER     1
    #>
        [CmdletBinding()]
        param (
            [Parameter( Mandatory = $True, Position = 0, HelpMessage = "Function metadata.")]
            $Function,
            [Parameter( Mandatory = $true, Position = 1, HelpMessage = "Powershell file path." )]
            [ValidateNotNullOrEmpty()]
            [string] $FilePath,
            [Parameter( Mandatory = $false, Position = 2, HelpMessage = "Recreate components." )]
            [switch] $Component,
            [Parameter( Mandatory = $false, Position = 3, HelpMessage = "Recreate Description." )]
            [switch] $Description,
            [Parameter( Mandatory = $false, Position = 4, HelpMessage = "Recreate Examples." )]
            [switch] $Examples,
            [Parameter( Mandatory = $false, Position = 5, HelpMessage = "Recreate ForwardHelpCategory." )]
            [switch] $ForwardHelpCategory,
            [Parameter( Mandatory = $false, Position = 6, HelpMessage = "Recreate ForwardHelpTargetName." )]
            [switch] $ForwardHelpTargetName,
            [Parameter( Mandatory = $false, Position = 7, HelpMessage = "Recreate Functionality." )]
            [switch] $Functionality,
            [Parameter( Mandatory = $false, Position = 8, HelpMessage = "Recreate Inputs." )]
            [switch] $Inputs,
            [Parameter( Mandatory = $false, Position = 9, HelpMessage = "Recreate Links." )]
            [switch] $Link,
            [Parameter( Mandatory = $false, Position = 10, HelpMessage = "Recreate MamlHelpFile." )]
            [switch] $MamlHelpFile,
            [Parameter( Mandatory = $false, Position = 11, HelpMessage = "Recreate Notes." )]
            [switch] $Notes,
            [Parameter( Mandatory = $false, Position = 12, HelpMessage = "Recreate Parameters." )]
            [switch] $Parameters,
            [Parameter( Mandatory = $false, Position = 13, HelpMessage = "Recreate RemoteHelpRunspace." )]
            [switch] $RemoteHelpRunspace,
            [Parameter( Mandatory = $false, Position = 14, HelpMessage = "Recreate Role." )]
            [switch] $Role,
            [Parameter( Mandatory = $false, Position = 15, HelpMessage = "Recreate Synopsis." )]
            [switch] $Synopsis,
            [Parameter( Mandatory = $false, Position = 16, HelpMessage = "Generate new version." )]
            [switch] $UpdateVersion,
            [Parameter( Mandatory = $false, Position = 17, HelpMessage = "Generate section with no data." )]
            [switch] $CreateEmpty
        )

        $HelpContent = $Function.HelpContent

        if ( $Examples ){
            $NewExample = Get-NewExamples -Function $Function
        }
        if ( $Description ){
            $NewDescription = Get-NewDescription -Function $Function -FilePath $FilePath
        }
        if ( $Notes ){
            if ( $UpdateVersion ){
                $NewNotes = Get-NewNotes -Function $Function -UpdateVersion
            }
            Else {
                $NewNotes = Get-NewNotes -Function $Function
            }
        }
        if ( $Synopsis ){
            if ( $UpdateVersion ){
                $NewSynopsis = Get-NewSynopsis -Function $Function -UpdateVersion
            }
            Else {
                $NewSynopsis = Get-NewSynopsis -Function $Function
            }
        }
        if ( $Component ){
            $NewComponent = Get-NewComponent -Function $Function
        }
        if ( $Link ){
            $NewLink = Get-NewLink -Function $Function -FilePath $FilePath
        }

        $Base = $Function.StartColumnNumber - 1
        if ( $Base -lt 0 ){
            $Base = 0
        }

        $ItemLevel       =  0
        $Indent          =  4
        $NewHelpContent  =  @()
        $NewHelpContent += "$(''.PadLeft($Base + $ItemLevel * $Indent , " "))<#"

        $Fields = "Synopsis", "Description", "Example", "Component", "ForwardHelpCategory", "ForwardHelpTargetName", "Functionality", "Inputs", "Link", "MamlHelpFile", "Notes", "Parameters", "RemoteHelpRunspace", "Role"
        $ItemLevel ++
        foreach ( $Field in  $fields ){
            $NewField   = Get-Variable -name "New$Field" -ErrorAction SilentlyContinue
            $SavedField = $Function.HelpContent.$Field
            if ( $NewField.Value ){
                $NewHelpContent += "$(''.PadLeft($Base + $ItemLevel * $Indent , " ")).$($Field.ToUpper())"
                $ItemLevel ++
                foreach ( $item in $NewField.Value ){
                    if ( $item.trim() ){
                        $NewHelpContent += "$(''.PadLeft($Base + $ItemLevel * $Indent , " "))$item"
                    }
                }
                $ItemLevel --
            }
            Else {
                $ItemLevel ++
                $SavedContent = @()
                foreach ( $item in $SavedField ){
                    if ( $item.count ){
                        foreach ($Line in ($item.split("`n"))){
                            if ( $Line.trim() ){
                                $SavedContent += "$(''.PadLeft($Base + $ItemLevel * $Indent , " "))$Line"
                            }
                        }
                    }
                }
                $ItemLevel --
                if ( $SavedContent ) {
                    $NewHelpContent += "$(''.PadLeft($Base + $ItemLevel * $Indent , " ")).$($Field.ToUpper())"
                    $NewHelpContent += $SavedContent
                }
                Else {
                    if ( $CreateEmpty ) {
                        switch ( $Field ) {
                            "link" {
                                $NewHelpContent += "$(''.PadLeft($Base + $ItemLevel * $Indent , " ")).$($Field.ToUpper())"
                            }
                            "synopsis" {
                                if ( $Synopsis ){
                                    $NewHelpContent += "$(''.PadLeft($Base + $ItemLevel * $Indent , " ")).$($Field.ToUpper())"
                                }
                            }
                            "description" {
                                if ( $Description ){
                                    $NewHelpContent += "$(''.PadLeft($Base + $ItemLevel * $Indent , " ")).$($Field.ToUpper())"
                                }
                            }
                            "examples" {
                                if ( $Examples ){
                                    $NewHelpContent += "$(''.PadLeft($Base + $ItemLevel * $Indent , " ")).$($Field.ToUpper())"
                                }
                            }
                            Default {}
                        }
                    }
                }
            }
        }
        $ItemLevel --
        $NewHelpContent += "$(''.PadLeft($Base + $ItemLevel * $Indent , " "))#>"

        Return $NewHelpContent
    }
    Function Get-CurrentHelpContent {
    <#
        .SYNOPSIS
            Get current help content
        .DESCRIPTION
            Internal. Get help content from file.
        .EXAMPLE
            Get-CurrentHelpContent -Function $Function
        .NOTES
            AUTHOR  Alexk
            CREATED 02.11.20
            MOD     05.11.20
            VER     2
    #>
        [CmdletBinding()]
        Param(
            [Parameter( Mandatory = $true, Position = 0, HelpMessage = "AST Function." )]
            $Function
        )

        $HelpContent = [PSCustomObject]@{
            Function      = ""
            HelpContent   = ""
        }
        if ( $Function.HelpContent ){
            if ( $Function.FunctionName ) {
                $TextLengthPreview    = Get-TextLengthPreview -text $Function.text -RemoveCR
                $HelpContent.Function = $Function.text.split("{")[0] + "{"
                $SpaceCounter         = $TextLengthPreview[($TextLengthPreview | select-string  -pattern "<#")[0].LineNumber-1].length - 2
                #$Function.text.split($HelpContent.Function)[1].split("<#")[0].length - 1
                # if ( $SpaceCounter -lt 0 ){
                #     $SpaceCounter = 0
                # }
                $HelpContent.HelpContent = (''.PadLeft( $SpaceCounter, " ")) + "<#" + $Function.text.split("<#")[1].split("#>")[0] + "#>"
            }
            Else {
                $SpaceCounter            = $Function.text.split("<#")[0].count - 1
                $HelpContent.HelpContent = (''.PadLeft( $SpaceCounter, " ")) + "<#" + $Function.text.split("<#")[1].split("#>")[0] + "#>"
            }
        }
        Else {
            if ( $Function.FunctionName ) {
                $HelpContent.Function = $Function.text.split("{")[0] + "{"
            }
            Else {
                $HelpContent.Function = ""
            }
        }
        #write-host @($HelpContent.HelpContent)
        Return $HelpContent
    }

    $res = $True
    Add-ToLog -Message "Starting update help content for [$FilePath]"  -logFilePath $LogPath -Display -Status "info"
    $ReplaceArray = @()
    #$FunctionDetails = Get-FunctionDetails -FilePath $FilePath
    #$FileContent     = Get-Content -path $Filepath

    $FileExt     = Split-Path -path $FilePath -Extension

    if ( $FileExt -eq ".psm1" ) {
        $Location = Split-Path -path $FilePath
    }
    Else {
        $Location = Split-Path -path (Split-Path -path $FilePath -Parent) -parent
    }

    if ( $FilePath ) {
        $DescriptionPath = "$Location\$($Global:gsTESTSFolder)\functions.csv"
        if ( !( test-path -path $DescriptionPath ) ){
            $Changes.FunctionList | Select-Object ParentFunctionName, FunctionName, Description | Export-Csv -path $DescriptionPath -Delimiter ";"
        }

        # Update module help content
        $EndLineNumber = ($Changes.FunctionList | Sort-Object StartLineNumber | Select-Object -First 1).StartLineNumber - 2
        $ModuleText    = Get-Content -Path $FilePath -Raw -ReadCount $EndLineNumber

        $PSO = [PSCustomObject]@{
            FunctionName      = ""
            HelpContent       = Get-ModuleHelpContent -FilePath $FilePath
            IsNew             = $false
            IsChanged         = $UpdateVersion
            StartColumnNumber = 1
            Text              = $ModuleText
        }

        if ( ( $Changes.ChangedFunctions ) -or ( $Changes.Added ) -or ( $Changes.Deleted ) ){
            $UpdatedHelpContent = Get-UpdatedHelpContent -Function $PSO -FilePath $FilePath -Examples -Description -Notes -synopsis -Component -link -UpdateVersion -CreateEmpty
        }
        Else {
            $UpdatedHelpContent = Get-UpdatedHelpContent -Function $PSO -FilePath $FilePath -Examples -Description -Notes -synopsis -Component -link -CreateEmpty
        }
        $CurrentHelpContent = Get-CurrentHelpContent -Function $PSO

        $ReplaceData = [PSCustomObject]@{
            Function = ""
            Find     = ""
            Replace  = ""
        }

        if ( $CurrentHelpContent.HelpContent ){
            $ReplaceData.Function = $PSO.FunctionName
            $ReplaceData.Find     = $CurrentHelpContent.HelpContent
            $ReplaceData.Replace  = $UpdatedHelpContent
            $ReplaceArray        += $ReplaceData
        }
        Else {
            $CurrentHelpContent   = $CurrentHelpContent.function
            $NewHelpContent       = @()
            #$NewHelpContent      += $CurrentHelpContent
            $NewHelpContent      += $UpdatedHelpContent
            $ReplaceData.Function = $PSO.FunctionName
            $ReplaceData.Find     = $CurrentHelpContent
            $ReplaceData.Replace  = $NewHelpContent
            $ReplaceArray        += $ReplaceData
        }
    }

    # Update function help content
    foreach ( $item in ( $Changes.FunctionList | Sort-Object StartLineNumber ) ){
        #write-host $item.FunctionName
        $CurrentHelpContent = Get-CurrentHelpContent -Function $item
        if ( $UpdateVersion ){
            $UpdatedHelpContent = Get-UpdatedHelpContent -Function $item -FilePath $FilePath -Examples -Description -Notes -synopsis -UpdateVersion
        }
        Else {
            $UpdatedHelpContent = Get-UpdatedHelpContent -Function $item -FilePath $FilePath -Examples -Description  -Notes -Synopsis
        }

        $ReplaceData = [PSCustomObject]@{
            Function = ""
            Find     = ""
            Replace  = ""
        }

        if ( $CurrentHelpContent.HelpContent ){
            $ReplaceData.Function = $item.FunctionName
            $ReplaceData.Find     = $CurrentHelpContent.HelpContent
            $ReplaceData.Replace  = $UpdatedHelpContent
            $ReplaceArray        += $ReplaceData
        }
        Else {
            $CurrentHelpContent   = $CurrentHelpContent.function
            $NewHelpContent       = @()
            $NewHelpContent      += $CurrentHelpContent
            $NewHelpContent      += $UpdatedHelpContent
            $ReplaceData.Function = $item.FunctionName
            $ReplaceData.Find     = $CurrentHelpContent
            $ReplaceData.Replace  = $NewHelpContent
            $ReplaceArray        += $ReplaceData
        }
    }

    #$FileContent     = $FileContent.Replace( $CurrentHelpContent, $NewHelpContent )
    $FileContent      = Get-Content $FilePath -Raw
    $SavedFileContent = $FileContent.Clone()

    foreach ( $item in $ReplaceArray ){
        $replace     = $item.replace -join "`n"
        $find        = $item.find
        if ( $find ){
            if ( ($replace.contains("<#") -and $replace.contains("#>")) -and ($find.contains("<#") -and $find.contains("#>") -or ( $find -ne "" )) ) {
                $FindRes = ([regex]::Matches($FileContent, [regex]::Escape($Find))).count
                if ( $FindRes -eq 1 ) {
                    $FileContent = $FileContent -replace [regex]::Escape($Find), $replace
                }
                Else {
                    if ( $FindRes -eq 0 ){
                        Add-ToLog -Message "String: `n$Find`nNot found !"  -logFilePath $LogPath -Display -Status "Error"
                    }
                    Else {
                        Add-ToLog -Message "Found multiple [$FindRes] string: `n$Find!"  -logFilePath $LogPath -Display -Status "Error"
                    }
                    $res = $False
                }
            }
            Else {
                Add-ToLog -Message "Found unconditional parameters for replacement find [$find] replace [$replace]!"  -logFilePath $LogPath -Display -Status "Error"
                $res = $False
            }
        }
        Else {
            if ( $FileContent ){
                if ( $Replace ){
                    $FileContent = $Replace + "`n`n`n" + $FileContent
                }
                Else {
                    Add-ToLog -Message "Replace and find not set!"  -logFilePath $LogPath -Display -Status "Error"
                }
            }
        }
    }

    $FileContent = $FileContent.TrimEnd()
    $FileExt     = Split-Path -path $FilePath -Extension

    if ( $FileExt -eq ".psm1" ) {
        $Location = Split-Path -path $FilePath
    }
    Else {
        $Location = Split-Path -path (Split-Path -path $FilePath -Parent) -parent
    }

    $FileName    = Split-Path -path $FilePath -Leaf
    $TmpFilename = "$Location\tmp.$FileName"
    $FileContent | Out-File -FilePath $TmpFilename -force -Encoding utf8BOM -NoNewline

    $CompareFiles = compare-object -ReferenceObject ( get-content -path $FilePath ) -DifferenceObject ( get-content -path $TmpFilename )

    if ( $CompareFiles ) {
        if ( $DebugMode ){
            Open-InVscode -ReuseOpenWindow -Compare -FilePath $FilePath -FilePath1 $TmpFilename
            $Answer = ""
            do {
                $Answer = read-host "Do you want to proceed with help content changes?[y/n]"
            }  Until  ( ($Answer.ToLower() -ne "y") -or ($Answer.ToLower() -ne "n"))

            if ( $Answer.ToLower() -eq "y" ){
                $FileContent | Out-File -FilePath $FilePath -NoNewline -force
                Add-ToLog -Message "Updated help content for [$FilePath]"  -logFilePath $LogPath -Display -Status "info"
            }
            Else {
                Add-ToLog -Message "Updating help content for [$FilePath] aborted!"  -logFilePath $LogPath -Display -Status "warning"
                $res = $False
            }
        }
        Else {
            $FileContent | Out-File -FilePath $FilePath -NoNewline -force
            Add-ToLog -Message "Updated help content for [$FilePath]"  -logFilePath $LogPath -Display -Status "info"
        }
    }
    Else {
        Add-ToLog -Message "Nothing to update for [$FilePath]"  -logFilePath $LogPath -Display -Status "info"

    }
    Remove-Item -path $TmpFilename -Force

    return $res
}
Function Update-ModuleMetaData {
<#
    .SYNOPSIS
        Update module meta data
    .DESCRIPTION
        Update module metadata file (*.psd1).
    .EXAMPLE
        Update-ModuleMetaData -FilePath $FilePath -Changes $Changes -CommitMessage $CommitMessage -AuthorName $AuthorName -AuthorEmail $AuthorEmail -ProjectStartYear $ProjectStartYear -License $License [-LogPath $LogPath=$Global:gsScriptLogFilePath]
    .NOTES
        AUTHOR  Alexk
        CREATED 02.11.20
        VER     1
#>
    [OutputType([bool])]
    [CmdletBinding()]
    param (
        [Parameter( Mandatory = $true, Position = 0, HelpMessage = "Powershell file path." )]
        [ValidateNotNullOrEmpty()]
        [string] $FilePath,
        [Parameter( Mandatory = $true, Position = 1, HelpMessage = "Change data." )]
        [PsObject] $Changes,
        [Parameter( Mandatory = $true, Position = 2, HelpMessage = "Git commit message." )]
        [string] $CommitMessage,
        [Parameter( Mandatory = $true, Position = 3, HelpMessage = "Author name." )]
        [string] $AuthorName,
        [Parameter( Mandatory = $true, Position = 4, HelpMessage = "Author email." )]
        [string] $AuthorEmail,
        [Parameter( Mandatory = $true, Position = 5, HelpMessage = "Year, project was started." )]
        [string] $ProjectStartYear,
        [Parameter( Mandatory = $true, Position = 6, HelpMessage = "Module license." )]
        [ValidateSet("Apache 2.0")]
        [string] $License,
        [Parameter( Mandatory = $false, Position = 7, HelpMessage = "Common log file path." )]
        [string] $LogPath = $Global:gsScriptLogFilePath
    )
    <#
        Version number of this module.
        Version Major.Minor.Build.Revision
        Major    (Major<1 Beta, Major>1) release Setup manual
        Minor    Add/remove/Change functions
        Build    Increment on build
        Revision Increment on Fix build, reset on New build
    #>
    $Res = $false
    $Location     = Split-Path -path $FilePath
    $BaseFileName = Split-Path -path $FilePath -LeafBase
    $FileExt      = Split-Path -path $FilePath -Extension

    if ( $FileExt -eq ".psm1" ) {
        import-module -name $BaseFileName -force
        $Module = get-module -name $BaseFileName
    }

    Add-ToLog -Message "Starting module [$($Module.name)] metadata update."  -logFilePath $LogPath -Display -Status "info"

    $CodeVersion = Get-ModuleVersion -FilePath $FilePath

    if ( $Changes.object.Added -or $Changes.object.removed -or $Changes.object.ChangedFunctions ){
        $Minor = $CodeVersion.Minor + 1
    }
    Else {
        $Minor = $CodeVersion.Minor
    }

    $Build = $CodeVersion.Build + 1

    if ( $CommitMessage.ToLower().contains( $Global:CommitType.fix ) ){
        $Revision = $CodeVersion.Revision + 1
    }
    Else {
        $Revision = $CodeVersion.Revision
    }
    $UpdatedVersion = ($CodeVersion.Major, $Minor, $Build, $Revision) -join "."
    $ReleaseNotes   = $CommitMessage
    switch ( $license ) {
        "Apache 2.0" {
            $Copyright = "Copyright (c) $AuthorName($AuthorEmail) $(get-date -Format "yyyy"), licensed under Apache 2.0 License."
            $LicenseUri = "http://www.apache.org/licenses/LICENSE-2.0.html"
        }
        Default {
            $Copyright = "Copyright (c) $AuthorName($AuthorEmail) $(get-date -Format "yyyy"). All rights reserved."
        }
    }

    if ( $Module ) {
        $ModuleParameters = @{}

        $ModuleParameters += @{ Path               = "$Location\$BaseFileName.psd1" }
        $ModuleParameters += @{ ModuleVersion      = $UpdatedVersion }
        $ModuleParameters += @{ Copyright          = $Copyright }
        $ModuleParameters += @{ LicenseUri         = $LicenseUri }
        $ModuleParameters += @{ ReleaseNotes       = $ReleaseNotes }
        $ModuleParameters += @{ FunctionsToExport  = '*'}

        Update-ModuleManifest @ModuleParameters -Verbose:$False
        Add-ToLog -Message "Module [$($Module.name)] successfully updated."  -logFilePath $LogPath -Display -Status "info"
        $res = $True
    }

    return $Res
}
Function Get-ChangeStatus {
<#
    .SYNOPSIS
        Get change status
    .DESCRIPTION
        Get commit version appliance status.
    .EXAMPLE
        Get-ChangeStatus -FilePath $FilePath
    .NOTES
        AUTHOR  Alexk
        CREATED 02.11.20
        VER     1
#>
    [OutputType([PsObject])]
    [CmdletBinding()]
    param(
        [Parameter( Mandatory = $true, Position = 0, HelpMessage = "Powershell file path." )]
        [ValidateNotNullOrEmpty()]
        [string] $FilePath
    )

    $LastCommitInfo = Get-CommitInfo -FilePath $FilePath

    $Res = $True

    $FileExt     = Split-Path -path $FilePath -Extension

    if ( $FileExt -eq ".psm1" ) {
        $Location = Split-Path -path $FilePath
    }
    Else {
        $Location = Split-Path -path (Split-Path -path $FilePath -Parent) -parent
    }

    $ChangeFilePath = "$Location\$($Global:gsTESTSFolder)\VersionAppliance.csv"

    if ( test-path -path $ChangeFilePath ){
        $Data = Import-Csv -path $ChangeFilePath
        if ( $Data | Where-Object { $_.Hash -eq $LastCommitInfo.Hash } ){
            $Res = $Data | Where-Object { $_.Hash -eq $LastCommitInfo.Hash }
            $HelpContent    = $Res.HelpContent
            $ModuleMetaData = $Res.ModuleMetaData
            if ( !$HelpContent ){
                $HelpContent = $false
            }
            if ( !$ModuleMetaData ){
                $ModuleMetaData = $false
            }
        }
    }
    $PSO = [PSCustomObject]@{
        HelpContent    = $HelpContent
        ModuleMetaData = $ModuleMetaData
    }
    Return $PSO
}
Function Set-ChangeStatus {
<#
    .SYNOPSIS
        Set change status
    .DESCRIPTION
        Set commit version appliance status.
    .EXAMPLE
        Set-ChangeStatus -FilePath $FilePath -Type $Type
    .NOTES
        AUTHOR  Alexk
        CREATED 02.11.20
        VER     1
#>
    [CmdletBinding()]
    param(
        [Parameter( Mandatory = $true, Position = 0, HelpMessage = "Powershell file path." )]
        [ValidateNotNullOrEmpty()]
        [string] $FilePath,
        [Parameter( Mandatory = $true, Position = 0, HelpMessage = "Object type." )]
        [ValidateSet("HelpContent","ModuleMetaData")]
        [string] $Type
    )

    $Res = $True

    $LastCommitInfo = Get-CommitInfo -FilePath $FilePath

    $FileExt     = Split-Path -path $FilePath -Extension

    if ( $FileExt -eq ".psm1" ) {
        $Location = Split-Path -path $FilePath
    }
    Else {
        $Location = Split-Path -path (Split-Path -path $FilePath -Parent) -parent
    }

    $ChangeFilePath = "$Location\$($Global:gsTESTSFolder)\VersionAppliance.csv"
    $NewData = @()
    if ( test-path -path $ChangeFilePath ){
        $Data  =  Import-Csv -path $ChangeFilePath
        $Exist = $Data | Where-Object { $_.hash -eq $LastCommitInfo.hash }
        if ( $Exist ){
            if ( $Exist.psobject.properties.name -contains "ModuleMetaData" ){
                $Exist.ModuleMetaData = $True
                $NewData += $Data
            }
            Else {
                $Exist | Add-Member -NotePropertyName $Type -NotePropertyValue $true
                $NewData += $Data
            }
        }
        Else {
            $LastCommitInfo.Modified =  $LastCommitInfo.Modified -join "; "
            $LastCommitInfo | Add-Member -NotePropertyName $Type -NotePropertyValue $true
            $NewData += $Data
            $NewData += $LastCommitInfo
        }

        $NewData | Export-Csv -path $ChangeFilePath
    }
    Else {
        $LastCommitInfo.Modified = $LastCommitInfo.Modified -join "; "
        $LastCommitInfo | Add-Member -NotePropertyName $Type -NotePropertyValue $true
        $LastCommitInfo | Export-Csv -path $ChangeFilePath
    }
}
Function Update-EmptySettings {
<#
    .SYNOPSIS
        Update empty settings
    .DESCRIPTION
        Generate new empty setting files.
    .EXAMPLE
        Update-EmptySettings -FilePath $FilePath [-LogPath $LogPath=$Global:gsScriptLogFilePath]
    .NOTES
        AUTHOR  Alexk
        CREATED 02.11.20
        VER     1
#>
    [OutputType([bool])]
    [CmdletBinding()]
    param (
        [Parameter( Mandatory = $true, Position = 0, HelpMessage = "Powershell file path." )]
        [ValidateNotNullOrEmpty()]
        [string] $FilePath,
        [Parameter( Mandatory = $false, Position = 3, HelpMessage = "Common log file path." )]
        [string] $LogPath = $Global:gsScriptLogFilePath
    )

    Add-ToLog -Message "Start creating empty setting file for [$FilePath]"  -logFilePath $LogPath -Display -Status "info"

    $FileExt     = Split-Path -path $FilePath -Extension

    if ( $FileExt -eq ".psm1" ) {
        $Location = Split-Path -path $FilePath
    }
    Else {
        $Location = Split-Path -path (Split-Path -path $FilePath -Parent) -parent
    }

    $EmptySettingsCreatorName = "EmptySettingsCreator"
    $EmptySettingsCreatorPath = "$($Global:gsProjectServicesFolderPath)\$EmptySettingsCreatorName\$Global:gsSCRIPTSFolder\$EmptySettingsCreatorName.ps1"

    . $EmptySettingsCreatorPath -ProjectPath $Location -InitGlobal $false -InitLocal $true
    Add-ToLog -Message "Finish creating empty setting file for [$FilePath]"  -logFilePath $LogPath -Display -Status "info"
    return $true
}
Function Get-ModuleHelpContent {
<#
    .SYNOPSIS
        Get module help content
    .DESCRIPTION
        Get module or script help content.
    .EXAMPLE
        Get-ModuleHelpContent -FilePath $FilePath
    .NOTES
        AUTHOR  Alexk
        CREATED 02.11.20
        MOD     03.11.20
        VER     2
#>
    [OutputType([PsObject])]
    [CmdletBinding()]
    param (
        [Parameter( Mandatory = $true, Position = 0, HelpMessage = "Full path to module file." )]
        [ValidateNotNullOrEmpty()]
        [string] $FilePath
    )
    $VarToken = $Null
    $VarError = $Null

    $Ast = [System.Management.Automation.Language.Parser]::ParseFile( $FilePath, [ref] $VarToken , [ref] $VarError )
    $HelpContent = $Ast.GetHelpContent()

    return $HelpContent
}
Function Get-CommentRegions {
<#
    .SYNOPSIS
        Get comment regions
    .DESCRIPTION
        Get comment regions from AST.
    .EXAMPLE
        Get-CommentRegions -FilePath $FilePath
    .NOTES
        AUTHOR  Alexk
        CREATED 02.11.20
        MOD     03.11.20
        VER     2
#>
    [OutputType([PsObject])]
    [CmdletBinding()]
    param (
        [Parameter( Mandatory = $true, Position = 0, HelpMessage = "Powershell file path." )]
        [ValidateNotNullOrEmpty()]
        [string] $FilePath
    )


    $Content = Get-Content -path $FilePath

    $CommentTokens =  [System.Management.Automation.PSParser]::Tokenize($Content, [ref]$null) |  Where-Object{ ($_.type -like "*comment*") -and ($_.Content -like "#*region*") }

    $Regions = @()
    foreach ( $Region in $CommentTokens ) {
        if ( $Region.content -like "#region*" ){
            $PSO = [PSCustomObject]@{
                Content   = $Region.Content
                Type      = $Region.Type
                StartLine = $Region.StartLine
                EndLine   = ""
            }
        }
        Else {
            $PSO.EndLine = $Region.EndLine
            $Regions += $PSO
        }
    }

    return $Regions

}
Function Get-PesterTemplate {
<#
    .SYNOPSIS
        Get pester template
    .DESCRIPTION
        Generate pester test template.
    .EXAMPLE
        Get-PesterTemplate -FilePath $FilePath -Author $Author="AlexK"
    .NOTES
        AUTHOR  Alexk
        CREATED 02.11.20
        MOD     03.11.20
        VER     2
#>
    [OutputType([string[]])]
    [CmdletBinding()]
    param (
        [Parameter( Mandatory = $true, Position = 0, HelpMessage = "Powershell file path." )]
        [ValidateNotNullOrEmpty()]
        [string] $FilePath,
        [Parameter( Mandatory = $true, Position = 1, HelpMessage = "Test file Author." )]
        [string] $Author = "AlexK"
    )

    $FileExt = Split-Path -Path $FilePath -Extension
    if ( $FileExt -eq ".psm1"  ) {
        $Module = Split-Path -Path $FilePath -LeafBase
    }

    $FunctionDetails = Get-FunctionDetails -FilePath $FilePath
    $FunctionRegions = Get-CommentRegions  -FilePath $FilePath

    $Lines = @()

    $TemplateCommentHelp = @"
<#
    .SYNOPSIS
        Pester test for [$FilePath].
    .DESCRIPTION
        Generated by AlexKBuildTools\Get-PesterTemplate ( https://github.com/Alex-0293/AlexKBuildTools )
    .NOTES
        VER     1
        AUTHOR  Alexk
        CREATED $(get-date -Format "dd.MM.yy")
#>


"@
    $Lines += $TemplateCommentHelp
    $Lines += @"
clear-host
Import-Module -Name "Pester"
$(if ( $Module ){ Import-module -Name `"$Module`" -force })
`$TestedFilePath = `"$FilePath`"

`$PesterPreference                  = [PesterConfiguration]::Default
`$PesterPreference.Output.Verbosity = "Detailed"
`$PesterPreference.Run.Exit         = `$true

"@

    foreach ( $Function in $FunctionDetails ){
        if ( $Function.EndLineNumber -lt $FunctionRegions[0].StartLine ) {
            $Lines += "Describe `"[$($Function.FunctionName)]`" -skip {"
            $Lines += "    It  `"name`" {"
            $Lines += ""
            $Lines += "    }"
            $Lines += "}"
            $Lines += ""
        }
    }

    foreach ( $region in $FunctionRegions ) {
        $Lines += "Context `"$($region.content.replace('#region','').trim())`" {"
        foreach ( $Function in $FunctionDetails ){
            if ( ( $Function.StartLineNumber -gt $region.StartLine ) -and ( $Function.EndLineNumber -lt $region.EndLine ) ) {
                $Lines += "    Describe `"[$($Function.FunctionName)]`" -skip {"
                $Lines += "        It  `"name`" {"
                $Lines += ""
                $Lines += "        }"
                $Lines += "    }"
                $Lines += ""
            }
        }
        $Lines += "}"
        $Lines += ""
    }

    foreach ( $Function in $FunctionDetails ){
        if ( $Function.StartLineNumber -gt $FunctionRegions[( $FunctionRegions.count - 1 )].EndLine ) {
            $Lines += "Describe `"[$($Function.FunctionName)]`" -skip {"
            $Lines += "    It  `"name`" {"
            $Lines += ""
            $Lines += "    }"
            $Lines += "}"
            $Lines += ""
        }
    }

    Return $Lines
}
Function Get-ProjectGitStatus {
<#
    .SYNOPSIS
        Get git current status
    .DESCRIPTION
        Get git project status.
    .EXAMPLE
        Get-ProjectGitStatus -FilePath $FilePath
    .NOTES
        AUTHOR  Alexk
        CREATED 02.11.20
        VER     1
#>
    [OutputType([PsObject])]
    [CmdletBinding()]
    param (
        [Parameter( Mandatory = $true, Position = 0, HelpMessage = "Powershell file path." )]
        [ValidateNotNullOrEmpty()]
        [string] $FilePath
    )

    $FileExt     = Split-Path -path $FilePath -Extension

    if ( $FileExt -eq ".psm1" ) {
        $Location = Split-Path -path $FilePath
    }
    Else {
        $Location = Split-Path -path (Split-Path -path $FilePath -Parent) -parent
    }

    Set-Location $Location

    $GitStatus = ( & git status )
    $section   = $null

    foreach ( $line in $GitStatus ){
        switch -wildcard ($line) {
            "On branch*" {
                $section  = "OnBranch"
                $OnBranch = @()
            }
            "Changes not staged for commit:*" {
                $section   = "NotStaged"
                $NotStaged = @()
            }
            "Untracked files*" {
                $section        = "UntrackedFiles"
                $UntrackedFiles = @()
            }
            Default {}
        }

        switch ( $section ) {
            "OnBranch" {
                $OnBranch += ( $line.trim() )
            }
            "NotStaged" {
                $NotStaged += ( $line.trim() )
            }
            "UntrackedFiles" {
                $UntrackedFiles += ( $line.trim() )
            }
            Default {}
        }
    }

    if ( $OnBranch ) {
        if ( $OnBranch[1].split("'")[0].contains("up to date") ){
            $Branch   = $OnBranch[1].split("'")[1]
            $UpToDate = $true
        }
        Else {
            $Branch   = $OnBranch[1].split("'")[1]
            $UpToDate = $false
        }
    }
    if ( $NotStaged ){
        $NotStagedFiles =  $NotStaged[3..($NotStaged.count-2)]
    }
    if ( $UntrackedFiles ){
        $Untracked =  $UntrackedFiles[2..($UntrackedFiles.count-3)]
    }

    $PSO = [PSCustomObject]@{
        Branch         = $Branch
        UpToDate       = $UpToDate
        NotStagedFiles = $NotStagedFiles
        Untracked      = $Untracked
    }

    return $PSO
}
Function Invoke-GitCommit {
<#
    .SYNOPSIS
        Invoke git commit
    .DESCRIPTION
        Invoke git commit.
    .EXAMPLE
        Invoke-GitCommit -FilePath $FilePath -CommitMessage $CommitMessage [-CommittedFileList $CommittedFileList] [-BranchName $BranchName="master"] [-Push $Push] [-PassThru $PassThru]
    .NOTES
        AUTHOR  Alexk
        CREATED 02.11.20
        MOD     05.11.20
        VER     2
#>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0, HelpMessage = "Script file path." )]
        [string] $FilePath,
        [Parameter(Mandatory = $false, Position = 1, HelpMessage = "Path to committed files." )]
        [string[]] $CommittedFileList,
        [Parameter(Mandatory = $true, Position = 2, HelpMessage = "Commit message." )]
        [ValidateLength(1,50)]
        [string] $CommitMessage,
        [Parameter(Mandatory = $false, Position = 3, HelpMessage = "Branch name." )]
        [string] $BranchName = "master",
        [Parameter(Mandatory = $false, Position = 4, HelpMessage = "Push commit." )]
        [switch] $Push,
        [Parameter(Mandatory = $false, Position = 5, HelpMessage = "Return object." )]
        [switch] $PassThru
    )

    $FileExt     = Split-Path -path $FilePath -Extension

    if ( $FileExt -eq ".psm1" ) {
        $Location = Split-Path -path $FilePath
    }
    Else {
        $Location = Split-Path -path (Split-Path -path $FilePath -Parent) -parent
    }
    Set-Location $Location

    if ( $CommittedFileList ){
        $AddFilesToCommit = Invoke-GitAdd -FilePath $FilePath -AddFiles $CommittedFileList
    }
    Else {
        $AddFilesToCommit = Invoke-GitAdd -FilePath $FilePath
    }

    $CurrentBranch = Get-CurrentGitBranch -FilePath $FilePath
    #$Branch   = (& git branch "`"$BranchName`"" )
    if ( $CurrentBranch -ne $BranchName ){
        $Checkout = (& git checkout -b "`"$BranchName`"" )
        $ChangeBranch = $true
    }


    $Commit   = (& git.exe commit -m "`"$CommitMessage`"" )


    if ( $Commit ){
        if ( !($Commit -like "*nothing to commit*") ){
            if ( $Push ){
                $PushMessage = Invoke-GitPush -FilePath $FilePath -BranchName $BranchName -PassThru
            }
        }
    }

    if ( $ChangeBranch ){
        $Checkout = (& git checkout "`"$CurrentBranch`"" )
    }

    if ( $PassThru ){
        $PSO = [PSCustomObject]@{
            AddFilesToCommit = $AddFilesToCommit
            Commit           = $Commit
            Push             = $PushMessage
        }

        return $PSO
    }
}
Function Invoke-GitPush {
<#
    .SYNOPSIS
        Invoke git push
    .EXAMPLE
        Invoke-GitPush -FilePath $FilePath [-BranchName $BranchName="origin master"] [-PassThru $PassThru]
    .NOTES
        AUTHOR  Alexk
        CREATED 05.11.20
        VER     1
#>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0, HelpMessage = "Script file path." )]
        [string] $FilePath,
        [Parameter(Mandatory = $false, Position = 3, HelpMessage = "Branch name." )]
        [string] $BranchName = "origin master",
        [switch] $PassThru
    )

    $FileExt     = Split-Path -path $FilePath -Extension

    if ( $FileExt -eq ".psm1" ) {
        $Location = Split-Path -path $FilePath
    }
    Else {
        $Location = Split-Path -path (Split-Path -path $FilePath -Parent) -parent
    }

    Set-Location $Location

    $ArgList = @()
    $ArgList += "push"
    $ArgList += "-u"
    $ArgList += "origin"
    $ArgList += "$BranchName"
    $ArgList += "--verbose"

    $PushMessage = (& git.exe $ArgList)

    if ( $PassThru ){
        return $PushMessage
    }
}
Function Invoke-GitAdd {
<#
    .SYNOPSIS
        Invoke git add
    .EXAMPLE
        Invoke-GitAdd -FilePath $FilePath [-AddFiles $AddFiles="."] [-PassThru $PassThru]
    .NOTES
        AUTHOR  Alexk
        CREATED 05.11.20
        VER     1
#>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0, HelpMessage = "Script file path." )]
        [string] $FilePath,
        [Parameter(Mandatory = $false, Position = 3, HelpMessage = "Branch name." )]
        [string[]] $AddFiles = ".",
        [switch] $PassThru
    )

    $FileExt     = Split-Path -path $FilePath -Extension

    if ( $FileExt -eq ".psm1" ) {
        $Location = Split-Path -path $FilePath
    }
    Else {
        $Location = Split-Path -path (Split-Path -path $FilePath -Parent) -parent
    }

    Set-Location $Location

    $AddFiles         = $AddFiles -join ", "

    $ArgList = @()
    $ArgList += "add"
    $ArgList += "$AddFiles"
    $ArgList += "--verbose"

    $PushMessage = (& git.exe $ArgList)

    if ( $PassThru ){
        return $PushMessage
    }
}
Function Get-CommitLog {
<#
    .SYNOPSIS
        Get commit log
    .DESCRIPTION
        Get last git commit log details.
    .EXAMPLE
        Get-CommitLog -FilePath $FilePath [-CommitPSO $CommitPSO] [-LogFileName $LogFileName] [-LogPath $LogPath=$Global:gsScriptLogFilePath] [-SaveLog $SaveLog]
    .NOTES
        AUTHOR  Alexk
        CREATED 02.11.20
        VER     1
#>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0, HelpMessage = "Script file path." )]
        [string] $FilePath,
        [Parameter(Mandatory = $false, Position = 1, HelpMessage = "Path to committed files." )]
        [pscustomobject] $CommitPSO,
        [Parameter(Mandatory = $false, Position = 2, HelpMessage = "Log file path." )]
        [string] $LogFileName,
        [Parameter(Mandatory = $false, Position = 3, HelpMessage = "Common log file path." )]
        [string] $LogPath = $Global:gsScriptLogFilePath,
        [Parameter(Mandatory = $false, Position = 4, HelpMessage = "Save log to disk." )]
        [switch] $SaveLog
    )

    $FileExt     = Split-Path -path $FilePath -Extension

    if ( $FileExt -eq ".psm1" ) {
        $Location = Split-Path -path $FilePath
    }
    Else {
        $Location = Split-Path -path (Split-Path -path $FilePath -Parent) -parent
    }

    $FileName = split-path -path $FilePath -LeafBase
    $Log = @()

    $Log += "Commit log for [$FileName]"
    $Log += "=========================="

    if ( $CommitPSO.AddFilesToCommit ) {
        $Log += ""
        $Log += "Add files to commit:"
        foreach ( $line in $CommitPSO.AddFilesToCommit ){
            $Log += "    $line"
        }
    }

    if ( $CommitPSO.Commit ) {
        $Log += ""
        $Log += "Commit:"
        foreach ( $line in $CommitPSO.Commit ){
            $Log += "    $line"
        }
    }

    if ( $CommitPSO.PushMessage ) {
        $Log += ""
        $Log += "Push:"
        foreach ( $line in $CommitPSO.PushMessage ){
            $Log += "    $line"
        }
    }

    if ( $SaveLog ){
        if ( !$LogFileName ){
            $LogPathParent = Split-Path -path $LogPath -Parent
            $LogFileName   = "$LogPathParent\Commit.log"
        }
        if ( $Log ){
            $Log | Out-File -FilePath $LogFileName -force
            Add-ToLog -Message "Saved log file [$LogFileName]" -logFilePath $LogPath -Display -Status "info"
        }
    }

    return $true
}
Function Get-ProjectOrigin {
<#
    .SYNOPSIS
        Get project origin
    .DESCRIPTION
        Get git project origin.
    .EXAMPLE
        Get-ProjectOrigin -FilePath $FilePath
    .NOTES
        AUTHOR  Alexk
        CREATED 02.11.20
        VER     1
#>
        [OutputType([string])]
        [CmdletBinding()]
        param (
            [Parameter(Mandatory = $true, Position = 0, HelpMessage = "Script file path." )]
            [string] $FilePath
        )

        $FileExt     = Split-Path -path $FilePath -Extension

        if ( $FileExt -eq ".psm1" ) {
            $Location = Split-Path -path $FilePath
        }
        Else {
            $Location = Split-Path -path (Split-Path -path $FilePath -Parent) -parent
        }
        $ModuleName = split-path -path $FilePath -LeafBase
        Set-Location -path $Location

        $Origin = & git config --get remote.origin.url

        if ( !$Origin ){
            $Origin = ( get-module $ModuleName | Select-Object ProjectUri ).ProjectUri
        }
        return $Origin
}
Function Get-GitRemoteBranchList {
<#
    .SYNOPSIS
        Get git remote branch list
    .DESCRIPTION
        Get git project remote branch list.
    .EXAMPLE
        Get-GitRemoteBranchList -FilePath $FilePath
    .NOTES
        AUTHOR  Alexk
        CREATED 11.11.20
        VER     1
#>
        [OutputType([PsObject[]])]
        [CmdletBinding()]
        param (
            [Parameter(Mandatory = $true, Position = 0, HelpMessage = "Script file path." )]
            [string] $FilePath
        )

        $FileExt     = Split-Path -path $FilePath -Extension

        if ( $FileExt -eq ".psm1" ) {
            $Location = Split-Path -path $FilePath
        }
        Else {
            $Location = Split-Path -path (Split-Path -path $FilePath -Parent) -parent
        }

        Set-Location $Location

        $StartArguments  = @()
        $StartArguments += "ls-remote"
        $StartArguments += "--heads"

        $BaranchList = & git $StartArguments
        $BranchArray = @()

        foreach ( $item in (1..($BaranchList.count-1))){
            $Array = $BaranchList[$item].split(" ")
            $PSO = [PSCustomObject]@{
                CommitHash = $Array[0]
                FullBranch = $Array[1]
                BranchName = $Array[1].split("/")[2]
            }

            $BranchArray += $PSO
        }

        return $BranchArray
}
Function Get-CurrentGitBranch {
<#
    .SYNOPSIS
        Get current git branch
    .DESCRIPTION
        Get git project current branch.
    .EXAMPLE
        Get-CurrentGitBranch -FilePath $FilePath
    .NOTES
        AUTHOR  Alexk
        CREATED 11.11.20
        VER     1
#>
        [OutputType([PsObject[]])]
        [CmdletBinding()]
        param (
            [Parameter(Mandatory = $true, Position = 0, HelpMessage = "Script file path." )]
            [string] $FilePath
        )

        $FileExt     = Split-Path -path $FilePath -Extension

        if ( $FileExt -eq ".psm1" ) {
            $Location = Split-Path -path $FilePath
        }
        Else {
            $Location = Split-Path -path (Split-Path -path $FilePath -Parent) -parent
        }

        Set-Location $Location


        $BranchList = & git branch

        foreach ( $item in $BranchList ){
            $Array = $item.split(" ")
            if ( $Array.count -eq 2 ){
                $CurrentBranch = $Array[1]
                break
            }

        }

        return $CurrentBranch
}
Function Open-InVscode {
<#
    .SYNOPSIS
        Open in vscode
    .DESCRIPTION
        Open files in VSCode.
    .EXAMPLE
        Parameter set: "Compare"
        Open-InVscode -FilePath $FilePath -FilePath1 $FilePath1 [-ReuseOpenWindow $ReuseOpenWindow] [-Compare $Compare] [-PassThru $PassThru]
    .NOTES
        AUTHOR  Alexk
        CREATED 04.11.20
        VER     1
#>
        [CmdletBinding()]
        param (
            [Parameter(Mandatory = $true, Position = 0, HelpMessage = "Script file path." )]
            [string] $FilePath,
            [Parameter(Mandatory = $true, Position = 1, ParameterSetName = "Compare", HelpMessage = "Script file path 1." )]
            [string] $FilePath1,
            [Parameter(Mandatory = $false, Position = 2, HelpMessage = "Open new file in existed window." )]
            [switch] $ReuseOpenWindow,
            [Parameter(Mandatory = $false, Position = 3, ParameterSetName = "Compare", HelpMessage = "Visual compare two files." )]
            [switch] $Compare,
            [Parameter(Mandatory = $false, Position = 4, ParameterSetName = "Wait", HelpMessage = "Wait until windows closed." )]
            [switch] $Wait,
            [Parameter(Mandatory = $false, Position = 5, HelpMessage = "Return object." )]
            [switch] $PassThru
        )

        $StartArguments = @()

        if ( $ReuseOpenWindow ){
            $StartArguments += "-r"
        }
        if ( $Wait ){
            $StartArguments += "-w"
        }
        if ( $Compare ){
            $StartArguments += "-d"
            $StartArguments += "`"$FilePath`""
            $StartArguments += "`"$FilePath1`""
        }
        Else {
            $StartArguments += "`"$FilePath`""
        }

        $res = & code $StartArguments

        if ( $PassThru ) {
            Return $Res
        }
}
Function Get-ASTVariableValue {
<#
    .SYNOPSIS
        Get AST variable value
    .DESCRIPTION
        Get variable value from AST.
    .EXAMPLE
        Get-ASTVariableValue -FilePath $FilePath -VariableName $VariableName
    .NOTES
        AUTHOR  Alexk
        CREATED 11.11.20
        VER     1
#>
    [OutputType([string[]])]
    [CmdletBinding()]
    param (
        [Parameter( Mandatory = $true, Position = 0, HelpMessage = "Script file path." )]
        [string] $FilePath,
        [Parameter( Mandatory = $true, Position = 1, HelpMessage = "Variable name." )]
        [string] $VariableName
    )

    # Todo: Implement line breaking "`" and line joining ";"

    $Res     = @()
    $Content = Get-Content -path $FilePath
    $Name    = $VariableName.split(".")[0]

    $Tokens    = [System.Management.Automation.PSParser]::Tokenize($Content, [ref]$null)
    $VarTokens = $Tokens | Where-Object { $_.type -eq "Variable" -and $_.Content -eq $Name }

    foreach ( $line in $VarTokens ){
        $Operators = $Tokens | Where-Object { $_.StartLine -eq $line.StartLine -and $_.type -ne "NewLine" }
        $Data      = $Operators.Content -join ""
        $Array     = $Data.split("=")
        $Var       = $Array[0]
        $Value     = $Array[1]
        if ( $Var.contains($VariableName) ){
            $ValueArray   = $Value.split("#")
            $Value        = $ValueArray[0] 
            if ( $ValueArray.count -gt 1 ){
                $Comment      = ($ValueArray | select-object -Skip 1) -join "#"
            }
            $PSO = [PSCustomObject]@{
                FilePath  = $FilePath
                Name      = $VariableName
                Value     = $Value.trim()
                Data      = $Data
                Comment   = $Comment
                StartLine = $line.StartLine
            }
            $Res += $PSO
        }
    }

    return $res
}
Function Set-ASTVariableValue {
<#
    .SYNOPSIS
        Set AST variable value
    .DESCRIPTION
        Set variable value to script file.
    .EXAMPLE
        Set-ASTVariableValue -FilePath $FilePath -VariableName $VariableName -VariableValue $VariableValue
    .NOTES
        AUTHOR  Alexk
        CREATED 11.11.20
        VER     1
#>
    [OutputType([string[]])]
    [CmdletBinding()]
    param (
        [Parameter( Mandatory = $true, Position = 0, HelpMessage = "Script file path." )]
        [string] $FilePath,
        [Parameter( Mandatory = $true, Position = 1, HelpMessage = "Variable name." )]
        [string] $VariableName,
        [Parameter( Mandatory = $true, Position = 2, HelpMessage = "Variable value." )]
        [string] $VariableValue
    )
    # Todo: Implement line breaking "`" and line joining ";"
    $Replaced = $false
    $Res      = @()
    $Content  = Get-Content -path $FilePath
    $Name     = $VariableName.split(".")[0]

    $Tokens    = [System.Management.Automation.PSParser]::Tokenize($Content, [ref]$null)
    $VarTokens = $Tokens | Where-Object { $_.type -eq "Variable" -and $_.Content -eq $Name }

    if ( $VarTokens ){
        $Content = Get-Content -Path $FilePath
        [string[]]$MultiLineContent = @()

        foreach ($item in (0..($Content.count-2))) {
            if ( !$Content[$item].contains("`n") ) {
                $MultiLineContent += "$($Content[$item])`n"
            }
            Else {
                $MultiLineContent += $Content[$item]
            }
        }
        $MultiLineContent += $Content[$Content.count - 1]
    }

    foreach ( $line in $VarTokens ){
        $FileLine    = $MultiLineContent[($line.StartLine - 1)]
        if ( $FileLine.Contains($VariableName) ){
            $FileValue        = $FileLine.split("=")[1]
            if ( $FileValue ) {           
                if ( $FileValue -notlike "*$VariableName*" ) {
                    if ( $FileValue -ne $VariableValue ) {
                        $FileValue        = $FileValue.split("#")[0]                                            
                        $NewFileLine      = $FileLine.replace($FileValue.trim(), $VariableValue)
                        $MultiLineContent = $MultiLineContent.Replace($FileLine, $NewFileLine)
                        $Replaced         = $true
                    }
                }
            }
        }
    }

    if ( $Replaced ) {
        $MultiLineContent | Out-File -FilePath $FilePath -Encoding utf8BOM -force -NoNewline
    }
}

Export-ModuleMember -Function Get-FunctionDetails, Get-FunctionChanges, Get-CommitInfo, Get-ChangeLog, Get-ModuleVersion, Start-FunctionTest, Remove-RightSpace, Start-ScriptAnalyzer, Update-HelpContent, Update-ModuleMetaData, Get-ChangeStatus, Set-ChangeStatus, Update-EmptySettings, Get-ModuleHelpContent, Get-PesterTemplate, Get-CommentRegions, New-ModuleMetaData, Get-ProjectGitStatus, Invoke-GitCommit, Get-CommitLog, Get-ProjectOrigin, Open-InVscode, Invoke-GitPush, Invoke-GitAdd, Get-GitRemoteBranchList, Get-CurrentGitBranch, Get-ASTVariableValue, Set-ASTVariableValue