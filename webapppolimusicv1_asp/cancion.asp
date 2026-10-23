<%@ Language="VBScript" CodePage="65001" %>
<% Option Explicit %>
<!--#include file="includes/common.asp"-->
<%
RequireAdmin
Dim id, songName, songPath, errorMessage, connection, command, records, failed, heading
id = 0
songName = ""
songPath = ""
errorMessage = ""
If Len(Request.QueryString("id")) > 0 Then
    id = PositiveId(Request.QueryString("id"))
    If id = 0 Then FailRequest "400 Bad Request", "El identificador de la canción no es válido."
End If
If id > 0 Then
    Set connection = OpenDatabase()
    If connection Is Nothing Then FailRequest "503 Service Unavailable", "No se pudo conectar con el catálogo. Inténtalo de nuevo en unos momentos."
    Set command = DbCommand(connection, "SELECT SONG_NAME, SONG_PATH FROM dbo.TBL_SONG WHERE ID_SONG = ?")
    AddParameter command, "id", adInteger, 4, id
    On Error Resume Next
    Set records = command.Execute
    failed = (Err.Number <> 0)
    Err.Clear
    On Error GoTo 0
    If failed Then
        connection.Close
        FailRequest "503 Service Unavailable", "No se pudo consultar la canción."
    End If
    If records.EOF Then
        records.Close
        connection.Close
        FailRequest "404 Not Found", "Esta canción ya no existe en el catálogo."
    End If
    songName = TextValue(records("SONG_NAME"))
    songPath = TextValue(records("SONG_PATH"))
    records.Close
    connection.Close
    Set records = Nothing
    Set command = Nothing
    Set connection = Nothing
End If
If TextValue(Session("form_id")) = CStr(id) Then
    errorMessage = TextValue(Session("form_error"))
    songName = TextValue(Session("form_name"))
    songPath = TextValue(Session("form_path"))
    Session.Contents.Remove "form_id"
    Session.Contents.Remove "form_error"
    Session.Contents.Remove "form_name"
    Session.Contents.Remove "form_path"
End If
heading = "Una nueva canción, otro buen momento."
If id > 0 Then heading = "Ajusta los detalles de tu canción."

Sub RenderAudioOptions(relativeFolder)
    Dim fs, folder, file, child
    Set fs = Server.CreateObject("Scripting.FileSystemObject")
    If fs.FolderExists(Server.MapPath(relativeFolder)) Then
        Set folder = fs.GetFolder(Server.MapPath(relativeFolder))
        For Each file In folder.Files
            If LCase(fs.GetExtensionName(file.Name)) = "mp3" Then Response.Write "<option value=""" & H(relativeFolder & "/" & file.Name) & """></option>"
        Next
        For Each child In folder.SubFolders
            If (child.Attributes And 1024) = 0 Then RenderAudioOptions relativeFolder & "/" & child.Name
        Next
    End If
    Set fs = Nothing
End Sub
%>
<!doctype html>
<html lang="es">
<head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title><% If id > 0 Then %>Editar<% Else %>Agregar<% End If %> canción · PoliMusic</title><link rel="icon" href="assets/PlaylistImages/default.jpg" type="image/jpeg"><link rel="stylesheet" href="style.css?v=<%= H(ASSET_VERSION) %>"></head>
<body class="editor-page">
    <header class="editor-header"><a class="brand" href="index.asp#catalogo"><span class="brand-mark"><%= Icon("music") %></span>PoliMusic<span class="brand-dot">.</span></a><a class="text-button" href="index.asp#catalogo">Volver al catálogo <%= Icon("arrow") %></a></header>
    <main class="song-editor"><section class="editor-story"><span class="eyebrow">ESPACIO DEL ADMINISTRADOR</span><h1><%= H(heading) %></h1><p>Los pequeños detalles hacen una gran biblioteca. Dale a cada canción su lugar.</p><img src="assets/PlaylistImages/playlist2.png" alt="Colección de discos de vinilo" class="editor-cover"></section>
    <section class="editor-form"><h2><% If id > 0 Then %>Editar canción<% Else %>Agregar canción<% End If %></h2><p class="muted">Completa la información del catálogo.</p>
        <% If Len(errorMessage) > 0 Then %><div class="notice error" role="alert"><%= H(errorMessage) %></div><% End If %>
        <form class="stack-form" method="post" action="procesar.asp">
            <input type="hidden" name="csrf" value="<%= H(CsrfToken()) %>"><input type="hidden" name="action" value="save"><input type="hidden" name="id" value="<%= id %>">
            <label for="song-name">Nombre de la canción <span class="required">*</span></label><input id="song-name" name="song_name" value="<%= H(songName) %>" maxlength="50" placeholder="Ej. Adventure" required autofocus>
            <label for="song-path">Ruta del archivo MP3 <span class="required">*</span></label><input id="song-path" name="song_path" value="<%= H(songPath) %>" maxlength="255" placeholder="assets/SongFiles/bensound-adventure.mp3" list="audio-files" aria-describedby="path-help" required>
            <datalist id="audio-files"><% RenderAudioOptions "assets" %></datalist>
            <p class="field-help" id="path-help">Elige un archivo local de la lista o escribe una ruta dentro de <code>assets/</code>. También se admiten las rutas originales <code>~/songFiles/</code>, que se buscan en <code>assets/SongFiles/</code>. Si el audio falta, la canción se mostrará como no disponible.</p>
            <div class="editor-info"><%= Icon("disc") %><p><% If id > 0 Then %>Se conservarán las escuchas y las asociaciones actuales con artistas, álbumes y playlists.<% Else %>La canción comenzará con 0 escuchas y aparecerá como sencillo hasta que tenga asociaciones en el catálogo existente.<% End If %></p></div>
            <div class="form-actions"><a class="button secondary" href="index.asp#catalogo">Cancelar</a><button class="button primary" type="submit"><% If id > 0 Then %>Guardar cambios<% Else %>Agregar canción<% End If %><%= Icon("arrow") %></button></div>
        </form>
    </section></main>
</body>
</html>
