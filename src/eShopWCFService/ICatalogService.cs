using eShopWCFService.Models;
using System;
using System.Collections.Generic;
using System.Threading.Tasks;

namespace eShopWCFService
{
    public interface ICatalogService
    {
        Task<CatalogItem> FindCatalogItemAsync(int id);
        Task<List<CatalogBrand>> GetCatalogBrandsAsync();
        Task<List<CatalogItem>> GetCatalogItemsAsync(int brandIdFilter, int typeIdFilter);
        Task<List<CatalogType>> GetCatalogTypesAsync();
        Task<int> GetAvailableStockAsync(DateTime date, int catalogItemId);
        Task CreateAvailableStockAsync(CatalogItemsStock catalogItemsStock);
        Task CreateCatalogItemAsync(CatalogItem catalogItem);
        Task UpdateCatalogItemAsync(CatalogItem catalogItem);
        Task RemoveCatalogItemAsync(CatalogItem catalogItem);
        Task<DiscountItem> GetDiscountAsync(DateTime day);
    }
}
