using Microsoft.EntityFrameworkCore;
using Relecloud.Web.Models.ConcertContext;

namespace Relecloud.Web.Api.Services.SqlDatabaseConcertRepository
{
    public class ConcertDataContext : DbContext
    {
        public DbSet<Concert> Concerts => Set<Concert>();
        public DbSet<Customer> Customers => Set<Customer>();
        public DbSet<User> Users => Set<User>();
        public DbSet<Ticket> Tickets => Set<Ticket>();

        public DbSet<TicketNumber> TicketNumbers => Set<TicketNumber>();

        public ConcertDataContext(DbContextOptions<ConcertDataContext> options) : base(options)
        {
        }

        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            base.OnModelCreating(modelBuilder);

            modelBuilder.Entity<Concert>()
                .Ignore(c => c.NumberOfTicketsForSale);
            modelBuilder.Entity<Customer>()
                .HasIndex(c => new { c.Email })
                .IsUnique();
            modelBuilder.Entity<TicketNumber>()
                .HasIndex(tn => new { tn.Number, tn.ConcertId })
                .IsUnique();
        }

        public void Initialize()
        {
            this.Database.EnsureCreated();

            if (this.Concerts.Any())
            {
                return;
            }

            if (this.Database.IsSqlServer())
            {
                EnableChangeTracking();
            }

            // Add random concerts to the database.
            var random = new Random();
            var artists = new[] {
                new { Name = "Marina Rodríguez", Genre = "Pop", Tour = "Cosmic Harmony Festival", Description = "Marina Rodríguez (born August 16, 1978) is a fictional musician and singer-songwriter. She grew up in a small coastal town in Spain and began playing the guitar at a young age. As a teenager, she started writing her own songs and performing at local venues. She quickly gained a reputation as a talented musician and a powerful performer." },
                new { Name = "Larissa Sevilla", Genre = "Pop", Tour = "Electric Stardust Extravaganza", Description = "Larissa Sevilla (born July 16, 1958) is a fictional musician and singer-songwriter. After completing her studies, she moved to Madrid to pursue a career in music. She quickly made a name for herself on the local music scene and eventually caught the attention of a record label." },
                new { Name = "Finn Andresen", Genre = "Pop", Tour = "Electric Stardust Spectacular featuring Finn and the Dreamwaves", Description = "The Dreamwaves are a fictional rock band formed in 1996 by lead vocalist and keyboardist Finn Andresen. In his early career, he released a few successful albums of folk-influenced pop music and toured extensively throughout Spain, gaining a large and dedicated fanbase in the process." },
                new { Name = "Fadime Dogan", Genre = "Pop", Tour = "Galactic Symphony: A Musical Odyssey through the Stars", Description = "Galactic Symphony are a British band formed in 2007. The band featuresFadime Dogan (lead vocals, electric guitar, acoustic guitar, drums) and includes guests featuring vocals, keyboard, piano, synthesizer. In her latest album, she wanted to experiment with new sounds and styles, so she decided to explore different rhythms, instruments and cultures which gave her a different touch to her music. She fuses pop, rock, and latin rhythms, to create her own unique sound." },
                new { Name = "Carla Costa", Genre = "Pop", Tour = "Cosmic Odyssey: A Musical Journey Through the Stars", Description = "Carla Costa (born 5 May 1986) is a British singer and songwriter. Her live performances are known for their high energy, with Marina giving it all on stage, whether it's a large concert venue or a small club. Carla Costa has become a prominent figure in the music scene, known for her powerful voice, her emotive lyrics and her charismatic stage presence." },
                new { Name = "Barbara Dias", Genre = "R&B/Hip-Hop", Tour = "Midnight Melodies", Description = "Barbara Dias (born September 4, 1981), is a fictional American singer, songwriter, dancer and actress. She was born in a small village in Brazil, surrounded by lush jungles and beautiful beaches. From a young age, she was exposed to the rich rhythms and melodies of traditional Brazilian music, which had a deep impact on her. She began playing guitar and writing her own songs at a young age." },
                new { Name = "Nanette Langen", Genre = "R&B/Hip-Hop", Tour = "The Underground Takeover", Description = "Nanette Langen (born February 18, 1969) is a fictional American rapper, record producer, and entrepreneur. She decided to move to Rio de Janeiro to pursue a career in music. She quickly made a name for herself on the local music scene, performing at various clubs and festivals. Her unique blend of traditional Brazilian rhythms with modern pop and rock elements caught the attention of music producers and soon she was signed to a record label." },
                new { Name = "Angel Brown", Genre = "R&B/Hip-Hop", Tour = "Rap Reign: The Tour", Description = "Angel Brown (born October 14, 1986) is a fictional Canadian rapper, singer, songwriter, record producer, actor, and entrepreneur. Her first album, and it was a success, which gained her a strong following in Brazil and worldwide. With her powerful voice, infectious melodies, and emotive lyrics, Barbara quickly established herself as one of the most promising young artists in the Brazilian music scene." },
                new { Name = "Stine & Romund", Genre = "Dance", Tour = "Euphoria Symphony: A Night of Sound and Light", Description = "Stine & Romund is are a fictional French electronic music duo from Paris formed in 1994. Their first album was a success, which gained a strong following in France and worldwide. The duo explores new sounds and styles, adding electronic elements and collaborating with international producers, which gave their music a new and fresh perspective." },
                new { Name = "Josefine Karlsen", Genre = "Dance", Tour = "Electric Tempest Tour", Description = "Josefine & Karlsen is a fictional American DJ/production artist consisting of Alex Pall and Andrew Taggart. The EDM-pop duo achieved a breakthrough with their 2014 song \"Drifting Souls\", which was a top twenty single in several countries. Their debut EP, Bouquet was released in October 2015 and featured the single \"Rockig Roses\", which reached the top 10 on the US Billboard Hot 100. Later it became their first top 5 single and won the Grammy Award for Best Dance Recording at the 59th awards ceremony. They have also won two American Music Awards and five Music Awards. The duo's second EP Collage was released in November 2017, succeeded by the release of their debut studio album, April Showers Bring Mayflowers, in April 2017." },
                new { Name = "Margarida Gouveia", Genre = "Rock", Tour = "The Rainy City Renegades Tour", Description = "The Rainy City Renegades are an Seattle rock duo formed in Bellevue in 2013. The band's sound is reminiscent of and rooted in modern blues rock, alternative metal, hard rock, garage rock, stoner rock and psychedelic rock. Their first album Royal Blueberries was released in August 2014." },
                new { Name = "Simanti Sengupta", Genre = "Rock", Tour = "The Dhaka Inferno", Description = "The Dhaka Inferno is a fictional Indian rock band, formed in Bangalore, in 1994. Prior to the release of their 1995 debut album the Dhaka Inferno, which featured Simanti Sengupta as the only official member, Simanti recruited bassist Dileep Chaturvedi and drummer Bhupesh Menon, both formerly of Sunny  Real Day Real Rain, as well as touring guitarist Lucky Shastry to complete the lineup." },
                new { Name = "Jennifer Wilkins", Genre = "Rock", Tour = "The Lone Star Outlaws Tour", Description = "The Lone Star Outlaws is a fictional American heavy metal band from Los Angeles, California. The band was formed in 1982 by drummer Jennifer Wilkins and vocalist/guitarist Ana Bowman." },
                new { Name = "Aidan Hunt", Genre = "Rock", Tour = "The Windy City Warriors Tour", Description = "The Windy City Warriors Tour are an American rock band from Chicago, Illinois, formed in 1994. The band consists of Aidan Hunt (lead vocals, guitar, piano, keyboards), Dakota Sanchez (bass guitar, backing vocals, keyboards) and Ashley Schroeder (drums, percussion). They released their debut album in 1999, showcasing Hunt's falsetto and a melancholic alternative rock style. Their second album, Origin of Angles (2001), expanded their sound, incorporating wider instrumentation and romantic classical influences, and earned them a reputation for energetic live performances. Absolution (2003) saw further classical influence, with orchestra on tracks such as \"Butterflies and Birds\", and became the first of five consecutive UK number-one albums. Black Holes and Cosmic Constellations (2006) incorporated electronic and pop elements, influenced by 1980s groups, displayed in singles such as \"Supermassive Planetoid\". The album brought the Windy City Warriors wider international success. Their latest albums cemented the Windy City Warriors as one of the world's major stadium acts. Their seventh album, returns to a harder rock sound." },
                new { Name = "Klemmet Reiersen", Genre = "Rock", Tour = "The Cosmic Serenaders Tour", Description = "Klemmet Reiersen is a Swedish songwriter, lyricist, guitarist, and vocalist. Thus far, every album released by Klemmet has been a concept album. Lyrically, Klemmet tends to address contemporary issues, such as, the environment, and the nature of God, humanity, and existence." },
                new { Name = "Kim Cao", Genre = "Rock", Tour = "As Almas Perdidas Tour", Description = "As Almas Perdidas is a fictional Portuguese rock band from Brazil, consisting of lead vocalist Kim Cao, lead guitarist Mila Moraes, bassist and keyboardist Alice Pena, and drummer Alejandra Arellano. The band first gained exposure with the release of their first single \"Ready set Go, It's Time\", followed by their award-winning debut studio album in 2012, which resulted in the chart topping singles \"Best Song Ever\" and \"Also the Best Song Ever\". The band's second studio album reached number one in the US, Canada and the UK. After a brief hiatus, the band released their third studio album in 2017 which resulted in the chart-topping singles, \"Another Best Song Ever\" and \"Probably the Best Song Ever\"." },
            };
            var locations = new[] { "Bellevue Field, Seattle, USA", "Quebeck Stadium, Montreal, Canada", "Queensland Stage, Brisbane, Australia", "Underground Arena, London, England", "The Chocolate Dome, Brussels, Belgium", "Abbot Centre Theatre, Cape Town, South Africa", "Olympic Arena Fields, Rome, Italy", "Bullet Trainyard Ampitheatre, Tokyo, Japan" };
            var startDate = new DateTimeOffset(DateTimeOffset.UtcNow.Year, DateTimeOffset.UtcNow.Month, DateTimeOffset.UtcNow.Day, 20, 0, 0, TimeSpan.Zero);
            for (var i = 0; i < 1000; i++)
            {
                var artist = artists[random.Next(artists.Length)]; // Random artist
                var location = locations[random.Next(locations.Length)]; // Random location
                var price = 5 * random.Next(4, 40); // Random price between 20 and 200
                var startTime = startDate.AddDays(random.Next(2, 365)); // Random date in the next year
                var randomExternalConcertId = "176tghji876tg1"; // the MockTicketManagementService says any ID that starts with 1 and ends with 1 is valid and ready to sell tickets
                this.Concerts.Add(new Concert { Artist = artist.Name, Genre = artist.Genre, Location = location, Price = price, Title = artist.Tour, Description = artist.Description, StartTime = startTime, IsVisible = true, CreatedBy = "System", CreatedOn = DateTime.UtcNow, UpdatedBy = "System", UpdatedOn = DateTime.UtcNow, TicketManagementServiceConcertId = randomExternalConcertId });
            }
            this.SaveChanges();
        }

        /// <summary>
        /// Enable change tracking on the database and table which can be used by the search service.
        /// </summary>
        private void EnableChangeTracking()
        {
            try
            {
                var databaseName = this.Database.GetDbConnection().Database;
                // Note: the cast to string is to work around an issue in Entity Framework Core 2.0 with string interpolation.
                // See https://github.com/aspnet/EntityFrameworkCore/issues/9734.
                this.Database.ExecuteSqlRaw((string)$"ALTER DATABASE [{databaseName}] SET CHANGE_TRACKING = ON (CHANGE_RETENTION = 2 DAYS, AUTO_CLEANUP = ON)");
            }
            catch (Microsoft.Data.SqlClient.SqlException exc)
            {
                if (exc.Number != 5088 /* Change tracking is already enabled for the database */)
                {
                    throw;
                }
            }

            try
            {
                var concertsTableName = nameof(Concerts);
                // Note: the cast to string is to work around an issue in Entity Framework Core 2.0 with string interpolation.
                // See https://github.com/aspnet/EntityFrameworkCore/issues/9734.
                this.Database.ExecuteSqlRaw((string)$"ALTER TABLE [{concertsTableName}] ENABLE CHANGE_TRACKING WITH (TRACK_COLUMNS_UPDATED = ON)");
            }
            catch (Microsoft.Data.SqlClient.SqlException exc)
            {
                if (exc.Number != 4996 /* Change tracking is already enabled for the table */)
                {
                    throw;
                }
            }
        }
    }
}
