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
                new { Name = "Marina Rodríguez", Genre = "Pop", Tour = "Cosmic Festival", Description = "Marina Rodríguez (born August 16, 1978) is a fictional musician and singer-songwriter. She grew up in a rural town and began playing the piano at 5 years old. As a teenager, she started writing her own songs and performing at local venues. She gained a reputation as a talented musician and singer." },
                new { Name = "Larissa Sevilla", Genre = "Pop", Tour = "Eclectic Stargazer Extravaganza", Description = "Larissa Sevilla (born June 16, 1958) is a fictional musician and singer-songwriter. After a brief teenage career she moved to Europe to complete her studies in jazz and to pursue a career in music. Her jazz-pop eclectic sound gained popularity in France and Germany, where she eventually caught the attention of a record label." },
                new { Name = "Finn Andresen", Genre = "Pop", Tour = "Finn's Dream Waves", Description = "The Dreamwaves are a fictional rock band formed in 1996 by lead vocalist and bass guitarist Finn Andresen. In his early career, he released a few successful albums of folk-influenced indie rock music. He toured extensively throughout the United Kingdom, gaining a dedicated fanbase in the process before becoming world-renowned for his dream-like sounds and lyrics." },
                new { Name = "Fadime Dogan", Genre = "Pop", Tour = "Symphonic Odyssey", Description = "Galactic Symphony is a fictional band formed in 2007. The band features Fadime Dogan (lead vocals, electric guitar, acoustic guitar, drums) and includes guests featuring trumpet, banjo, keyboard, piano, and synthesizer. In her latest record, she experimented with culturally diverse melodies. So she decided to explore different rhythms and instruments which gave her a different touch to her music. She fuses pop, rock, and world-inspired rhythms, to create her own up-pace sound." },
                new { Name = "Carla Costa", Genre = "Pop", Tour = "A Musical Journey", Description = "Carla Costa (born 5 September 1986) is a fictional singer and songwriter. Her fans travel from various countries to see her perform in person. Critics gave her the Awesome Award for best live performer in 1992, 2000, 2019, the first to win in three separate decades. Carla Costa has become a prominent figure in the music scene based on her charismatic stage presence the is known for bringing fans to tears." },
                new { Name = "Barbara Dias", Genre = "R&B/Hip-Hop", Tour = "Midnight Madness", Description = "Barbara Dias (born September 4, 1981), is a fictional American singer, songwriter, dancer and actress. She was born in a small town surrounded by trees and farmland. Her uncle is from Brazil and exposed her to traditional Brazilian music which had a deep impact on her style. She began playing guitar and writing her own songs in her 30s. Her favorite instrument is the guitar though she is sometimes known to surprise fans with guest stars while she plays the harmonica or flute." },
                new { Name = "Nanette Langen", Genre = "R&B/Hip-Hop", Tour = "The Underground Eruption", Description = "Nanette Langen (born February 18, 1969) is a fictional American hip-hop artist, record producer, and entrepreneur. She decided to move to California to study music and pursue a career in music. She quickly rose to fame on the local music scene, performing at underground venues and subway stops. Her unique blend of traditional 90s beats with modern pop and rock elements caught the attention of producers which led to two successful albums in 2015, 2016." },
                new { Name = "Angel Brown", Genre = "R&B/Hip-Hop", Tour = "Rap Rain", Description = "Angel Brown (born October 14, 1986) is a fictional Canadian rapper, singer, songwriter, record producer, actor, and entrepreneur. She released her first album in 2020, and it was a flop. She released another album in 2021 that gained her a strong following worldwide reaching the top of the charts on several streaming services. With her powerful voice, catchy melodies, and syncopated rhythm, Barbara established herself as one of the most promising young artists of 2022 and fans eagerly awaiting her next album set to drop in 2024." },
                new { Name = "Stine & Romund", Genre = "Dance", Tour = "Euphoria and Sound", Description = "Stine & Romund are a fictional French electronic music duo. They formed in 1998. Their first album was a success and gained a strong following in Europe. The group explores new sounds and styles, adding jazz elements and collaborating with American producers, which gave their music a new and fresh perspective." },
                new { Name = "Josefine & Karlsen", Genre = "Dance", Tour = "Tempest Tour", Description = "Josefine & Karlsen is a fictional American DJ/production group consisting of Alex Pall and Andrew Taggart. The EDM-pop duo achieved a breakthrough with their 2014 song \"Drifting Souls\", which was a top twenty single in several countries. Their debut EP, Flowers, was released in August 2015 and featured the single \"Rocking Roses, not Timing Tulips\", which reached the top 10 on the US Billboard Hot 100. It became their first top-5 single and won the Slammy Award for Best Dance Recording at the 1000th awards ceremony. They have also won two American Music Awards and five Music Awards. The duo's second EP Collage, not College was released in November 2017, succeeded by the release of their debut studio album, April Showers Bring Music Powers, in April 2017." },
                new { Name = "Margarida Gouveia", Genre = "Rock", Tour = "Rainy Renegades", Description = "The Rainy City Renegades are a fictional Seattle rock duo formed in Bellevue in 2013. The band's sound is rooted in modern blues, alternative metal, hip-hop, and 70's influences. Their first album Royal Blueberries was released in August 2014." },
                new { Name = "Simanti Sengupta", Genre = "Rock", Tour = "The New Delhi Inferno", Description = "The New Delhi Inferno is a fictional Indian rock band, formed in Bangalore, in 1994. Prior to the release of their 1995 debut album. The New Delhi Inferno, which featured Simanti Sengupta as the only official member, Simanti recruited bassist Dileep Chaturvedi and drummer Bhupesh Menon, both formerly of Sunny Real Day Real Rain, as well as touring guitarist Lucky Shastry to complete the lineup." },
                new { Name = "Jennifer Wilkins", Genre = "Rock", Tour = "The Lone Star Outlaws Tour", Description = "The Lone Star Outlaws is a fictional American heavy metal band from Los Angeles, California. The band was formed in 1982 by drummer Jennifer Wilkins and vocalist/guitarist Ana Bowman. These two grew up together and formed a life-long bond initiated by a love for Elvis. They use lyrics to reinforce unity and positivity and most live performances fans leave feeling like family." },
                new { Name = "Aidan Hunt", Genre = "Rock", Tour = "The City Warriors Tour", Description = "The City Warriors are a fictional American rock band from Chicago, Illinois, formed in 1994. The band consists of Aidan Hunt (lead vocals, guitar, piano, keyboards), Dakota Sanchez (bass guitar, backing vocals, keyboards) and Ashley Schroeder (drums, percussion, and synth). They released their debut album in 2000, showcasing Hunt's falsetto and indie style. Their second album, Origin of Angles and Geometry (2001), expanded their sound, incorporating wider instrumentation and romantic classical influences. It earned them a reputation for weird sounds that sooth and inspire. Absolution (2003) saw further classical influence, with orchestra on tracks such as \"Butterflies and Birds\", and became the first of five consecutive number-one albums. Black Holes and Cosmic Constellations (2006) incorporated electronic and pop elements, influenced by 1980s groups, displayed in singles such as \"Supermassive Planetoid\". The album brought the City Warriors wider domestic success. Their latest albums cemented the City Warriors as one of the world's major stadium acts. Their seventh album, returns to a harder rock sound." },
                new { Name = "Klemmet Reiersen", Genre = "Rock", Tour = "Serenade", Description = "Klemmet Reiersen is a fictional Swedish songwriter, lyricist, guitarist, and vocalist. Thus far, every album released by Klemmet has been a concept album. Lyrically, Klemmet tends to address philosophical issues, such as purpose and existence. His riffs are known to wow audience members. He's known to play his guitar with his hands and piano with his toes, leaving people amazed at his ability." },
                new { Name = "Kim Cao", Genre = "Rock", Tour = "The Lisbon Saints Tour", Description = "The Lisbon Saints is a fictional Portuguese rock band from Brazil, consisting of lead vocalist Kim Cao, lead guitarist Mila Moraes, bassist and keyboardist Alice Pena, and drummer Alejandra Arellano. The band first gained exposure with the release of their first single \"Ready set Go, It's Time to Stop\", followed by their award-winning debut studio album in 2012, which resulted in the chart-topping singles \"Really Really Good Song\" and \"Even Better Song\". The band's second studio album reached number one in the US, Canada and the UK. After a brief hiatus, the band released their third studio album in 2017 which resulted in the chart-topping singles, \"Another Best Song Ever\" and \"Probably the Best Song Ever\"." },
            };
            var locations = new[] { "Bellevue Field, Seattle, USA", "Quebec Stadium, Montreal, Canada", "Queensland Stage, Brisbane, Australia", "Overground Stadium, London, England", "The Chocolate Dome, Brussels, Belgium", "Central Town Theatre, Cape Town, South Africa", "Metal Fields, Rome, Italy", "Train Amphitheater, Tokyo, Japan" };
            var startDate = new DateTimeOffset(DateTimeOffset.UtcNow.Year, DateTimeOffset.UtcNow.Month, DateTimeOffset.UtcNow.Day, 20, 0, 0, TimeSpan.Zero);
            // Counters to ensure more even distribution
            var artistIndex = 0;
            var locationIndex = 0;

            for (var i = 0; i < 1000; i++)
            {
                var artist = artists[artistIndex];
                var location = locations[locationIndex];
                var price = 5 * random.Next(4, 40); // Random price between 20 and 200
                var startTime = startDate.AddDays(random.Next(2, 365)); // Random date in the next year
                var randomExternalConcertId = "176tghji876tg1"; // the MockTicketManagementService says any ID that starts with 1 and ends with 1 represents valid and ready to sell tickets
                this.Concerts.Add(new Concert
                {
                    Artist = artist.Name,
                    Genre = artist.Genre,
                    Location = location,
                    Price = price,
                    Title = artist.Tour,
                    Description = artist.Description,
                    StartTime = startTime,
                    IsVisible = true,
                    CreatedBy = "System",
                    CreatedOn = DateTime.UtcNow,
                    UpdatedBy = "System",
                    UpdatedOn = DateTime.UtcNow,
                    TicketManagementServiceConcertId = randomExternalConcertId
                });

                // Update indices for more even distribution
                artistIndex = (artistIndex + 1) % artists.Length;
                locationIndex = (locationIndex + 1) % locations.Length;
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
