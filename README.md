# Sample WCF SOAP Service

A sample WCF SOAP service on .NET Framework 4.8 for demonstrating AWS Transform Custom capabilities for WCF to ASP.NET Core Web API conversion.

The code under `src/` is the `eShopWCFService` project from
[dotnet-architecture/eShopModernizing](https://github.com/dotnet-architecture/eShopModernizing),
reproduced as-is — the legacy patterns are the point of the sample, not defects to be fixed. See
[License](#license) for attribution.

## Project Structure

```
src/eShopWCFService/
├── CatalogService.svc            # Service host directive
├── CatalogService.svc.cs         # ICatalogService implementation (EF-backed)
├── ICatalogService.cs            # [ServiceContract] — 10 operations
├── CatalogServiceMock.cs         # In-memory implementation
├── CatalogServiceClient.cs       # ClientBase<T> proxy (not compiled)
├── EntityModel.cs                # EF6 DbContext
├── Models/
│   ├── CatalogItem.cs            # [DataContract] entities
│   ├── CatalogBrand.cs
│   ├── CatalogType.cs
│   ├── CatalogItemsStock.cs
│   ├── DiscountItem.cs
│   └── Infrastructure/           # Connection config, DB initializer, seed data
├── Properties/
│   └── AssemblyInfo.cs
├── Web.config                    # WCF endpoints, EF provider, connection string
├── Web.Debug.config              # XDT transform: Debug
├── Web.Release.config            # XDT transform: Release
├── packages.config               # EntityFramework 6.1.3
├── eShopWCFService.csproj        # Project file (.NET Framework 4.8)
└── eShopWCFService.slnx          # Solution file
```

## Features

This sample demonstrates WCF and legacy .NET Framework patterns that are good candidates for
conversion to ASP.NET Core Web API:

### WCF Features Demonstrated

- **Service Contracts** - `[ServiceContract]` and `[OperationContract]` on `ICatalogService`
- **Data Contracts** - `[DataContract]` and `[DataMember]` on entity classes
- **Config-driven hosting** - endpoints, `basicHttpBinding`, and behaviors declared in `Web.config`
- **`.svc` service host** - `ServiceHost` directive rather than code-based startup
- **`IDisposable` service contract** - the service constructs and owns its own `DbContext`
- **Entity Framework 6** - `DbContext` with Fluent API mapping and a database initializer
- **Synchronous data access** - no `async`/`await` anywhere
- **Non-SDK project format** - `packages.config`, `HintPath` references, `WebApplication.targets`
- **XDT config transforms** - `Web.Debug.config` and `Web.Release.config`
- **SQL Server-specific mapping** - `money` column type and `HasPrecision(19, 4)`
- **Null and void as protocol** - `null` signals absence, `void` signals completion, no fault contracts
- **Client-assigned keys** - `Max(Id) + 1` with `DatabaseGeneratedOption.None`

### Business Logic

- Catalog item management (CRUD operations)
- Brand and type lookups
- Filtering by brand and type
- Stock availability by item and date
- Discount lookup by date

## Building the Project

### Prerequisites

- Windows — this is a non-SDK .NET Framework project, so `dotnet build` will not work
- Visual Studio 2019 or later, or MSBuild with the .NET Framework 4.8 targeting pack
- SQL Server LocalDB
- IIS Express, to host the service

### Build Commands

```powershell
# the .csproj resolves assemblies via ..\packages, so restore into src\packages
nuget restore src\eShopWCFService\packages.config -PackagesDirectory src\packages
msbuild src\eShopWCFService\eShopWCFService.csproj /p:Configuration=Release
```

## Running the Application

```powershell
& 'C:\Program Files\IIS Express\iisexpress.exe' /path:"$PWD\src\eShopWCFService" /port:62314 /clr:v4.0
```

The service is then at `http://localhost:62314/CatalogService.svc`, with WSDL at
`http://localhost:62314/CatalogService.svc?wsdl`. The LocalDB database is created and seeded on
first run, so no migration or schema script is needed.

`Test-CatalogService.ps1` calls every read operation over SOAP and checks each response against the
seeded data. It is read-only, so it is safe to run repeatedly:

```powershell
# with the service already running, in a second window
.\Test-CatalogService.ps1
```

> **Note:** `RemoveCatalogItem` faults with HTTP 500 — it hands a detached entity to `DbSet.Remove`,
> which EF6 rejects. This is preserved from upstream as a realistic migration finding.

## AWS Transform Custom Demo

This project is designed to showcase WCF to ASP.NET Core Web API conversion using AWS Transform
Custom. Key conversion points include:

1. **Service Contract to Controller** - `[ServiceContract]` interface becomes a controller or minimal API endpoints
2. **Operation Contracts to Actions** - `[OperationContract]` methods map to `[HttpGet]` / `[HttpPost]` / `[HttpPut]` / `[HttpDelete]`
3. **Data Contracts to DTOs** - `[DataContract]` entities become plain classes serialized as JSON
4. **Config to Code** - `.svc` and `Web.config` endpoints become `Program.cs` startup and routing
5. **Settings** - `Web.config` connection strings and XDT transforms become `appsettings.json` with environment overrides
6. **Dependency Injection** - the self-constructed `DbContext` and `IDisposable` contract become a scoped DI registration
7. **EF6 to EF Core** - `DbContext`, Fluent API mapping, and the initializer need porting
8. **Return Conventions** - `null` becomes `404`, `void` becomes `204` or `CreatedAtAction`, SOAP faults become `ProblemDetails`
9. **Async** - synchronous data access becomes `async` actions with `await` and `CancellationToken`

Some operations need real design decisions rather than a mechanical rename: `GetCatalogItems` uses
`0` as a sentinel for "no filter" and should become optional query parameters, `CreateAvailableStock`
is an upsert behind a create-shaped name, and `RemoveCatalogItem` takes a whole entity where a REST
delete would take an id.

## Security

This sample is for local development and experimentation only, and is **not suitable for production
use as-is**. It intentionally retains insecure development defaults — directory browsing, debug
compilation, HTTP metadata publishing, and an unauthenticated endpoint with no transport security.
Do not expose it on an untrusted network. See [SECURITY.md](SECURITY.md).

## License

This sample's own contributions are licensed under the MIT-0 License. See the [LICENSE](LICENSE) file.

The code under `src/` is reproduced from
[dotnet-architecture/eShopModernizing](https://github.com/dotnet-architecture/eShopModernizing)
(`eShopLegacyNTier/src/eShopWCFService` at commit `63bc9ec`) and remains under its original MIT
license, © .NET Foundation and Contributors. Full license text is in
[THIRD-PARTY-LICENSES](THIRD-PARTY-LICENSES); attribution is recorded in [NOTICE](NOTICE).
