using eShopWCFService.Models;
using Microsoft.EntityFrameworkCore;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

namespace eShopWCFService
{
    public class CatalogService : ICatalogService
    {
        private readonly EntityModel _context;

        public CatalogService(EntityModel context)
        {
            _context = context;
        }

        public async Task<DiscountItem> GetDiscountAsync(DateTime day)
        {
            return await _context.DiscountItems
                .Where(y => y.Start.Date <= day.Date && y.End.Date >= day.Date)
                .FirstOrDefaultAsync();
        }

        public async Task<CatalogItem> FindCatalogItemAsync(int id)
        {
            return await _context.CatalogItems
                .Include(i => i.CatalogBrand)
                .Include(i => i.CatalogType)
                .FirstOrDefaultAsync(x => x.Id == id);
        }

        public async Task<List<CatalogType>> GetCatalogTypesAsync()
        {
            return await _context.CatalogTypes.ToListAsync();
        }

        public async Task<List<CatalogBrand>> GetCatalogBrandsAsync()
        {
            return await _context.CatalogBrands.ToListAsync();
        }

        public async Task<List<CatalogItem>> GetCatalogItemsAsync(int brandIdFilter, int typeIdFilter)
        {
            var query = _context.CatalogItems.AsQueryable();

            if (brandIdFilter != 0)
                query = query.Where(x => x.CatalogBrandId == brandIdFilter);

            if (typeIdFilter != 0)
                query = query.Where(x => x.CatalogTypeId == typeIdFilter);

            return await query.ToListAsync();
        }

        public async Task CreateCatalogItemAsync(CatalogItem catalogItem)
        {
            var maxId = await _context.CatalogItems.MaxAsync(i => i.Id);
            catalogItem.Id = ++maxId;
            _context.CatalogItems.Add(catalogItem);
            await _context.SaveChangesAsync();
        }

        public async Task UpdateCatalogItemAsync(CatalogItem catalogItem)
        {
            _context.Entry(catalogItem).State = EntityState.Modified;
            await _context.SaveChangesAsync();
        }

        public async Task RemoveCatalogItemAsync(CatalogItem catalogItem)
        {
            _context.CatalogItems.Remove(catalogItem);
            await _context.SaveChangesAsync();
        }

        public async Task<int> GetAvailableStockAsync(DateTime date, int catalogItemId)
        {
            var stock = await _context.CatalogItemsStocks
                .Where(x => x.CatalogItemId == catalogItemId && x.Date.Date == date.Date)
                .FirstOrDefaultAsync();

            return stock?.AvailableStock ?? 0;
        }

        public async Task CreateAvailableStockAsync(CatalogItemsStock catalogItemsStock)
        {
            var existing = await _context.CatalogItemsStocks
                .Where(x => x.CatalogItemId == catalogItemsStock.CatalogItemId && x.Date.Date == catalogItemsStock.Date.Date)
                .FirstOrDefaultAsync();

            if (existing != null)
            {
                existing.AvailableStock = catalogItemsStock.AvailableStock;
                _context.Entry(existing).State = EntityState.Modified;
                await _context.SaveChangesAsync();
            }
            else
            {
                var maxId = await _context.CatalogItemsStocks.MaxAsync(i => i.StockId);
                catalogItemsStock.StockId = ++maxId;
                _context.CatalogItemsStocks.Add(catalogItemsStock);
                await _context.SaveChangesAsync();
            }
        }
    }
}
