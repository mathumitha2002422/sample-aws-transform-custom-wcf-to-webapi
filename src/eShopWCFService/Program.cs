using eShopWCFService;
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddControllers();
builder.Services.AddOpenApi();

builder.Services.AddDbContext<EntityModel>(options =>
    options.UseSqlServer(builder.Configuration.GetConnectionString("DefaultConnection")));

if (builder.Configuration.GetValue<bool>("UseMockService"))
    builder.Services.AddScoped<ICatalogService, CatalogServiceMock>();
else
    builder.Services.AddScoped<ICatalogService, CatalogService>();

var app = builder.Build();

app.MapOpenApi();
app.MapControllers();

app.Run();
