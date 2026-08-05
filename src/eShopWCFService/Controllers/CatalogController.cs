using eShopWCFService.Models;
using Microsoft.AspNetCore.Mvc;
using System;
using System.Threading.Tasks;

namespace eShopWCFService.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class CatalogController : ControllerBase
    {
        private readonly ICatalogService _catalogService;

        public CatalogController(ICatalogService catalogService)
        {
            _catalogService = catalogService;
        }

        [HttpGet("items/{id}")]
        public async Task<IActionResult> FindCatalogItem(int id)
        {
            var item = await _catalogService.FindCatalogItemAsync(id);
            if (item == null)
                return NotFound();
            return Ok(item);
        }

        [HttpGet("brands")]
        public async Task<IActionResult> GetCatalogBrands()
        {
            var brands = await _catalogService.GetCatalogBrandsAsync();
            return Ok(brands);
        }

        [HttpGet("items")]
        public async Task<IActionResult> GetCatalogItems([FromQuery] int brandIdFilter = 0, [FromQuery] int typeIdFilter = 0)
        {
            var items = await _catalogService.GetCatalogItemsAsync(brandIdFilter, typeIdFilter);
            return Ok(items);
        }

        [HttpGet("types")]
        public async Task<IActionResult> GetCatalogTypes()
        {
            var types = await _catalogService.GetCatalogTypesAsync();
            return Ok(types);
        }

        [HttpGet("stock")]
        public async Task<IActionResult> GetAvailableStock([FromQuery] DateTime date, [FromQuery] int catalogItemId)
        {
            var stock = await _catalogService.GetAvailableStockAsync(date, catalogItemId);
            return Ok(stock);
        }

        [HttpPost("stock")]
        public async Task<IActionResult> CreateAvailableStock([FromBody] CatalogItemsStock catalogItemsStock)
        {
            await _catalogService.CreateAvailableStockAsync(catalogItemsStock);
            return NoContent();
        }

        [HttpPost("items")]
        public async Task<IActionResult> CreateCatalogItem([FromBody] CatalogItem catalogItem)
        {
            await _catalogService.CreateCatalogItemAsync(catalogItem);
            return CreatedAtAction(nameof(FindCatalogItem), new { id = catalogItem.Id }, catalogItem);
        }

        [HttpPut("items")]
        public async Task<IActionResult> UpdateCatalogItem([FromBody] CatalogItem catalogItem)
        {
            await _catalogService.UpdateCatalogItemAsync(catalogItem);
            return NoContent();
        }

        [HttpDelete("items")]
        public async Task<IActionResult> RemoveCatalogItem([FromBody] CatalogItem catalogItem)
        {
            await _catalogService.RemoveCatalogItemAsync(catalogItem);
            return NoContent();
        }

        [HttpGet("discount")]
        public async Task<IActionResult> GetDiscount([FromQuery] DateTime day)
        {
            var discount = await _catalogService.GetDiscountAsync(day);
            if (discount == null)
                return NotFound();
            return Ok(discount);
        }
    }
}
