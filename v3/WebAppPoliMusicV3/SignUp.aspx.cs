using System;
using System.Configuration;
using System.Data.SqlClient;
using System.Globalization;
using System.IO;
using System.Net.Mail;
using System.Web.UI;
using EntityLayer.PoliMusicV3;
using EntityLayer.PoliMusicV3.Util;

namespace WebAppPoliMusicV3
{
    public partial class SignUp : Page
    {
        protected void btnSumbit_Click(object sender, EventArgs e)
        {
            string userName = txtUserName.Text.Trim();
            string email = txtEmail.Text.Trim();
            string password = txtPassword.Text;
            if (userName.Length == 0 || userName.Length > 50 || !IsValidEmail(email) || string.IsNullOrEmpty(password))
            {
                lblMessage.Text = "Introduce un usuario, un correo válido y una contraseña.";
                return;
            }
            if (password != txtConfirmPassword.Text)
            {
                lblMessage.Text = "Las contraseñas deben coincidir.";
                return;
            }

            string birthday = string.Empty;
            if (!string.IsNullOrWhiteSpace(txtBirthDate.Text))
            {
                DateTime date;
                if (!DateTime.TryParseExact(txtBirthDate.Text.Trim(), "dd/MM/yyyy", CultureInfo.InvariantCulture,
                    DateTimeStyles.None, out date) || date < new DateTime(1753, 1, 1) || date > DateTime.Today)
                {
                    lblMessage.Text = "Introduce una fecha de nacimiento válida en formato dd/MM/aaaa.";
                    return;
                }
                birthday = date.ToString("yyyyMMdd", CultureInfo.InvariantCulture);
            }

            string folder = ConfigurationManager.AppSettings["userPhotoPath"];
            var user = new User
            {
                UserName = userName,
                Email = email,
                Password = Hash.GeneratePasswordHash(password),
                Birthday = birthday,
                UserType = Constants.ID_USER_NORMAL,
                Photo = folder + "default.jpg"
            };

            try
            {
                string connectionString = ConfigurationManager.ConnectionStrings["BDD_PoliMusicConnectionString"].ConnectionString;
                var users = new BLL.PoliMusicV3.User(connectionString);
                if (users.CheckExistUser(userName) != 0)
                {
                    lblMessage.Text = "El nombre de usuario ya está registrado.";
                    return;
                }
                if (users.CheckExistEmail(email) != 0)
                {
                    lblMessage.Text = "El correo electrónico ya está registrado.";
                    return;
                }

                if (fupPhoto.HasFile)
                {
                    string photoName = Guid.NewGuid().ToString("N");
                    string error = new FileManagement().SaveImageOnServer(fupPhoto, folder, photoName);
                    if (!string.IsNullOrEmpty(error))
                    {
                        lblMessage.Text = "No se pudo guardar la foto. Usa una imagen JPEG o PNG de hasta 10 MB.";
                        return;
                    }
                    user.Photo = folder + photoName + Path.GetExtension(fupPhoto.FileName).ToLowerInvariant();
                }

                users.Save(user);
                lblMessage.CssClass = "message success";
                lblMessage.Text = "Tu cuenta está lista. Ya puedes iniciar sesión.";
            }
            catch (SqlException exception)
            {
                Trace.Warn("PoliMusic", "No se pudo registrar el usuario.", exception);
                lblMessage.Text = "No se pudo crear la cuenta. Vuelve a intentarlo en unos minutos.";
            }
        }

        private static bool IsValidEmail(string email)
        {
            if (email.Length == 0 || email.Length > 50)
            {
                return false;
            }

            try
            {
                return new MailAddress(email).Address == email;
            }
            catch (FormatException)
            {
                return false;
            }
        }
    }
}
