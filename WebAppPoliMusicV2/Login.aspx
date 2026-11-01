<%@ Page Language="C#" AutoEventWireup="true" CodeBehind="Login.aspx.cs" Inherits="WebAppPoliMusicV2.Login" %>
<!DOCTYPE html>
<html lang="es">
<head runat="server"><meta charset="utf-8" /><meta name="viewport" content="width=device-width, initial-scale=1" /><title>Iniciar sesión · PoliMusic</title><link rel="stylesheet" href="Content/polimusic.css" /><link rel="icon" href="SongCovers/cover-1.svg" type="image/svg+xml" /></head>
<body class="auth-body">
    <a class="brand auth-brand" href="Login.aspx"><span class="brand-mark"><svg><use href="Content/icons.svg#wave" /></svg></span>PoliMusic<span class="brand-dot">.</span></a>
    <main class="auth-card"><span class="eyebrow">TU MÚSICA, A TU RITMO</span><h1>Qué bueno<br />volver a escucharte.</h1><p class="auth-intro">Inicia sesión y dale play a tu día.</p>
        <form id="formLogin" runat="server">
            <div class="field"><asp:Label runat="server" AssociatedControlID="txtLogin" Text="Nombre de usuario" /><asp:TextBox ID="txtLogin" runat="server" placeholder="Tu usuario" autocomplete="username" MaxLength="50" /></div>
            <div class="field"><asp:Label runat="server" AssociatedControlID="txtPassword" Text="Contraseña" /><asp:TextBox ID="txtPassword" runat="server" TextMode="Password" placeholder="Tu contraseña" autocomplete="current-password" MaxLength="128" /></div>
            <asp:Button ID="btnLogin" runat="server" Text="Iniciar sesión" OnClick="BtnLogin_Click" CssClass="button primary" />
            <asp:Label ID="lblMessage" runat="server" CssClass="auth-message" role="alert" />
            <div class="auth-bottom">¿Primera vez aquí? <asp:LinkButton ID="LinkButtonNewUser" runat="server" OnClick="LinkButtonNewUser_Click" CausesValidation="false">Crea tu cuenta</asp:LinkButton></div>
        </form>
    </main>
    <p class="auth-caption">PoliMusic · La música nos conecta.</p>
</body>
</html>
