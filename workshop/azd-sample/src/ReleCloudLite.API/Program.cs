using Microsoft.AspNetCore.Mvc;
using ReleCloudLite.API.Data;
using ReleCloudLite.API.Service;
using ReleCloudLite.API.Mocks;
using ReleCloudLite.Models;


var builder = WebApplication.CreateBuilder(args);

// Add services to the container.
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

builder.Services.AddTransient<ITicketContext, MockTicketContext>();

var app = builder.Build();

// Configure the HTTP request pipeline.
if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Error", createScopeForErrors: true);
    // The default HSTS value is 30 days. You may want to change this for production scenarios, see https://aka.ms/aspnetcore-hsts.
    app.UseHsts();
} else
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseHttpsRedirection();

app.MapGet("/tickets", async (ITicketContext ticketContext) =>
{
    var tickets = await ticketContext.GetTicketsAsync();
    return tickets != null ? Results.Ok(tickets) : Results.NotFound();
})
.WithName("GetAllTickets")
.Produces<IEnumerable<Ticket>>(StatusCodes.Status200OK);

app.Run();
