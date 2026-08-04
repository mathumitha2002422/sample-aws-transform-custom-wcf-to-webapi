<#
.SYNOPSIS
    Smoke-tests the eShop WCF CatalogService over SOAP and reports pass/fail per operation.

.DESCRIPTION
    Calls each read operation on ICatalogService, prints the operation name, SOAPAction and
    parameters being sent, then compares the response against the values seeded by
    CatalogDBInitializer. Use this to confirm the service is hosted and returning real data
    from the database.

    Read-only by design: nothing here modifies the database, so it is safe to run repeatedly.
    The four mutating operations (CreateCatalogItem, UpdateCatalogItem, RemoveCatalogItem,
    CreateAvailableStock) are not covered. See the NOTES section.

    The service must already be running. To host it with IIS Express:

        $env:ConnectionString = 'Data Source=(localdb)\eShopLocal;Initial Catalog=eShopDatabase;Integrated Security=True;MultipleActiveResultSets=True'
        & 'C:\Program Files\IIS Express\iisexpress.exe' /path:"<repo>\src\eShopWCFService" /port:62314 /clr:v4.0

.PARAMETER BaseUrl
    Root URL where the service is hosted. Defaults to http://localhost:62314.

.EXAMPLE
    .\Test-CatalogService.ps1

.EXAMPLE
    .\Test-CatalogService.ps1 -BaseUrl http://localhost:8080

.NOTES
    Exits 0 when every test passes, 1 otherwise, so it can be used in a build step.

    RemoveCatalogItem returns HTTP 500 when called over SOAP: it passes a detached,
    deserialized entity to DbSet.Remove, which EF6 rejects because the entity is not tracked
    by the context. That makes a create/delete round trip impossible to clean up after, which
    is why the write operations are excluded from this script.
#>
[CmdletBinding()]
param(
    [string] $BaseUrl = 'http://localhost:62314'
)

# Version 1.0 only: XML navigation relies on absent properties returning $null, which
# StrictMode 2.0 turns into a terminating error.
Set-StrictMode -Version 1.0

$ServiceUrl    = "$BaseUrl/CatalogService.svc"
$ContractNs    = 'http://tempuri.org/'
$script:Passed = 0
$script:Failed = 0
$script:Step   = 0

# Seed data in CatalogDBInitializer / PreconfiguredData that these assertions rely on.
$ExpectedBrands = 5
$ExpectedTypes  = 4
$ExpectedItems  = 12

function Invoke-CatalogOperation {
    <# Posts a SOAP 1.1 request for one operation and returns the response as [xml]. #>
    param(
        [Parameter(Mandatory)] [string] $Operation,
        [string] $InnerXml = ''
    )

    $envelope = "<s:Envelope xmlns:s='http://schemas.xmlsoap.org/soap/envelope/'>" +
                "<s:Body><$Operation xmlns='$ContractNs'>$InnerXml</$Operation></s:Body></s:Envelope>"
    $action = '"' + $ContractNs + 'ICatalogService/' + $Operation + '"'

    $response = Invoke-WebRequest -Uri $ServiceUrl -Method Post `
        -ContentType 'text/xml; charset=utf-8' `
        -Headers @{ 'SOAPAction' = $action } `
        -Body $envelope -UseBasicParsing -TimeoutSec 120

    return [xml] $response.Content
}

function Get-OperationResult {
    <# Unwraps <OpResponse><OpResult>. Returns $null when the service signalled nil. #>
    param(
        [Parameter(Mandatory)] [xml] $Response,
        [Parameter(Mandatory)] [string] $Operation
    )

    $wrapper = $Response.Envelope.Body."${Operation}Response"
    if ($null -eq $wrapper) { return $null }

    $result = $wrapper."${Operation}Result"
    if ($null -eq $result) { return $null }

    # WCF emits i:nil="true" for a null return value.
    if ($result -is [System.Xml.XmlElement] -and
        $result.GetAttribute('nil', 'http://www.w3.org/2001/XMLSchema-instance') -eq 'true') {
        return $null
    }
    return $result
}

function Get-ResultCollection {
    <# Normalises a repeated child element into an array, even for 0 or 1 items. #>
    param($Result, [Parameter(Mandatory)] [string] $ChildName)

    if ($null -eq $Result) { return @() }
    return @($Result.$ChildName | Where-Object { $null -ne $_ })
}

function Write-TestResult {
    <# Prints one clearly labelled block per WCF operation. #>
    param(
        [Parameter(Mandatory)] [string] $Operation,
        [Parameter(Mandatory)] [string] $Request,
        [Parameter(Mandatory)] [string] $Expected,
        [Parameter(Mandatory)] [string] $Actual,
        [Parameter(Mandatory)] [bool]   $Success,
        [int] $ElapsedMs = 0
    )

    $script:Step++
    if ($Success) { $script:Passed++ } else { $script:Failed++ }

    Write-Host ''
    Write-Host ("[{0}] " -f $script:Step) -NoNewline -ForegroundColor DarkGray
    Write-Host "ICatalogService.$Operation" -ForegroundColor Cyan
    Write-Host ("      SOAPAction : {0}ICatalogService/{1}" -f $ContractNs, $Operation) -ForegroundColor DarkGray
    Write-Host  "      Request    : $Request"
    Write-Host  "      Expected   : $Expected"
    Write-Host  "      Actual     : $Actual"

    Write-Host  "      Status     : " -NoNewline
    if ($Success) {
        Write-Host "PASS" -NoNewline -ForegroundColor Green
    } else {
        Write-Host "FAIL" -NoNewline -ForegroundColor Red
    }
    if ($ElapsedMs -gt 0) {
        Write-Host ("  ({0} ms)" -f $ElapsedMs) -ForegroundColor DarkGray
    } else {
        Write-Host ''
    }
}

function Test-Operation {
    <# Runs one operation, evaluates it with $Check, and reports the outcome. #>
    param(
        [Parameter(Mandatory)] [string]      $Operation,
        [string]                             $InnerXml = '',
        [Parameter(Mandatory)] [string]      $Request,
        [Parameter(Mandatory)] [string]      $Expected,
        [Parameter(Mandatory)] [scriptblock] $Check
    )

    $timer = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        $xml = Invoke-CatalogOperation -Operation $Operation -InnerXml $InnerXml
        $timer.Stop()
        $result  = Get-OperationResult -Response $xml -Operation $Operation
        $verdict = & $Check $result          # returns @{ Ok = [bool]; Detail = [string] }

        Write-TestResult -Operation $Operation -Request $Request -Expected $Expected `
            -Actual $verdict.Detail -Success ([bool]$verdict.Ok) -ElapsedMs $timer.ElapsedMilliseconds
    }
    catch {
        $timer.Stop()
        Write-TestResult -Operation $Operation -Request $Request -Expected $Expected `
            -Actual ("ERROR - " + $_.Exception.Message) -Success $false -ElapsedMs $timer.ElapsedMilliseconds
    }
}

# ---------------------------------------------------------------------------------------
# Header and reachability check
# ---------------------------------------------------------------------------------------

Write-Host ''
Write-Host '=======================================================================' -ForegroundColor White
Write-Host ' eShop WCF CatalogService - smoke test' -ForegroundColor White
Write-Host '=======================================================================' -ForegroundColor White
Write-Host " Endpoint : $ServiceUrl"
Write-Host " Contract : ICatalogService (basicHttpBinding, SOAP 1.1)"
Write-Host " Scope    : read-only operations, no data is modified"
Write-Host " Started  : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"

try {
    $null = Invoke-WebRequest -Uri "${ServiceUrl}?wsdl" -UseBasicParsing -TimeoutSec 30
    Write-Host " Metadata : WSDL reachable" -ForegroundColor Green
}
catch {
    Write-Host " Metadata : UNREACHABLE - $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ''
    Write-Host "The service does not appear to be running at $BaseUrl." -ForegroundColor Yellow
    Write-Host 'Start it with IIS Express (see the comment block at the top of this script),' -ForegroundColor Yellow
    Write-Host 'then run this script again.' -ForegroundColor Yellow
    exit 1
}

# ---------------------------------------------------------------------------------------
# Read operations
# ---------------------------------------------------------------------------------------

Test-Operation -Operation 'GetCatalogBrands' `
    -Request '(no parameters)' `
    -Expected "$ExpectedBrands brands" `
    -Check {
        param($r)
        $brands = Get-ResultCollection -Result $r -ChildName 'CatalogBrand'
        @{
            Ok     = ($brands.Count -eq $ExpectedBrands)
            Detail = "$($brands.Count) brands -> " + (($brands | ForEach-Object { $_.Brand }) -join ', ')
        }
    }

Test-Operation -Operation 'GetCatalogTypes' `
    -Request '(no parameters)' `
    -Expected "$ExpectedTypes types" `
    -Check {
        param($r)
        $types = Get-ResultCollection -Result $r -ChildName 'CatalogType'
        @{
            Ok     = ($types.Count -eq $ExpectedTypes)
            Detail = "$($types.Count) types -> " + (($types | ForEach-Object { $_.Type }) -join ', ')
        }
    }

Test-Operation -Operation 'GetCatalogItems' `
    -InnerXml '<brandIdFilter>0</brandIdFilter><typeIdFilter>0</typeIdFilter>' `
    -Request 'brandIdFilter=0, typeIdFilter=0  (0 means no filter)' `
    -Expected "$ExpectedItems items" `
    -Check {
        param($r)
        $items = Get-ResultCollection -Result $r -ChildName 'CatalogItem'
        $first = if ($items.Count -gt 0) { "; first = '$($items[0].Name)' at $($items[0].Price)" } else { '' }
        @{
            Ok     = ($items.Count -eq $ExpectedItems)
            Detail = "$($items.Count) items$first"
        }
    }

Test-Operation -Operation 'GetCatalogItems' `
    -InnerXml '<brandIdFilter>2</brandIdFilter><typeIdFilter>0</typeIdFilter>' `
    -Request 'brandIdFilter=2 (.NET), typeIdFilter=0' `
    -Expected '6 items, all of brand 2' `
    -Check {
        param($r)
        $items = Get-ResultCollection -Result $r -ChildName 'CatalogItem'
        $allBrand2 = ($items.Count -gt 0) -and -not ($items | Where-Object { $_.CatalogBrandId -ne '2' })
        @{
            Ok     = (($items.Count -eq 6) -and $allBrand2)
            Detail = "$($items.Count) items -> " + (($items | ForEach-Object { $_.Name }) -join ', ')
        }
    }

Test-Operation -Operation 'GetCatalogItems' `
    -InnerXml '<brandIdFilter>0</brandIdFilter><typeIdFilter>1</typeIdFilter>' `
    -Request 'brandIdFilter=0, typeIdFilter=1 (Mug)' `
    -Expected '2 items, all of type 1' `
    -Check {
        param($r)
        $items = Get-ResultCollection -Result $r -ChildName 'CatalogItem'
        $allType1 = ($items.Count -gt 0) -and -not ($items | Where-Object { $_.CatalogTypeId -ne '1' })
        @{
            Ok     = (($items.Count -eq 2) -and $allType1)
            Detail = "$($items.Count) items -> " + (($items | ForEach-Object { $_.Name }) -join ', ')
        }
    }

Test-Operation -Operation 'FindCatalogItem' `
    -InnerXml '<id>1</id>' `
    -Request 'id=1' `
    -Expected "'.NET Bot Black Hoodie', brand .NET, type T-Shirt" `
    -Check {
        param($r)
        if ($null -eq $r) { return @{ Ok = $false; Detail = 'null returned' } }
        $ok = ($r.Name -eq '.NET Bot Black Hoodie') -and
              ($r.CatalogBrand.Brand -eq '.NET') -and
              ($r.CatalogType.Type -eq 'T-Shirt')
        @{
            Ok     = $ok
            Detail = "'$($r.Name)', price $($r.Price), brand $($r.CatalogBrand.Brand), type $($r.CatalogType.Type), picture $($r.Picturefilename)"
        }
    }

Test-Operation -Operation 'FindCatalogItem' `
    -InnerXml '<id>999999</id>' `
    -Request 'id=999999 (absent)' `
    -Expected 'null (legacy absence signal)' `
    -Check {
        param($r)
        @{
            Ok     = ($null -eq $r)
            Detail = if ($null -eq $r) { 'null, as expected' } else { "unexpected item '$($r.Name)'" }
        }
    }

Test-Operation -Operation 'GetAvailableStock' `
    -InnerXml '<date>2017-09-20T00:00:00</date><catalogItemId>1</catalogItemId>' `
    -Request 'date=2017-09-20, catalogItemId=1' `
    -Expected '100' `
    -Check {
        param($r)
        $value = if ($null -eq $r) { '(none)' } else { $r.ToString() }
        @{ Ok = ($value -eq '100'); Detail = "AvailableStock = $value" }
    }

Test-Operation -Operation 'GetAvailableStock' `
    -InnerXml '<date>1999-01-01T00:00:00</date><catalogItemId>1</catalogItemId>' `
    -Request 'date=1999-01-01, catalogItemId=1 (no stock row)' `
    -Expected '0 (legacy absence signal)' `
    -Check {
        param($r)
        $value = if ($null -eq $r) { '(none)' } else { $r.ToString() }
        @{ Ok = ($value -eq '0'); Detail = "AvailableStock = $value" }
    }

Test-Operation -Operation 'GetDiscount' `
    -InnerXml '<day>2017-09-19T00:00:00</day>' `
    -Request 'day=2017-09-19 (inside 2017-09-18..2017-09-21)' `
    -Expected 'the discount covering that day' `
    -Check {
        param($r)
        if ($null -eq $r) { return @{ Ok = $false; Detail = 'null returned' } }
        @{
            Ok     = ($r.Id -eq '1')
            Detail = "Id $($r.Id), $($r.Start) to $($r.End), size $($r.Size)"
        }
    }

Test-Operation -Operation 'GetDiscount' `
    -InnerXml '<day>2020-01-01T00:00:00</day>' `
    -Request 'day=2020-01-01 (outside every discount window)' `
    -Expected 'null (legacy absence signal)' `
    -Check {
        param($r)
        @{
            Ok     = ($null -eq $r)
            Detail = if ($null -eq $r) { 'null, as expected' } else { "unexpected discount Id $($r.Id)" }
        }
    }

# ---------------------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------------------

$total = $script:Passed + $script:Failed

Write-Host ''
Write-Host '=======================================================================' -ForegroundColor White
Write-Host ' Summary: ' -NoNewline
Write-Host "$script:Passed passed" -NoNewline -ForegroundColor Green
Write-Host ', ' -NoNewline
if ($script:Failed -gt 0) {
    Write-Host "$script:Failed failed" -NoNewline -ForegroundColor Red
} else {
    Write-Host '0 failed' -NoNewline -ForegroundColor Green
}
Write-Host " of $total checks"
Write-Host '=======================================================================' -ForegroundColor White

if ($script:Failed -gt 0) {
    Write-Host ''
    Write-Host 'Some checks failed. Common causes:' -ForegroundColor Yellow
    Write-Host '  - the ConnectionString environment variable was not set for the host process,' -ForegroundColor Yellow
    Write-Host '    so it fell back to Web.config and (localdb)\MSSQLLocalDB' -ForegroundColor Yellow
    Write-Host '  - the service is pointed at a database that was never seeded' -ForegroundColor Yellow
    Write-Host '  - rows were added or removed, so the seeded counts no longer match' -ForegroundColor Yellow
    Write-Host ''
    exit 1
}

Write-Host ''
Write-Host 'CatalogService is hosted and returning the expected seed data.' -ForegroundColor Green
Write-Host ''
exit 0
