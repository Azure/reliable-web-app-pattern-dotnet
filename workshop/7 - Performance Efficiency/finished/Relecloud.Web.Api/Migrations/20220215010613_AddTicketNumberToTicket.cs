using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Relecloud.Web.Api.Migrations
{
    public partial class AddTicketNumberToTicket : Migration
    {
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "TicketNumber",
                table: "Tickets",
                type: "nvarchar(max)",
                nullable: false,
                defaultValue: "");

            migrationBuilder.CreateIndex(
                name: "IX_TicketNumbers_TicketId",
                table: "TicketNumbers",
                column: "TicketId");

            migrationBuilder.AddForeignKey(
                name: "FK_TicketNumbers_Tickets_TicketId",
                table: "TicketNumbers",
                column: "TicketId",
                principalTable: "Tickets",
                principalColumn: "Id");
        }

        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_TicketNumbers_Tickets_TicketId",
                table: "TicketNumbers");

            migrationBuilder.DropIndex(
                name: "IX_TicketNumbers_TicketId",
                table: "TicketNumbers");

            migrationBuilder.DropColumn(
                name: "TicketNumber",
                table: "Tickets");
        }
    }
}
