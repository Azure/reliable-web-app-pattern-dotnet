using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Relecloud.Web.Api.Migrations
{
    public partial class CreateTicketNumbers : Migration
    {
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "TicketNumbers",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    Number = table.Column<string>(type: "nvarchar(450)", nullable: false),
                    TicketId = table.Column<int>(type: "int", nullable: true),
                    ConcertId = table.Column<int>(type: "int", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_TicketNumbers", x => x.Id);
                });

            migrationBuilder.CreateIndex(
                name: "IX_TicketNumbers_Number_ConcertId",
                table: "TicketNumbers",
                columns: new[] { "Number", "ConcertId" },
                unique: true);
        }

        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "TicketNumbers");
        }
    }
}
