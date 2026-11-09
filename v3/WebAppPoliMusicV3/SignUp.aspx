<%@ Page Language="C#" AutoEventWireup="true" CodeBehind="SignUp.aspx.cs" Inherits="WebAppPoliMusicV3.SignUp" %>
<!DOCTYPE html>
<html lang="es">
<head runat="server">
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>Registro · PoliMusic</title>
    <link href="~/Content/polimusic.css" rel="stylesheet" />
    <link href="~/SongCovers/cover-1.svg" rel="icon" type="image/svg+xml" />
</head>
<body class="auth-body">
    <main class="auth-card">
        <div class="brand">
            <span class="brand-mark"><svg aria-hidden="true"><use href="<%: ResolveUrl("~/Content/icons.svg") %>#wave"></use></svg></span>
            <span>PoliMusic <small>- Mateo.Yunga</small></span>
        </div>
        <h1>Crea tu cuenta</h1>
        <p>Empieza a explorar tu biblioteca.</p>
        <form id="formLogin" runat="server" enctype="multipart/form-data">
            <div class="field">
                <asp:Label runat="server" AssociatedControlID="txtUserName" Text="Nombre de usuario" />
                <asp:TextBox ID="txtUserName" runat="server" MaxLength="50" autocomplete="username" />
            </div>
            <div class="field">
                <asp:Label runat="server" AssociatedControlID="txtEmail" Text="Correo electrónico" />
                <asp:TextBox ID="txtEmail" runat="server" TextMode="Email" MaxLength="50" autocomplete="email" />
            </div>
            <div class="field">
                <asp:Label runat="server" AssociatedControlID="txtPassword" Text="Contraseña" />
                <asp:TextBox ID="txtPassword" runat="server" TextMode="Password" autocomplete="new-password" />
            </div>
            <div class="field">
                <asp:Label runat="server" AssociatedControlID="txtConfirmPassword" Text="Confirma tu contraseña" />
                <asp:TextBox ID="txtConfirmPassword" runat="server" TextMode="Password" autocomplete="new-password" />
            </div>
            <div class="field">
                <asp:Label runat="server" AssociatedControlID="txtBirthDate" Text="Fecha de nacimiento (opcional)" />
                <asp:TextBox ID="txtBirthDate" runat="server" placeholder="dd/MM/yyyy" autocomplete="bday" />
            </div>
            <div class="field">
                <asp:Label runat="server" AssociatedControlID="fupPhoto" Text="Foto de perfil (opcional)" />
                <asp:FileUpload ID="fupPhoto" runat="server" accept="image/png,image/jpeg" />
            </div>
            <asp:Button ID="btnSumbit" runat="server" Text="Crear cuenta" OnClick="btnSumbit_Click" CssClass="button primary" />
            <asp:Panel ID="frmConfirmation" runat="server">
                <asp:Label ID="lblMessage" runat="server" CssClass="message" role="status" />
            </asp:Panel>
            <p class="auth-bottom"><asp:HyperLink ID="HyperLink1" NavigateUrl="~/Login" runat="server">Volver a iniciar sesión</asp:HyperLink></p>
        </form>
    </main>
</body>
</html>
