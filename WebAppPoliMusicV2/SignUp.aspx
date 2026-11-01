<%@ Page Language="C#" AutoEventWireup="true" CodeBehind="SignUp.aspx.cs" Inherits="WebAppPoliMusicV2.SignUp" %>
<!DOCTYPE html>
<html lang="es">
<head runat="server"><meta charset="utf-8" /><meta name="viewport" content="width=device-width, initial-scale=1" /><title>Crea tu cuenta · PoliMusic</title><link rel="stylesheet" href="Content/polimusic.css" /></head>
<body class="auth-body">
    <a class="brand auth-brand" href="Login.aspx"><span class="brand-mark"><svg><use href="Content/icons.svg#wave" /></svg></span>PoliMusic<span class="brand-dot">.</span></a>
    <main class="auth-card"><span class="eyebrow">TU PRÓXIMA CANCIÓN FAVORITA TE ESPERA</span><h1>Empieza a sonar.</h1><p class="auth-intro">Crea tu cuenta y encuentra tu ritmo.</p>
        <form id="formLogin" runat="server" enctype="multipart/form-data">
            <div class="field"><asp:Label runat="server" AssociatedControlID="txtUserName" Text="Nombre de usuario *" /><asp:TextBox ID="txtUserName" runat="server" MaxLength="50" autocomplete="username" /></div>
            <div class="field"><asp:Label runat="server" AssociatedControlID="txtEmail" Text="Correo electrónico *" /><asp:TextBox ID="txtEmail" runat="server" MaxLength="50" autocomplete="email" /></div>
            <div class="field"><asp:Label runat="server" AssociatedControlID="txtPassword" Text="Contraseña *" /><asp:TextBox ID="txtPassword" runat="server" TextMode="Password" autocomplete="new-password" /></div>
            <div class="field"><asp:Label runat="server" AssociatedControlID="txtConfirmPassword" Text="Confirma tu contraseña *" /><asp:TextBox ID="txtConfirmPassword" runat="server" TextMode="Password" autocomplete="new-password" /></div>
            <div class="field"><asp:Label runat="server" AssociatedControlID="txtBirthDate" Text="Fecha de nacimiento" /><asp:TextBox ID="txtBirthDate" runat="server" placeholder="dd/MM/yyyy" autocomplete="bday" /><small class="field-hint">Opcional · día/mes/año</small></div>
            <div class="field"><asp:Label runat="server" AssociatedControlID="fupPhoto" Text="Foto de perfil" /><asp:FileUpload ID="fupPhoto" runat="server" accept="image/png,image/jpeg" /></div>
            <asp:Button ID="btnSumbit" runat="server" Text="Crear cuenta" OnClick="btnSumbit_Click" CssClass="button primary" />
            <asp:Panel ID="frmConfirmation" runat="server"><asp:Label ID="lblMessage" runat="server" CssClass="auth-message" role="alert" /></asp:Panel>
            <div class="auth-bottom">¿Ya tienes cuenta? <asp:HyperLink ID="HyperLink1" NavigateUrl="~/Login.aspx" runat="server">Inicia sesión</asp:HyperLink></div>
        </form>
    </main>
    <p class="auth-caption">PoliMusic · La música nos conecta.</p>
</body>
</html>
