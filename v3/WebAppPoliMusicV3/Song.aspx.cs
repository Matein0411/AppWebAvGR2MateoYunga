using System;
using System.Configuration;
using System.Data.SqlClient;
using System.IO;
using System.Linq;
using System.Web;
using System.Web.UI;
using System.Web.UI.WebControls;
using EntityLayer.PoliMusicV3;
using EntityLayer.PoliMusicV3.Util;
using SongService = BLL.PoliMusicV3.Song;

namespace WebAppPoliMusicV3
{
    public partial class Song : Page
    {
        internal const string HomeViewKey = "PoliMusic.HomeView";

        internal bool ShowHome => Context.Items[HomeViewKey] != null;

        protected string IconPath => ResolveUrl("~/Content/icons.svg");
        protected string UserName => Context.User.Identity.Name;

        protected string ProfilePhoto
        {
            get
            {
                var user = Session[Constants.USER] as User;
                string storedPath = (user?.Photo ?? string.Empty).Replace('\\', '/');
                string fileName = storedPath.Substring(storedPath.LastIndexOf('/') + 1);
                string folder = ConfigurationManager.AppSettings["userPhotoPath"];
                if (fileName.IndexOfAny(Path.GetInvalidFileNameChars()) >= 0 ||
                    !File.Exists(Path.Combine(Server.MapPath(folder), fileName)))
                {
                    fileName = "default.jpg";
                }
                return ResolveUrl(folder) + Uri.EscapeDataString(fileName);
            }
        }

        protected void Page_Load(object sender, EventArgs e)
        {
            if (ShowHome)
            {
                Title = "Inicio";
            }

            phHome.Visible = ShowHome;
            phHomeHeading.Visible = ShowHome;
            phCatalogHeading.Visible = !ShowHome;

            try
            {
                string connectionString = ConfigurationManager.ConnectionStrings["BDD_PoliMusicConnectionString"].ConnectionString;
                var songs = new SongService(connectionString).Read().Select((song, index) =>
                {
                    string audioUrl = AudioUrl(song.Path);
                    return new
                    {
                        Index = index,
                        song.Name,
                        song.Artist,
                        song.Album,
                        AudioUrl = audioUrl,
                        HasAudio = audioUrl.Length > 0,
                        CoverUrl = ResolveUrl("~/SongCovers/cover-" + (index % 5 + 1) + ".svg")
                    };
                }).ToList();

                grdSongs.DataSource = songs;
                grdSongs.DataBind();
                if (grdSongs.HeaderRow != null)
                {
                    grdSongs.HeaderRow.TableSection = TableRowSection.TableHeader;
                }

                phFeatured.Visible = songs.Count > 0;
                if (ShowHome)
                {
                    rptFeatured.DataSource = songs.Take(5);
                    rptFeatured.DataBind();
                }

                int playableCount = songs.Count(song => song.HasAudio);
                string countLabel = songs.Count == 1 ? "1 canción" : songs.Count + " canciones";
                lblSongCount.Text = countLabel + " · " + playableCount + " con audio disponible";
            }
            catch (SqlException exception)
            {
                Trace.Warn("PoliMusic", "No se pudo consultar el catálogo.", exception);
                phFeatured.Visible = false;
                lblCatalogError.Text = "No se pudo cargar el catálogo. Vuelve a intentarlo en unos minutos.";
            }
        }

        private string AudioUrl(string path)
        {
            string fileName = SongService.AudioFileName(path);
            if (fileName == null)
            {
                return string.Empty;
            }

            string virtualPath = ConfigurationManager.AppSettings["songFolderPath"] + fileName;
            return File.Exists(Server.MapPath(virtualPath))
                ? HttpUtility.UrlPathEncode(ResolveUrl(virtualPath))
                : string.Empty;
        }
    }
}
