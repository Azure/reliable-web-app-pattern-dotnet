using System.ComponentModel.DataAnnotations;

namespace ReleCloudLite.Models;

public class Ticket
{

    public int Id { get; set; }

    [Required]
    public string? ShowName { get; set; }

    [Required]
    public string? Band { get; set; }

    [Required]
    public string? Location { get; set; }

    [Required]
    public int? TicketsRemaining { get; set; }

    [Required]
    public DateTimeOffset? Date { get; set; }

    [Required]
    public float? Price { get; set; }
}