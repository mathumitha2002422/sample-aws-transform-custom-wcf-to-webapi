namespace eShopWCFService.Models
{
    using System.ComponentModel.DataAnnotations;
    using System.ComponentModel.DataAnnotations.Schema;

    public partial class CatalogItem
    {
        [DatabaseGenerated(DatabaseGeneratedOption.None)]
        public int Id { get; set; }
        public string Description { get; set; }
        public string Name { get; set; }

        [Column(TypeName = "money")]
        public decimal Price { get; set; }
        public string Picturefilename { get; set; }
        public int CatalogBrandId { get; set; }
        public int CatalogTypeId { get; set; }

        public CatalogType CatalogType { get; set; }

        public CatalogBrand CatalogBrand { get; set; }
    }
}
