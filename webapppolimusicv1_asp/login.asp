<%@ Language="VBScript" CodePage="65001" %>
<% Option Explicit %>
<!--#include file="includes/common.asp"-->
<%
Dim errorMessage, username, password, connection, command, users, failed, loginBlocked
errorMessage = ""
username = ""
If Len(TextValue(Session("usuario"))) > 0 Then Response.Redirect "index.asp"
loginBlocked = False
If IsDate(Session("login_after")) Then loginBlocked = (Now < Session("login_after"))
If Request.ServerVariables("REQUEST_METHOD") = "POST" Then
    RequirePost
    username = Trim(Request.Form("username"))
    password = Request.Form("password")
    If loginBlocked Then
        errorMessage = "Demasiados intentos. Espera un minuto antes de volver a intentarlo."
    ElseIf Len(username) = 0 Or Len(username) > 50 Or Len(password) = 0 Or Len(password) > 50 Then
        errorMessage = "Introduce un usuario y una contraseña válidos."
    Else
        Set connection = OpenDatabase()
        If connection Is Nothing Then
            errorMessage = "No se pudo conectar con el servicio de música. Inténtalo de nuevo en unos momentos."
            Response.Status = "503 Service Unavailable"
        Else
            ' Compatibilidad con las contraseñas de texto y SHA1 presentes en el SQL original.
            Set command = DbCommand(connection, "SELECT TOP (1) ID_USER, USERNAME, USER_TYPE, USER_PHOTO, CONVERT(varchar(36), NEWID()) + CONVERT(varchar(36), NEWID()) AS CSRF_TOKEN FROM dbo.TBL_USER WHERE USERNAME COLLATE Latin1_General_100_BIN2 = ? AND (CONVERT(varbinary(50), PASSWORD) = CONVERT(varbinary(50), ?) OR UPPER(PASSWORD) = CONVERT(varchar(40), HASHBYTES('SHA1', CONVERT(varchar(50), ?)), 2)) AND USER_TYPE IN (0, 1) ORDER BY ID_USER")
            AddParameter command, "username", adVarChar, 50, username
            AddParameter command, "password", adVarChar, 50, password
            AddParameter command, "legacyPassword", adVarChar, 50, password
            On Error Resume Next
            Set users = command.Execute
            failed = (Err.Number <> 0)
            Err.Clear
            On Error GoTo 0
            If failed Then
                errorMessage = "No se pudo iniciar sesión. Inténtalo de nuevo en unos momentos."
                Response.Status = "503 Service Unavailable"
            ElseIf users.EOF Then
                errorMessage = "El usuario o la contraseña no son correctos."
                Session("login_attempts") = CLng(0 & TextValue(Session("login_attempts"))) + 1
                If Session("login_attempts") >= 5 Then
                    Session("login_after") = DateAdd("n", 1, Now)
                    Session("login_attempts") = 0
                End If
            Else
                Session("usuario") = CStr(users("USERNAME"))
                Session("id_usuario") = CLng(users("ID_USER"))
                Session("foto_usuario") = TextValue(users("USER_PHOTO"))
                Session("rol") = "normal"
                If CLng(users("USER_TYPE")) = 1 Then Session("rol") = "admin"
                Session("csrf") = CStr(users("CSRF_TOKEN"))
                Session("login_attempts") = 0
                Session.Contents.Remove "login_after"
            End If
            If Not failed Then users.Close
            Set users = Nothing
            Set command = Nothing
            connection.Close
            Set connection = Nothing
            If Len(TextValue(Session("usuario"))) > 0 Then Response.Redirect "index.asp"
        End If
    End If
End If
%>
<!doctype html>
<html lang="es">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta name="theme-color" content="#ffffff">
    <title>Inicia sesión · PoliMusic</title>
    <link rel="icon" href="assets/PlaylistImages/default.jpg" type="image/jpeg">
    <link rel="stylesheet" href="style.css?v=<%= H(ASSET_VERSION) %>">
</head>
<body class="login-page">
    <main class="login-layout">
        <section class="login-story" aria-label="Bienvenido a PoliMusic">
            <a class="brand" href="login.asp"><span class="brand-mark"><%= Icon("music") %></span>PoliMusic<span class="brand-dot">.</span></a>
            <div class="story-copy"><span class="eyebrow">TU MÚSICA. TU MOMENTO.</span><h1>Hay una canción<br> para cada versión<br> de ti<span>.</span></h1><p>Desconecta del ruido.<br>Conecta con lo que te mueve.</p></div>
            <div class="vinyl-scene" aria-hidden="true"><div class="vinyl-sleeve"><img src="assets/PlaylistImages/playlist3.png" alt=""></div><div class="vinyl-record"><span><%= Icon("music") %></span></div><div class="floating-note"><%= Icon("headphones") %> Dale play a tu día</div></div>
            <p class="story-footer">Un espacio para descubrir, escuchar y volver a sentir.</p>
        </section>
        <section class="login-form-panel">
            <div class="login-form-wrap"><span class="small-label">QUÉ BUENO TENERTE AQUÍ</span><h2>Vuelve a tu ritmo.</h2><p class="muted">Inicia sesión y encuentra tu próxima canción favorita.</p>
                <% If Len(errorMessage) > 0 Then %><div class="notice error" role="alert"><%= H(errorMessage) %></div><% End If %>
                <form method="post" action="login.asp" class="stack-form">
                    <input type="hidden" name="csrf" value="<%= H(CsrfToken()) %>">
                    <label for="username">Usuario</label>
                    <input id="username" name="username" autocomplete="username" placeholder="Tu nombre de usuario" maxlength="50" value="<%= H(username) %>" required autofocus>
                    <label for="password">Contraseña</label>
                    <input id="password" name="password" type="password" autocomplete="current-password" placeholder="Tu contraseña" maxlength="50" required>
                    <button class="button primary login-submit" type="submit">Entrar a PoliMusic <%= Icon("arrow") %></button>
                </form>
                <p class="login-note"><%= Icon("headphones") %> Lo único que necesitas es darle play.</p>
            </div>
            <footer class="login-footer">POLIMUSIC <span>Hecho para escuchar a tu manera.</span></footer>
        </section>
    </main>
</body>
</html>
