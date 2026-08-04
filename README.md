# Sample .NET Framework WCF Catalog Service

A .NET Framework 4.8 WCF SOAP service exposing a product catalog, provided as a fixed,
self-contained **input** for WCF-to-ASP.NET Core Web API transformation experiments with
AWS Transform Custom.

This repository contains only the legacy WCF service — the starting point. It does not contain a
converted Web API project; producing one is the exercise.

The code is the `eShopWCFService` project from Microsoft's **eShop** modernization reference
application, reproduced here as a standalone sample. It is deliberately kept **as-is**: the
legacy patterns are the point of the sample, not defects to be fixed.

> **This sample bundles third-party code.** The contents of `src/` come from the
> `eShopLegacyNTier` solution in
> [dotnet-architecture/eShopModernizing](https://github.com/dotnet-architecture/eShopModernizing),
> © .NET Foundation and Contributors, MIT licensed. See [Provenance](#provenance) and
> [License](#license).

## Project Structure

```
.
├── src/
│   └── eShopWCFService/
│       ├── CatalogService.svc            # Service host directive
│       ├── CatalogService.svc.cs         # ICatalogService implementation (EF-backed)
│       ├── ICatalogService.cs            # [ServiceContract] — 10 operations
│       ├── CatalogServiceMock.cs         # In-memory ICatalogService implementation
│       ├── CatalogServiceClient.cs       # Partial ClientBase<T> proxy (not compiled)
│       ├── EntityModel.cs                # EF6 DbContext
│       ├── Models/
│       │   ├── CatalogItem.cs            # [DataContract] entities
│       │   ├── CatalogBrand.cs
│       │   ├── CatalogType.cs
│       │   ├── CatalogItemsStock.cs
│       │   ├── DiscountItem.cs
│       │   └── Infrastructure/
│       │       ├── CatalogConfiguration.cs   # Connection-string resolution
│       │       ├── CatalogDBInitializer.cs   # CreateDatabaseIfNotExists + seeding
│       │       └── PreconfiguredData.cs      # Seed data
│       ├── Properties/
│       │   └── AssemblyInfo.cs
│       ├── Web.config                    # WCF endpoints, EF provider, connection string
│       ├── Web.Debug.config              # Transform: Debug
│       ├── Web.Release.config            # Transform: Release
│       ├── packages.config               # EntityFramework 6.1.3
│       ├── eShopWCFService.csproj        # Non-SDK project, .NET Framework 4.8
│       └── eShopWCFService.slnx          # Solution file
├── Test-CatalogService.ps1               # SOAP smoke test (read-only)
├── LICENSE                               # MIT-0, for this sample's own contributions
├── NOTICE                                # Third-party attribution
├── THIRD-PARTY-LICENSES                  # Upstream MIT license text
├── CONTRIBUTING.md
├── CODE_OF_CONDUCT.md
└── SECURITY.md
```

## Overview

| | |
|---|---|
| Framework | .NET Framework 4.8 (upstream targeted 4.6.1) |
| Service style | WCF SOAP, `basicHttpBinding`, `CatalogService.svc` |
| Contract | `ICatalogService` — 10 `[OperationContract]` methods |
| Data access | Entity Framework 6.1.3, SQL Server LocalDB |
| Project format | Non-SDK `.csproj` with `packages.config`, plus an `.slnx` solution |
| Size | 13 compiled C# files, ~673 lines |
| Tests | None upstream; `Test-CatalogService.ps1` added here as a SOAP smoke test |

### Service operations

| Operation | Returns |
|---|---|
| `FindCatalogItem(int id)` | `CatalogItem` (null if absent) |
| `GetCatalogItems(int brandIdFilter, int typeIdFilter)` | `List<CatalogItem>` — 0 means no filter |
| `CreateCatalogItem(CatalogItem)` | `void` |
| `UpdateCatalogItem(CatalogItem)` | `void` |
| `RemoveCatalogItem(CatalogItem)` | `void` |
| `GetCatalogBrands()` | `List<CatalogBrand>` |
| `GetCatalogTypes()` | `List<CatalogType>` |
| `GetAvailableStock(DateTime date, int catalogItemId)` | `int` — 0 if no record |
| `CreateAvailableStock(CatalogItemsStock)` | `void` — upsert by item + date |
| `GetDiscount(DateTime day)` | `DiscountItem` (null if none active) |

## Legacy Patterns Demonstrated

These are the characteristics that make the sample useful as a migration baseline. Each is a
pattern a modernization effort has to address deliberately, and each is representative of real
legacy .NET code:

- **WCF SOAP service model** — `[ServiceContract]` / `[OperationContract]` / `[DataContract]`,
  with endpoints and bindings configured in `Web.config`
- **`IDisposable` on the service contract** — `[ServiceContract]` sits on an interface that also
  inherits `IDisposable`, with the implementation constructing its own `DbContext`
- **In-memory filtering** — `.ToList()` before `.Where(...)` in three operations, pulling whole
  tables into memory
- **Client-assigned keys** — `Max(Id) + 1` assignment with
  `[DatabaseGenerated(DatabaseGeneratedOption.None)]` on the keys, which does not survive
  concurrency
- **Null and `void` as protocol** — operations return `null` to signal absence and `void` to
  signal completion, with no fault contracts
- **SQL Server-specific mapping** — `HasPrecision(19, 4)` and a `money` column type on the price
  property; `date` column types on the date properties
- **Fully synchronous data access** — no `async`/`await` anywhere
- **Non-SDK project format** — `packages.config` NuGet, `HintPath` assembly references, and
  MSBuild `WebApplication.targets`
- **Config-driven, machine-local database** — a LocalDB connection string in `Web.config`, plus
  `Web.Debug.config` / `Web.Release.config` XDT transforms
- **Insecure development defaults left enabled** — `directoryBrowse enabled="true"`, `compilation
  debug="true"`, and `serviceMetadata httpGetEnabled="true"` in `Web.config`

The sample also carries a few genuine defects and inconsistencies, preserved intentionally
because migration tooling and reviewers encounter exactly this kind of thing:

- `RemoveCatalogItem` hands a detached, deserialized entity to `DbSet.Remove`, which EF6 rejects
  because it is untracked, so the operation faults with HTTP 500 over SOAP. `UpdateCatalogItem`
  avoids this by assigning `Entry(...).State` instead.
- `Web.config` declares `httpRuntime targetFramework="4.6.1"` while `compilation` targets 4.8 —
  a mismatch left by the retarget.
- `RootNamespace` and `AssemblyName` are still the Visual Studio default `WcfService1`, while the
  code namespace is `eShopWCFService`.
- `CatalogServiceClient.cs` is an incomplete `ClientBase<ICatalogService>` proxy that does not
  compile against the current contract, and is not referenced by the `.csproj`. It is on disk but
  excluded from the build.
- `AssemblyInfo.cs` carries an empty `AssemblyCompany` and a `Copyright © 2017` string.
- The `.csproj` has a `<None>` entry for `Properties\PublishProfiles\FolderProfile.pubxml`, a file
  that is not present.

## Prerequisites

**Windows only.** This is a non-SDK project targeting .NET Framework, so `dotnet build` will not
work, and the LocalDB connection string is Windows-specific.

- Windows with Visual Studio 2019 or later, or MSBuild with the .NET Framework 4.8 targeting pack
- SQL Server LocalDB (installed with Visual Studio, or via the SQL Server Express installer)
- IIS Express, to host the service
- NuGet CLI, to restore `EntityFramework 6.1.3`
- PowerShell 5.1 or later, to run the smoke test

## Building

```powershell
# the .csproj resolves assemblies via ..\packages, so restore into src\packages
nuget restore src\eShopWCFService\packages.config -PackagesDirectory src\packages
msbuild src\eShopWCFService\eShopWCFService.csproj /p:Configuration=Release
```

`CatalogDBInitializer` seeds reference data on first run via `CreateDatabaseIfNotExists`, so no
migration or schema script is needed. The connection string in `Web.config` points at
`(localdb)\MSSQLLocalDB`.

`CatalogConfiguration` reads a `ConnectionString` environment variable and only falls back to the
`EntityModel` entry in `Web.config` when it is absent, so setting that variable redirects EF at a
different database without editing any config file.

## Running

```powershell
$env:ConnectionString = 'Data Source=(localdb)\eShopLocal;Initial Catalog=eShopDatabase;Integrated Security=True;MultipleActiveResultSets=True'
& 'C:\Program Files\IIS Express\iisexpress.exe' /path:"$PWD\src\eShopWCFService" /port:62314 /clr:v4.0
```

The service is then at `http://localhost:62314/CatalogService.svc`, with WSDL at
`http://localhost:62314/CatalogService.svc?wsdl`.

## Testing

`Test-CatalogService.ps1` calls every read operation over SOAP and checks each response against
the seeded data. It is read-only, so it is safe to run repeatedly.

```powershell
# with the service already running, in a second window
.\Test-CatalogService.ps1
```

Each check prints the operation name, its `SOAPAction`, the parameters sent, what was expected and
what came back. The script exits non-zero if anything fails, so it works in a build step. Use
`-BaseUrl` if the service is hosted somewhere other than `http://localhost:62314`.

The four mutating operations are deliberately not covered, because `RemoveCatalogItem` faults (see
[Legacy Patterns Demonstrated](#legacy-patterns-demonstrated)) and a create/delete round trip
therefore cannot clean up after itself.

## WCF to Web API Transformation

This sample is the input side of a WCF-to-ASP.NET Core Web API migration. The mappings a
transformation has to make, and which make this service a useful test case:

| WCF construct here | ASP.NET Core equivalent |
|---|---|
| `[ServiceContract]` on `ICatalogService` | Controller class, or a set of minimal API endpoints |
| `[OperationContract]` methods | Actions with `[HttpGet]` / `[HttpPost]` / `[HttpPut]` / `[HttpDelete]` |
| `[DataContract]` / `[DataMember]` entities | Plain DTOs serialized as JSON |
| `CatalogService.svc` + `Web.config` endpoints | `Program.cs` startup and routing |
| `Web.config` connection string and XDT transforms | `appsettings.json` plus environment overrides |
| Constructor-instantiated `DbContext`, `IDisposable` contract | `DbContext` registered in DI with a scoped lifetime |
| Entity Framework 6.1.3 | EF Core |
| `null` returns to signal absence | `NotFound()` / `404` |
| `void` returns to signal completion | `NoContent()` / `204`, or `CreatedAtAction` for creates |
| SOAP faults | `ProblemDetails` error responses |
| Synchronous data access | `async` actions with `await` and `CancellationToken` |
| `basicHttpBinding` over HTTP | Kestrel with HTTPS redirection |

The operations are not uniformly straightforward, which is the point. `GetCatalogItems` uses `0` as
a sentinel for "no filter" and needs to become optional query parameters. `CreateAvailableStock` is
an upsert behind a create-shaped name. `RemoveCatalogItem` takes a whole entity where a REST delete
would take an id — and is also the operation that currently faults. A transformation that only
renames attributes will carry all of this across unchanged.

## Provenance

| | |
|---|---|
| Upstream repository | [dotnet-architecture/eShopModernizing](https://github.com/dotnet-architecture/eShopModernizing) |
| Upstream path | `eShopLegacyNTier/src/eShopWCFService` |
| Upstream commit | `63bc9ec` |
| Upstream license | MIT — © .NET Foundation and Contributors |
| Modifications | Retargeted 4.6.1 → 4.8 in `eShopWCFService.csproj` and `Web.config`; added `eShopWCFService.slnx` and `Test-CatalogService.ps1` |

The upstream repository holds several eShop samples — WebForms, MVC, N-tier, and their modernized
counterparts. Only the N-tier WCF service is reproduced here; its companion `eShopWinForms` client
is not included.

Keeping this `main` branch as an unmodified baseline is deliberate — it stays stable to diff
against. Anything applied on top belongs on a branch or in a fork.

## Security

See [CONTRIBUTING](CONTRIBUTING.md#security-issue-notifications) and [SECURITY](SECURITY.md) for
more information.

This sample is intended for local development and experimentation only, and is **not suitable for
production use as-is**. It intentionally retains the insecure development defaults listed under
[Legacy Patterns Demonstrated](#legacy-patterns-demonstrated) — directory browsing, debug
compilation, unauthenticated HTTP metadata publishing, and an unauthenticated `basicHttpBinding`
endpoint with no transport security. Do not expose it on an untrusted network.

## License

This sample's own contributions are licensed under the MIT-0 License. See the [LICENSE](LICENSE)
file.

The code under `src/` is third-party code reproduced from
[dotnet-architecture/eShopModernizing](https://github.com/dotnet-architecture/eShopModernizing)
and remains under its original MIT license, © .NET Foundation and Contributors. Its full license
text is in [THIRD-PARTY-LICENSES](THIRD-PARTY-LICENSES), and attribution is recorded in
[NOTICE](NOTICE).
