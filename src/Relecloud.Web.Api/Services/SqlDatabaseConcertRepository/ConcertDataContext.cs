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
                new { Name = "Ed Sheeran", Genre = "Pop", Tour = "Divide Tour", Description = "Edward Christopher Sheeran, (born 17 February 1991) is an English singer, songwriter, guitarist, and record producer. After signing with Asylum Records, his debut album, + (read as \"plus\"), was released in September 2011. His second studio album, x (read as \"multiply\"), was released in June 2014. Sheeran's third album, ÷ (read as \"divide\"), was released in March 2017." },
                new { Name = "Madonna", Genre = "Pop", Tour = "Rebel Heart Tour", Description = "Madonna Louise Ciccone (born August 16, 1958) is an American singer, songwriter, actress, and businesswoman. A leading presence during the emergence of MTV in the 1980s, Madonna is known for pushing the boundaries of lyrical content in mainstream popular music, as well as visual imagery in music videos and live performances. She has also frequently reinvented both her music and image while maintaining autonomy within the recording industry. Her diverse musical productions have been acclaimed by music critics and often generated controversy in media and public. Referred to as the \"Queen of Pop\", Madonna is widely cited as an influence by other artists." },
                new { Name = "Coldplay", Genre = "Pop", Tour = "A Head Full Of Dreams Tour", Description = "Coldplay are a British rock band formed in 1996 by lead vocalist and keyboardist Chris Martin and lead guitarist Jonny Buckland at University College London (UCL)." },
                new { Name = "Mumford & Sons", Genre = "Pop", Tour = "Wilder Mind Tour", Description = "Mumford & Sons are a British band formed in 2007. The band consists of Marcus Mumford (lead vocals, electric guitar, acoustic guitar, drums), Ben Lovett (vocals, keyboard, piano, synthesizer), Winston Marshall (vocals, electric guitar, banjo) and Ted Dwane (vocals, bass guitar, double bass). Mumford & Sons have released three studio albums: Sigh No More (2009), Babel (2012) and Wilder Mind (2015)." },
                new { Name = "Adele", Genre = "Pop", Tour = "25 Tour", Description = "Adele Laurie Blue Adkins (born 5 May 1988) is a British singer and songwriter. Her debut album, 19, was released in 2008 to commercial and critical success. She released her second studio album, 21, in 2011. In 2012, Adele released \"Skyfall\", which she co-wrote and recorded for the James Bond film of the same name. After taking a three-year break, Adele released her third studio album, 25, in 2015." },
                new { Name = "Beyoncé", Genre = "R&B/Hip-Hop", Tour = "Lemonade Tour", Description = "Beyoncé Giselle Knowles-Carter (born September 4, 1981), is an American singer, songwriter, dancer and actress. She rose to fame in the late 1990s as lead singer of the R&B girl-group Destiny's Child. Their hiatus saw Beyoncé's theatrical film debut in Austin Powers in Goldmember (2002) and the release of her debut album, Dangerously in Love (2003)." },
                new { Name = "Dr. Dre", Genre = "R&B/Hip-Hop", Tour = "Compton Tour", Description = "Andre Romelle Young (born February 18, 1965), better known by his stage name Dr. Dre, is an American rapper, record producer, and entrepreneur. He has produced albums for and overseen the careers of many rappers, including 2Pac, The D.O.C., Snoop Dogg, Eminem, Xzibit, Knoc-turn'al, 50 Cent, The Game and Kendrick Lamar. He is credited as a key figure in the popularization of West Coast G-funk, a style of rap music characterized as synthesizer-based with slow, heavy beats." },
                new { Name = "Drake", Genre = "R&B/Hip-Hop", Tour = "More Life Tour", Description = "Aubrey Drake Graham (born October 24, 1986) is a Canadian rapper, singer, songwriter, record producer, actor, and entrepreneur. Drake released his debut studio album Thank Me Later in 2010. His next two releases were 2011's Take Care and 2013's Nothing Was the Same. Drake released his fourth album, Views, in 2016, breaking several chart records in the process. Drake released the multi-genre More Life in 2017." },
                new { Name = "Daft Punk", Genre = "Dance", Tour = "Random Access Memories Tour", Description = "Daft Punk is a French electronic music duo from Paris formed in 1993 by Guy-Manuel de Homem-Christo and Thomas Bangalter. The duo released their debut studio album Homework through Virgin Records in 1997 to highly positive reviews, and spawning singles \"Around the World\" and \"Da Funk\". The duo's second album Discovery was even more successful, driven by the release of the hit singles \"One More Time\", \"Digital Love\" and \"Harder, Better, Faster, Stronger\". In March 2005, the duo released their third album Human After All to mixed reviews. However, the singles \"Robot Rock\" and \"Technologic\" achieved considerable success in the United Kingdom. In January 2013, Daft Punk left Virgin for Columbia Records, and released their fourth album Random Access Memories in 2013 to worldwide critical acclaim." },
                new { Name = "The Chainsmokers", Genre = "Dance", Tour = "Memories... Do Not Open Tour", Description = "The Chainsmokers is an American DJ/production duo consisting of Alex Pall and Andrew Taggart. The EDM-pop duo achieved a breakthrough with their 2014 song \"#Selfie\", which was a top twenty single in several countries. Their debut EP, Bouquet was released in October 2015 and featured the single \"Roses\", which reached the top 10 on the US Billboard Hot 100. \"Don't Let Me Down\" became their first top 5 single there and won the Grammy Award for Best Dance Recording at the 59th awards ceremony, while \"Closer\" became their first number-one single on the chart. They have also won two American Music Awards and five iHeartRadio Music Awards. The duo's second EP Collage was released in November 2016, succeeded by the release of their debut studio album, Memories...Do Not Open, in April 2017." },
                new { Name = "Royal Blood", Genre = "Rock", Tour = "How Did We Get So Dark? Tour", Description = "Royal Blood are an English rock duo formed in Brighton in 2013. The band's sound is reminiscent of and rooted in modern blues rock, alternative metal, hard rock, garage rock, stoner rock and psychedelic rock. Their first album Royal Blood was released in August 2014." },
                new { Name = "Foo Fighters", Genre = "Rock", Tour = "Concrete and Gold Tour", Description = "Foo Fighters is an American rock band, formed in Seattle, Washington in 1994. Prior to the release of Foo Fighters' 1995 debut album Foo Fighters, which featured Grohl as the only official member, Grohl recruited bassist Nate Mendel and drummer William Goldsmith, both formerly of Sunny Day Real Estate, as well as Nirvana touring guitarist Pat Smear to complete the lineup." },
                new { Name = "Metallica", Genre = "Rock", Tour = "Hardwired Tour", Description = "Metallica is an American heavy metal band from Los Angeles, California. The band was formed in 1981 by drummer Lars Ulrich and vocalist/guitarist James Hetfield." },
                new { Name = "Muse", Genre = "Rock", Tour = "Rock", Description = "Muse are an English rock band from Teignmouth, Devon, formed in 1994. The band consists of Matt Bellamy (lead vocals, guitar, piano, keyboards), Chris Wolstenholme (bass guitar, backing vocals, keyboards) and Dominic Howard (drums, percussion). Muse released their debut album, Showbiz, in 1999, showcasing Bellamy's falsetto and a melancholic alternative rock style. Their second album, Origin of Symmetry (2001), expanded their sound, incorporating wider instrumentation and romantic classical influences, and earned them a reputation for energetic live performances. Absolution (2003) saw further classical influence, with orchestra on tracks such as \"Butterflies and Hurricanes\", and became the first of five consecutive UK number-one albums. Black Holes and Revelations (2006) incorporated electronic and pop elements, influenced by 1980s groups such as Depeche Mode, displayed in singles such as \"Supermassive Black Hole\". The album brought Muse wider international success. The Resistance (2009) and The 2nd Law (2012) explored themes of government oppression and civil uprising and cemented Muse as one of the world's major stadium acts. Their seventh album, Drones (2015), was a concept album about drone warfare and returned to a harder rock sound." },
                new { Name = "Pain Of Salvation", Genre = "Rock", Tour = "In The Passing Light Of Day Tour", Description = "Pain of Salvation is a Swedish band led by Daniel Gildenlöw, who is the band's main songwriter, lyricist, guitarist, and vocalist. Thus far, every album released by the band has been a concept album. Lyrically, the band tends to address contemporary issues, such as sexuality, war, the environment, and the nature of God, humanity, and existence." },
                new { Name = "Imagine Dragons", Genre = "Rock", Tour = "Evolve Tour", Description = "Imagine Dragons is an American rock band from Las Vegas, Nevada, consisting of lead vocalist Dan Reynolds, lead guitarist Wayne Sermon, bassist and keyboardist Ben McKee, and drummer Daniel Platzman. The band first gained exposure with the release of single \"It's Time\", followed by their award-winning debut studio album Night Visions (2012), which resulted in the chart topping singles \"Radioactive\" and \"Demons\". The band's second studio album Smoke + Mirrors (2015) reached number one in the US, Canada and the UK. After a brief hiatus, the band released their third studio album, Evolve (2017) which resulted in the chart-topping singles, \"Believer\" and \"Thunder\"." },
            };
            var locations = new[] { "CenturyLink Field, Seattle, USA", "Parc Jean Drapeau, Montreal, Canada", "Riverstage, Brisbane, Australia", "O2 Arena, London, England", "Ancienne Belgique, Brussels, Belgium", "Baxter Theatre Centre, Cape Town, South Africa", "Olympic Stadium, Rome, Italy", "Zepp, Tokyo, Japan" };
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
