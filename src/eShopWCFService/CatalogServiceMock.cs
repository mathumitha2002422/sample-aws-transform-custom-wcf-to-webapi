using eShopWCFService.Models;
using eShopWCFService.Models.Infrastructure;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

namespace eShopWCFService
{
    public class CatalogServiceMock : ICatalogService
    {
        private List<CatalogItem> catalogItems;
        private List<CatalogBrand> catalogBrands;
        private List<CatalogType> catalogTypes;
        private List<CatalogItemsStock> catalogItemsStock;

        public CatalogServiceMock()
        {
            catalogItems = new List<CatalogItem>(PreconfiguredData.GetPreconfiguredCatalogItems());
            catalogBrands = new List<CatalogBrand>(PreconfiguredData.GetPreconfiguredCatalogBrands());
            catalogTypes = new List<CatalogType>(PreconfiguredData.GetPreconfiguredCatalogTypes());
            catalogItemsStock = new List<CatalogItemsStock>(PreconfiguredData.GetPreconfiguredCatalogItemsStock());
        }

        public Task<CatalogItem> FindCatalogItemAsync(int id)
        {
            return Task.FromResult(catalogItems.FirstOrDefault(x => x.Id == id));
        }

        public Task<List<CatalogItem>> GetCatalogItemsAsync(int brandIdFilter, int typeIdFilter)
        {
            bool brandFilterIsNull = brandIdFilter == 0;
            bool typeFilterIsNull = typeIdFilter == 0;
            var result = catalogItems.Where(x =>
                (brandFilterIsNull || x.CatalogBrandId == brandIdFilter) &&
                (typeFilterIsNull || x.CatalogTypeId == typeIdFilter)).ToList();
            return Task.FromResult(result);
        }

        public Task<List<CatalogType>> GetCatalogTypesAsync()
        {
            return Task.FromResult(catalogTypes);
        }

        public Task<List<CatalogBrand>> GetCatalogBrandsAsync()
        {
            return Task.FromResult(catalogBrands);
        }

        public Task CreateCatalogItemAsync(CatalogItem catalogItem)
        {
            var maxId = catalogItems.Max(i => i.Id);
            catalogItem.Id = ++maxId;
            catalogItems.Add(catalogItem);
            return Task.CompletedTask;
        }

        public Task UpdateCatalogItemAsync(CatalogItem modifiedItem)
        {
            var originalItem = catalogItems.FirstOrDefault(x => x.Id == modifiedItem.Id);
            if (originalItem != null)
            {
                catalogItems[catalogItems.IndexOf(originalItem)] = modifiedItem;
            }
            return Task.CompletedTask;
        }

        public Task RemoveCatalogItemAsync(CatalogItem catalogItem)
        {
            catalogItems.Remove(catalogItem);
            return Task.CompletedTask;
        }

        public Task<int> GetAvailableStockAsync(DateTime date, int catalogItemId)
        {
            var stock = catalogItemsStock.FirstOrDefault(x => x.CatalogItemId == catalogItemId && x.Date.Date == date.Date);
            return Task.FromResult(stock?.AvailableStock ?? 0);
        }

        public Task CreateAvailableStockAsync(CatalogItemsStock cat)
        {
            var existing = catalogItemsStock
                .Where(x => x.CatalogItemId == cat.CatalogItemId)
                .FirstOrDefault(y => y.Date.Date == cat.Date.Date);

            if (existing != null)
            {
                existing.AvailableStock = cat.AvailableStock;
            }
            else
            {
                var maxId = catalogItemsStock.Max(i => i.StockId);
                cat.StockId = ++maxId;
                catalogItemsStock.Add(cat);
            }
            return Task.CompletedTask;
        }

        public Task<DiscountItem> GetDiscountAsync(DateTime day)
        {
            return Task.FromResult<DiscountItem>(null);
        }
    }
}
