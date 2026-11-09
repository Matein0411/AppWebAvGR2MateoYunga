<%@ Page Language="C#" AutoEventWireup="true" CodeBehind="Login.aspx.cs" Inherits="WebAppPoliMusicV3.Login" %>
<!DOCTYPE html>
<html lang="es">
<head runat="server">
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>Iniciar sesión · PoliMusic</title>
    <link href="~/Content/polimusic.css" rel="stylesheet" />
    <link href="~/SongCovers/cover-1.svg" rel="icon" type="image/svg+xml" />
</head>
<body class="auth-body">
    <main class="auth-card">
        <div class="brand">
            <span class="brand-mark"><svg aria-hidden="true"><use href="<%: ResolveUrl("~/Content/icons.svg") %>#wave"></use></svg></span>
            <span>PoliMusic <small>- Mateo.Yunga</small></span>
        </div>
        <h1>Inicia sesión</h1>
        <p>Tu catálogo de música te espera.</p>
        <form id="formLogin" runat="server" defaultbutton="btnLogin">
            <div class="field">
                <asp:Label runat="server" AssociatedControlID="txtLogin" Text="Nombre de usuario" />
                <asp:TextBox ID="txtLogin" runat="server" MaxLength="50" autocomplete="username" />
            </div>
            <div class="field">
                <asp:Label runat="server" AssociatedControlID="txtPassword" Text="Contraseña" />
                <asp:TextBox ID="txtPassword" runat="server" TextMode="Password" autocomplete="current-password" />
            </div>
            <asp:Button ID="btnLogin" runat="server" Text="Iniciar sesión" OnClick="BtnLogin_Click" CssClass="button primary" />
            <asp:Label ID="lblMessage" runat="server" CssClass="message" role="alert" />
            <p class="auth-bottom">¿Primera vez aquí? <asp:LinkButton ID="LinkButtonNewUser" runat="server" OnClick="LinkButtonNewUser_Click" CausesValidation="false">Crea tu cuenta</asp:LinkButton></p>
        </form>
    </main>
</body>
</html>
