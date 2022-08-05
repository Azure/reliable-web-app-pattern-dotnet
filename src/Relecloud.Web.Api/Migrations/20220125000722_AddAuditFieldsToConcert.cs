using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Relecloud.Web.Api.Migrations
{
    public partial class AddAuditFieldsToConcert : Migration
    {
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "IsDeleted",
                table: "Concerts");

            migrationBuilder.AddColumn<string>(
                name: "CreatedBy",
                table: "Concerts",
                type: "nvarchar(max)",
                nullable: false,
                defaultValue: "");

            migrationBuilder.AddColumn<DateTimeOffset>(
                name: "CreatedOn",
                table: "Concerts",
                type: "datetimeoffset",
                nullable: false,
                defaultValue: new DateTimeOffset(new DateTime(1, 1, 1, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)));

            migrationBuilder.AddColumn<string>(
                name: "UpdatedBy",
                table: "Concerts",
                type: "nvarchar(max)",
                nullable: false,
                defaultValue: "");

            migrationBuilder.AddColumn<DateTimeOffset>(
                name: "UpdatedOn",
                table: "Concerts",
                type: "datetimeoffset",
                nullable: false,
                defaultValue: new DateTimeOffset(new DateTime(1, 1, 1, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)));
        }

        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "CreatedBy",
                table: "Concerts");

            migrationBuilder.DropColumn(
                name: "CreatedOn",
                table: "Concerts");

            migrationBuilder.DropColumn(
                name: "UpdatedBy",
                table: "Concerts");

            migrationBuilder.DropColumn(
                name: "UpdatedOn",
                table: "Concerts");

            migrationBuilder.AddColumn<bool>(
                name: "IsDeleted",
                table: "Concerts",
                type: "bit",
                nullable: false,
                defaultValue: false);
        }
    }
}
