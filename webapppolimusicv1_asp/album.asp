<%@ Language="VBScript" CodePage="65001" %>
<% Option Explicit %>
<!--#include file="includes/common.asp"-->
<%
RequireAdmin
Dim id, albumTitle, albumYear, albumPath, errorMessage, connection, command, records, failed
Dim songRows, songCount, selectedSongs, selection, key, i, heading
id = 0
albumTitle = ""
albumYear = ""
albumPath = ""
errorMessage = ""
songCount = 0
Set selectedSongs = Server.CreateObject("Scripting.Dictionary")
If Len(Request.QueryString("id")) > 0 Then
    id = PositiveId(Request.QueryString("id"))
    If id = 0 Then FailRequest "400 Bad Request", "El identificador del álbum no es válido."
End If
Set connection = OpenDatabase()
If connection Is Nothing Then FailRequest "503 Service Unavailable", "No se pudo conectar con el catálogo. Inténtalo de nuevo."
If id > 0 Then
    Set command = DbCommand(connection, "SELECT TITLE_ALBUM, RELEASE_YEAR, ALBUM_IMAGE_PATH FROM dbo.TBL_ALBUM WHERE ID_ALBUM = ?")
    AddParameter command, "id", adInteger, 4, id
    On Error Resume Next
    Set records = command.Execute
    failed = (Err.Number <> 0)
    Err.Clear
    On Error GoTo 0
    If failed Then
        connection.Close
        FailRequest "503 Service Unavailable", "No se pudo consultar el álbum."
    End If
    If records.EOF Then
        records.Close
        connection.Close
        FailRequest "404 Not Found", "Este álbum ya no existe en el catálogo."
    End If
    albumTitle = TextValue(records("TITLE_ALBUM"))
    albumYear = TextValue(records("RELEASE_YEAR"))
    albumPath = TextValue(records("ALBUM_IMAGE_PATH"))
    records.Close
End If
Set command = DbCommand(connection, "SELECT s.ID_SONG, s.SONG_NAME, CASE WHEN EXISTS (SELECT 1 FROM dbo.TBL_TRACKLIST t WHERE t.ID_ALBUM = ? AND t.ID_SONG = s.ID_SONG) THEN 1 ELSE 0 END AS SELECTED FROM dbo.TBL_SONG s ORDER BY s.SONG_NAME, s.ID_SONG")
AddParameter command, "album", adInteger, 4, id
On Error Resume Next
Set records = command.Execute
failed = (Err.Number <> 0)
Err.Clear
On Error GoTo 0
If failed Then
    connection.Close
    FailRequest "503 Service Unavailable", "No se pudo consultar la selección de canciones."
End If
If Not records.EOF Then
    songRows = records.GetRows()
    songCount = UBound(songRows, 2) + 1
End If
records.Close
connection.Close
Set records = Nothing
Set command = Nothing
Set connection = Nothing
For i = 0 To songCount - 1
    If CLng(songRows(2, i)) = 1 Then selectedSongs.Add CStr(songRows(0, i)), True
Next
If TextValue(Session("album_form_id")) = CStr(id) Then
    errorMessage = TextValue(Session("album_form_error"))
    albumTitle = TextValue(Session("album_form_title"))
    albumYear = TextValue(Session("album_form_year"))
    albumPath = TextValue(Session("album_form_path"))
    selectedSongs.RemoveAll
    selection = Split(TextValue(Session("album_form_songs")), ",")
    For Each key In selection
        If PositiveId(key) > 0 Then selectedSongs(CStr(PositiveId(key))) = True
    Next
    Session.Contents.Remove "album_form_id"
    Session.Contents.Remove "album_form_title"
    Session.Contents.Remove "album_form_year"
    Session.Contents.Remove "album_form_path"
    Session.Contents.Remove "album_form_songs"
    Session.Contents.Remove "album_form_error"
End If
heading = "Dale forma a tu próximo álbum."
If id > 0 Then heading = "Cada canción, en su lugar."

Sub RenderCoverChoices(relativeFolder)
    Dim fs, folder, file, path
    Set fs = Server.CreateObject("Scripting.FileSystemObject")
    If fs.FolderExists(Server.MapPath(relativeFolder)) Then
        Set folder = fs.GetFolder(Server.MapPath(relativeFolder))
        For Each file In folder.Files
            path = relativeFolder & "/" & file.Name
            If IsCoverPath(path) Then Response.Write "<button type=""button"" class=""cover-choice"" data-cover-path=""" & H(path) & """ aria-label=""Usar portada " & H(file.Name) & """ aria-pressed=""false""><img src=""" & H(path) & """ alt=""" & H(file.Name) & """ loading=""lazy""></button>"
        Next
    End If
    Set fs = Nothing
End Sub
%>
<!doctype html>
<html lang="es">
<head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><meta name="theme-color" content="#ffffff"><title><% If id > 0 Then %>Editar<% Else %>Agregar<% End If %> álbum · PoliMusic</title><link rel="icon" href="assets/PlaylistImages/default.jpg" type="image/jpeg"><link rel="stylesheet" href="style.css?v=<%= H(ASSET_VERSION) %>"><script src="album.js?v=<%= H(ASSET_VERSION) %>" defer></script></head>
<body class="editor-page">
    <header class="editor-header"><a class="brand" href="index.asp#gestionar-albumes"><span class="brand-mark"><%= Icon("music") %></span>PoliMusic<span class="brand-dot">.</span></a><a class="text-button" href="index.asp#gestionar-albumes">Volver a álbumes <%= Icon("arrow") %></a></header>
    <main class="song-editor album-editor">
        <section class="editor-story"><span class="eyebrow">ESPACIO DEL ADMINISTRADOR</span><h1><%= H(heading) %></h1><p>Elige una portada y reúne las canciones que cuentan su historia.</p><img id="album-preview" class="editor-cover album-preview" src="<%= H(CoverUrl(albumPath, id)) %>" alt="Vista previa de la portada" data-fallback="<%= H(CoverUrl("", id)) %>"><p class="field-help">Las portadas de las canciones se conservan al organizar los álbumes.</p></section>
        <section class="editor-form"><h2><% If id > 0 Then %>Editar álbum<% Else %>Agregar álbum<% End If %></h2><p class="muted">Completa los detalles y selecciona sus canciones.</p>
            <% If Len(errorMessage) > 0 Then %><div class="notice error" role="alert"><%= H(errorMessage) %></div><% End If %>
            <form class="stack-form" method="post" action="procesar-album.asp">
                <input type="hidden" name="csrf" value="<%= H(CsrfToken()) %>"><input type="hidden" name="action" value="save"><input type="hidden" name="id" value="<%= id %>">
                <label for="album-title">Nombre del álbum <span class="required">*</span></label><input id="album-title" name="album_title" value="<%= H(albumTitle) %>" maxlength="50" placeholder="Ej. Noches de verano" required autofocus>
                <label for="album-year">Año de lanzamiento</label><input id="album-year" name="album_year" type="number" min="1" max="9999" step="1" value="<%= H(albumYear) %>" placeholder="Ej. 2026">
                <label for="album-path">Portada del álbum</label><input id="album-path" name="album_path" value="<%= H(albumPath) %>" maxlength="255" placeholder="Elige una portada de abajo" aria-describedby="album-path-help"><p class="field-help" id="album-path-help">Elige una imagen o indica su ruta local en assets. Si la dejas vacía o el archivo no está disponible, se mostrará una portada de respaldo.</p>
                <div class="cover-choices" role="group" aria-label="Portadas disponibles"><% RenderCoverChoices "assets/PlaylistImages"
                    RenderCoverChoices "assets/AlbumImages" %></div>
                <fieldset class="album-songs"><legend>Canciones del álbum</legend><p class="field-help">Puedes incluir una canción en varios álbumes. La selección puede quedar vacía.</p>
                    <label class="song-picker-search" for="song-filter"><%= Icon("search") %><input type="search" id="song-filter" placeholder="Buscar una canción" autocomplete="off" aria-label="Buscar canciones del álbum"></label>
                    <p class="selection-summary" id="selection-summary" role="status" aria-live="polite"></p>
                    <div class="song-choices">
                    <% For i = 0 To songCount - 1 %>
                        <label class="song-choice" data-song-choice><input type="checkbox" name="song_ids" value="<%= CLng(songRows(0, i)) %>" <% If selectedSongs.Exists(CStr(songRows(0, i))) Then %>checked<% End If %>><img src="<%= H(SongCoverUrl(songRows(0, i))) %>" alt="" loading="lazy"><span><strong><%= H(songRows(1, i)) %></strong><small>Canción #<%= CLng(songRows(0, i)) %></small></span></label>
                    <% Next %>
                    </div>
                    <% If songCount = 0 Then %><p class="muted">Todavía no hay canciones. Puedes guardar el álbum y añadirlas después.</p><% End If %>
                    <p class="field-help" id="song-filter-empty" hidden>No hay canciones que coincidan con tu búsqueda.</p>
                </fieldset>
                <div class="editor-info"><%= Icon("disc") %><p>Guardar actualiza los datos del álbum y su selección. Las canciones, sus escuchas, artistas y playlists se conservan.</p></div>
                <div class="form-actions"><a class="button secondary" href="index.asp#gestionar-albumes">Cancelar</a><button class="button primary" type="submit">Guardar álbum <%= Icon("arrow") %></button></div>
            </form>
        </section>
    </main>
</body>
</html>
