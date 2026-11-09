using System;
using System.Configuration;
using System.Data;
using System.Data.SqlClient;
using System.Web.Security;
using System.Web.UI;
using EntityLayer.PoliMusicV3;
using EntityLayer.PoliMusicV3.Util;

namespace WebAppPoliMusicV3
{
    public partial class Login : Page
    {
        protected void Page_Load(object sender, EventArgs e)
        {
            if (!IsPostBack && Request.IsAuthenticated && Session[Constants.USER] is User)
            {
                Response.Redirect("~/");
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

            DataTable users;
            try
            {
                string connectionString = ConfigurationManager.ConnectionStrings["BDD_PoliMusicConnectionString"].ConnectionString;
                users = new BLL.PoliMusicV3.User(connectionString).AuthenticateUser(login, Hash.GeneratePasswordHash(password));
            }
            catch (SqlException exception)
            {
                Trace.Warn("PoliMusic", "No se pudo iniciar sesión.", exception);
                lblMessage.Text = "No se pudo conectar con el servicio. Vuelve a intentarlo en unos minutos.";
                return;
            }

            if (users.Rows.Count == 0)
            {
                lblMessage.Text = "Usuario o contraseña incorrectos.";
                return;
            }

            DataRow row = users.Rows[0];
            int userType = (int)row["USER_TYPE"];
            if (userType != Constants.ID_USER_NORMAL && userType != Constants.ID_USER_ADMIN)
            {
                lblMessage.Text = "Usuario o contraseña incorrectos.";
                return;
            }

            Session[Constants.USER] = new User
            {
                ID = (int)row["ID_USER"],
                UserName = login,
                Photo = row["USER_PHOTO"].ToString(),
                Email = row["EMAIL"].ToString(),
                Birthday = row["BIRTHDAY"].ToString(),
                UserType = userType
            };
            FormsAuthentication.RedirectFromLoginPage(login, false);
        }

        protected void LinkButtonNewUser_Click(object sender, EventArgs e)
        {
            Response.Redirect("~/SignUp");
        }
    }
}
