using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Relecloud.Web.Api.Migrations
{
    public partial class SelectTicketManagementService : Migration
    {
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "TicketManagementServiceConcertId",
                table: "Concerts",
                type: "nvarchar(max)",
                nullable: false,
                defaultValue: "");

            migrationBuilder.AddColumn<int>(
                name: "TicketManagementServiceProvider",
                table: "Concerts",
                type: "int",
                nullable: false,
                defaultValue: 0);
        }

        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "TicketManagementServiceConcertId",
                table: "Concerts");

            migrationBuilder.DropColumn(
                name: "TicketManagementServiceProvider",
                table: "Concerts");
        }
    }
}
