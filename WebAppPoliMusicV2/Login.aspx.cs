using System;
using System.Collections.Generic;
using System.Configuration;
using System.Data;
using System.Data.SqlClient;
using System.Web;
using System.Web.Security;
using System.Web.UI;
using System.Web.UI.WebControls;

namespace WebAppPoliMusicV2
{
    public partial class Login : System.Web.UI.Page
    {
        string strConnString = ConfigurationManager.ConnectionStrings["BDD_PoliMusicConnectionString"].ConnectionString;
        protected void Page_Load(object sender, EventArgs e)
        {
            if (!Page.IsPostBack)
            {
                lblMessage.Text = string.Empty;
                if (Request.IsAuthenticated && Session[Util.Constants.USER] is Entities.User)
                    Response.Redirect("Song.aspx", true);
            }
        }

        protected void BtnLogin_Click(object sender, EventArgs e)
        {
            string login = txtLogin.Text.Trim();
            string password = txtPassword.Text;

            if (string.IsNullOrEmpty(login) || string.IsNullOrEmpty(password))
            {
                lblMessage.Text = "Introduce tu usuario y contraseña.";
                return;
            }
            password = Util.Hash.GeneratePasswordHash(password);
            DataTable dtUser;
            try { dtUser = new BLL.User(strConnString).AuthenticateUser(login, password); }
            catch (SqlException exception)
            {
                Trace.Warn("PoliMusic", "No se pudo iniciar sesión.", exception);
                lblMessage.Text = "No se pudo conectar con el servicio. Comprueba que SQL Server esté disponible.";
                return;
            }

            if (dtUser != null && dtUser.Rows.Count > 0)
            {
                Entities.User user = new Entities.User();
                user.ID = Convert.ToInt32(dtUser.Rows[0]["ID_USER"]);
                user.UserName = login;
                user.Photo = dtUser.Rows[0]["USER_PHOTO"].ToString();
                user.Email = dtUser.Rows[0]["EMAIL"].ToString();
                user.Birthday = dtUser.Rows[0]["BIRTHDAY"].ToString();
                user.UserType = Convert.ToInt32(dtUser.Rows[0]["USER_TYPE"]);
                if (user.UserType == Util.Constants.ID_USER_NORMAL || user.UserType == Util.Constants.ID_USER_ADMIN)
                {
                    Session[Util.Constants.USER] = user;
                    Session.Remove("SongCsrf");
                    FormsAuthentication.SetAuthCookie(login, false);
                    Response.Redirect("~/Song.aspx", false);
                    Context.ApplicationInstance.CompleteRequest();
                    return;
                }
                else
                {
                    lblMessage.Text = "Usuario o contraseña incorrectos.";
                    return;
                }
            }
            else
            {
                lblMessage.Text = "Usuario o contraseña incorrectos.";
                return;
            }
        }

        protected void LinkButtonNewUser_Click(object sender, EventArgs e)
        {
            Response.Redirect("SignUp.aspx", true);
        }
    }


}
