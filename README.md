# eShop WCF Service Sample

The `eShopWCFService` project from Microsoft's **eShop** modernization reference
application, reproduced here as a standalone sample.

> **This is not original work.** The code comes from the `eShopLegacyNTier` solution in
> [dotnet-architecture/eShopModernizing](https://github.com/dotnet-architecture/eShopModernizing),
> © .NET Foundation and Contributors, MIT licensed. It is copied verbatim, unmodified.

## Provenance

| | |
|---|---|
| Upstream repository | [dotnet-architecture/eShopModernizing](https://github.com/dotnet-architecture/eShopModernizing) |
| Upstream path | `eShopLegacyNTier/src/eShopWCFService` |
| Upstream commit | `63bc9ec` |
| License | MIT — © .NET Foundation and Contributors (see `LICENSE`) |
| Modifications | None |

The upstream repository holds several eShop samples — WebForms, MVC, N-tier, and their
modernized counterparts. Only the N-tier WCF service is reproduced here. Its companion
`eShopWinForms` client is not included.

## What this is

A .NET Framework 4.6.1 WCF SOAP service exposing a product catalog.

| | |
|---|---|
| Framework | .NET Framework 4.6.1 |
| Service style | WCF SOAP, `basicHttpBinding`, `CatalogService.svc` |
| Contract | `ICatalogService` — 10 `[OperationContract]` methods |
| Data access | Entity Framework 6.1.3, SQL Server LocalDB |
| Project format | Non-SDK `.csproj` with `packages.config` |
| Size | 13 C# files, ~993 lines |
| Tests | None |

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

## Building

Windows only. This is a non-SDK project targeting .NET Framework, so it needs MSBuild and
the .NET Framework 4.6.1 targeting pack — `dotnet build` will not work.

```powershell
nuget restore
msbuild eShopWCFService.csproj
```

The connection string in `Web.config` points at `(localdb)\MSSQLLocalDB`, which is
Windows-only. `CatalogDBInitializer` seeds reference data on first run via
`CreateDatabaseIfNotExists`.

## Why this repository exists

A fixed, isolated starting point for modernization experiments — cloning one project is
easier than cloning the whole upstream repository and working out which of its several
solutions to target.

It is deliberately kept **as-is**: no fixes, no cleanup, no modernization. The legacy
patterns are the point. Anything applied on top belongs on a branch or in a fork, so this
`main` stays a faithful baseline to diff against.

Worth knowing before you use it as a baseline — the sample contains patterns that are
representative of real legacy code and that a migration has to address deliberately:

- `[ServiceContract]` on an interface that also inherits `IDisposable`, with the
  implementation constructing its own `DbContext`
- In-memory filtering — `.ToList()` then `.Where(...)` — in three operations
- `Max(Id) + 1` key assignment, with `[DatabaseGenerated(DatabaseGeneratedOption.None)]`
  on the keys
- Operations returning `null` to signal absence, and `void` to signal completion
- `HasPrecision(19, 4)` and a `money` column type on the price property
- `directoryBrowse` enabled in `Web.config`
- Fully synchronous data access

## License

MIT. See `LICENSE`, reproduced verbatim from upstream. Original work © .NET Foundation
and Contributors.
