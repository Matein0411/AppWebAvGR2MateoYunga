using System;
using System.Configuration;
using System.Data;
using System.Data.SqlClient;
using System.IO;
using System.Web;
using System.Web.UI;
using System.Web.UI.WebControls;

namespace WebAppPoliMusicV2
{
    public partial class Song : Page
    {
        protected Entities.User CurrentUser;
        protected bool IsAdmin { get { return CurrentUser != null && CurrentUser.UserType == Util.Constants.ID_USER_ADMIN; } }
        protected string CsrfToken { get { return (string)Session["SongCsrf"]; } }
        protected int SongCount;
        protected int AvailableCount;
        private BLL.Song Service
        {
            get { return new BLL.Song(ConfigurationManager.ConnectionStrings["BDD_PoliMusicConnectionString"].ConnectionString); }
        }

        protected override void OnInit(EventArgs e)
        {
            CurrentUser = Session[Util.Constants.USER] as Entities.User;
            if (!Request.IsAuthenticated || CurrentUser == null)
            {
                Response.Redirect("Login.aspx", true);
                return;
            }
            if (Session["SongCsrf"] == null) Session["SongCsrf"] = Guid.NewGuid().ToString("N");
            ViewStateUserKey = CsrfToken;
            Response.Cache.SetCacheability(HttpCacheability.NoCache);
            Response.Cache.SetNoStore();
            base.OnInit(e);
        }

        protected void Page_Load(object sender, EventArgs e)
        {
            if (Request.HttpMethod == "POST" && Request.Form["csrf"] != CsrfToken)
            {
                Response.StatusCode = 403;
                Response.Write("La sesión del formulario ha caducado. Recarga la página.");
                Response.End();
                return;
            }
            if (Request.HttpMethod == "POST" && Request.Form["action"] == "play")
            {
                RegisterPlay();
                return;
            }
            if (Request.HttpMethod == "POST") RequireAdmin();
            pnlAdmin.Visible = IsAdmin;
            if (!IsPostBack) BindCatalog();
        }

        private void BindCatalog()
        {
            try
            {
                DataTable songs = Service.Read();
                songs.Columns.Add("COVER_URL", typeof(string));
                songs.Columns.Add("AUDIO_URL", typeof(string));
                songs.Columns.Add("POSITION", typeof(int));
                AvailableCount = 0;
                for (int i = 0; i < songs.Rows.Count; i++)
                {
                    DataRow row = songs.Rows[i];
                    int id = (int)row["ID_SONG"];
                    row["COVER_URL"] = ResolveUrl("~/SongCovers/cover-" + ((id - 1) % 5 + 1) + ".svg");
                    row["AUDIO_URL"] = AudioUrl(row["SONG_PATH"].ToString());
                    row["POSITION"] = i + 1;
                    if (row["AUDIO_URL"].ToString().Length > 0) AvailableCount++;
                }
                SongCount = songs.Rows.Count;
                rptSongs.DataSource = songs;
                rptSongs.DataBind();
                DataTable featured = songs.Clone();
                for (int i = 0; i < Math.Min(5, songs.Rows.Count); i++) featured.ImportRow(songs.Rows[i]);
                rptFeatured.DataSource = featured;
                rptFeatured.DataBind();
                lblSongCount.Text = SongCount + (SongCount == 1 ? " canción" : " canciones");
                lblAvailable.Text = AvailableCount + " con audio disponible";
                pnlEmpty.Visible = SongCount == 0;
                catalogHeader.Visible = SongCount > 0;
            }
            catch (SqlException exception)
            {
                Trace.Warn("PoliMusic", "No se pudo consultar el catálogo.", exception);
                ShowMessage("No se pudo conectar con el catálogo. Comprueba que SQL Server esté disponible e inténtalo de nuevo.", false);
                pnlEmpty.Visible = true;
                catalogHeader.Visible = false;
                lblSongCount.Text = "Catálogo no disponible";
                lblAvailable.Text = "Conexión pendiente";
            }
        }

        protected string H(object value) { return HttpUtility.HtmlEncode(Convert.ToString(value)).Replace("'", "&#39;"); }
        protected string Disabled(object audio) { return string.IsNullOrEmpty(Convert.ToString(audio)) ? "disabled" : string.Empty; }
        protected string UserPhoto()
        {
            string name = Path.GetFileName((CurrentUser.Photo ?? string.Empty).Replace('\\', '/'));
            string path = "~/UserImages/" + name;
            return ResolveUrl(name.Length > 0 && File.Exists(Server.MapPath(path)) ? path : "~/UserImages/default.jpg");
        }

        private string AudioUrl(string path)
        {
            try
            {
                path = BLL.Song.NormalizePath(path);
                return File.Exists(Server.MapPath(path)) ? ResolveUrl(path) : string.Empty;
            }
            catch (ArgumentException) { return string.Empty; }
        }

        private void RequireAdmin()
        {
            if (!IsAdmin) throw new HttpException(403, "Solo los administradores pueden gestionar canciones.");
        }

        protected void NewSong_Click(object sender, EventArgs e)
        {
            RequireAdmin();
            hidSongID.Value = string.Empty;
            txtSongName.Text = string.Empty;
            lblEditorTitle.Text = "Añadir canción";
            lblEditorMessage.Text = string.Empty;
            LoadAudioFiles(null);
            pnlEditor.Visible = true;
        }

        protected void Song_Command(object sender, CommandEventArgs e)
        {
            RequireAdmin();
            int id;
            if (!int.TryParse(Convert.ToString(e.CommandArgument), out id) || id <= 0)
                throw new HttpException(400, "Canción no válida.");
            try
            {
                Entities.Song song = Service.Read(id);
                if (song == null) { ShowMessage("Esta canción ya no existe. Actualiza el catálogo.", false); BindCatalog(); return; }
                if (e.CommandName == "EditSong")
                {
                    hidSongID.Value = id.ToString();
                    txtSongName.Text = song.Name;
                    lblEditorTitle.Text = "Editar canción";
                    lblEditorMessage.Text = string.Empty;
                    LoadAudioFiles(song.Path);
                    pnlEditor.Visible = true;
                }
                else if (e.CommandName == "DeleteSong")
                {
                    Service.Delete(id);
                    ShowMessage("Canción eliminada del catálogo.", true);
                    BindCatalog();
                }
            }
            catch (SqlException exception)
            {
                Trace.Warn("PoliMusic", "No se pudo gestionar la canción.", exception);
                ShowMessage("No se pudo completar la operación. Inténtalo de nuevo.", false);
            }
        }

        private void LoadAudioFiles(string selectedPath)
        {
            ddlAudioFiles.Items.Clear();
            ddlAudioFiles.Items.Add(new ListItem("Selecciona un MP3 existente", string.Empty));
            foreach (string file in Directory.GetFiles(Server.MapPath("~/SongFiles/"), "*.mp3"))
            {
                string name = Path.GetFileName(file);
                ddlAudioFiles.Items.Add(new ListItem(name, "~/SongFiles/" + name));
            }
            if (!string.IsNullOrEmpty(selectedPath))
            {
                selectedPath = BLL.Song.NormalizePath(selectedPath);
                ListItem item = ddlAudioFiles.Items.FindByValue(selectedPath);
                if (item == null)
                {
                    item = new ListItem(Path.GetFileName(selectedPath) + " (archivo no disponible)", selectedPath);
                    ddlAudioFiles.Items.Add(item);
                }
                item.Selected = true;
            }
        }

        protected void SaveSong_Click(object sender, EventArgs e)
        {
            RequireAdmin();
            string uploadedPath = null;
            try
            {
                int id = 0;
                if (hidSongID.Value.Length > 0 && (!int.TryParse(hidSongID.Value, out id) || id <= 0))
                    throw new ArgumentException("La canción seleccionada no es válida.");
                Entities.Song previous = id > 0 ? Service.Read(id) : null;
                if (id > 0 && previous == null) throw new ArgumentException("La canción ya no existe.");
                Entities.Song song = new Entities.Song { ID = id, Name = txtSongName.Text, Path = ddlAudioFiles.SelectedValue };
                // Validate the name before writing any uploaded file.
                BLL.Song.Validate(new Entities.Song { Name = song.Name, Path = "~/SongFiles/validation.mp3" });
                if (fupSong.HasFile)
                {
                    int maxSize = Convert.ToInt32(ConfigurationManager.AppSettings["maxSongLength"] ?? "52428800");
                    string mediaType = fupSong.PostedFile.ContentType.ToLowerInvariant();
                    if (!string.Equals(Path.GetExtension(fupSong.FileName), ".mp3", StringComparison.OrdinalIgnoreCase) ||
                        (mediaType != "audio/mpeg" && mediaType != "audio/mp3" && mediaType != "audio/mpeg3"))
                        throw new ArgumentException("Selecciona un archivo de audio MP3.");
                    if (fupSong.PostedFile.ContentLength == 0 || fupSong.PostedFile.ContentLength > maxSize)
                        throw new ArgumentException("El MP3 debe tener contenido y ocupar como máximo " + (maxSize / 1048576) + " MB.");
                    song.Path = "~/SongFiles/" + Guid.NewGuid().ToString("N") + ".mp3";
                    uploadedPath = Server.MapPath(song.Path);
                    fupSong.SaveAs(uploadedPath);
                }
                song.Path = BLL.Song.NormalizePath(song.Path);
                if (!File.Exists(Server.MapPath(song.Path)) && (previous == null ||
                    !string.Equals(previous.Path, song.Path, StringComparison.OrdinalIgnoreCase)))
                    throw new ArgumentException("El archivo seleccionado no está disponible. Selecciona o sube otro MP3.");
                int affected = id == 0 ? Service.Save(song) : Service.Update(song);
                if (affected == 0) throw new ArgumentException("La canción ya no existe. Actualiza el catálogo.");
                uploadedPath = null;
                pnlEditor.Visible = false;
                ShowMessage(id == 0 ? "Canción añadida. ¡Dale al play!" : "Canción actualizada.", true);
                BindCatalog();
            }
            catch (ArgumentException exception) { lblEditorMessage.Text = H(exception.Message); }
            catch (Exception exception)
            {
                Trace.Warn("PoliMusic", "No se pudo guardar la canción.", exception);
                lblEditorMessage.Text = "No se pudo guardar la canción. Comprueba la conexión y los permisos de SongFiles.";
            }
            finally
            {
                if (uploadedPath != null && File.Exists(uploadedPath)) File.Delete(uploadedPath);
            }
        }

        protected void CancelSong_Click(object sender, EventArgs e) { pnlEditor.Visible = false; BindCatalog(); }

        private void ShowMessage(string message, bool success)
        {
            pnlMessage.Visible = true;
            pnlMessage.CssClass = success ? "notice success" : "notice error";
            lblMessage.Text = H(message);
        }

        private void RegisterPlay()
        {
            bool saved = false;
            int id;
            if (int.TryParse(Request.Form["id"], out id) && id > 0)
            {
                DateTime last = Session["SongLastPlay"] is DateTime ? (DateTime)Session["SongLastPlay"] : DateTime.MinValue;
                if ((DateTime.UtcNow - last).TotalSeconds >= 30)
                {
                    try
                    {
                        Entities.Song song = Service.Read(id);
                        if (song != null && AudioUrl(song.Path).Length > 0)
                        {
                            saved = Service.IncrementPlays(id) > 0;
                            if (saved) Session["SongLastPlay"] = DateTime.UtcNow;
                        }
                    }
                    catch (SqlException exception) { Trace.Warn("PoliMusic", "No se pudo registrar la escucha.", exception); }
                }
            }
            Response.Clear();
            Response.ContentType = "application/json";
            Response.Write(saved ? "{\"saved\":true}" : "{\"saved\":false}");
            Response.End();
        }
    }
}
