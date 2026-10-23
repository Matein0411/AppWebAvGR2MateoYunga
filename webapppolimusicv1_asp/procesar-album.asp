<%@ Language="VBScript" CodePage="65001" %>
<% Option Explicit %>
<!--#include file="includes/common.asp"-->
<%
RequireAdmin
RequirePost
Dim action, id, albumTitle, albumYear, albumPath, yearValue, selectedSongs, songId, key, i
Dim connection, command, records, affected, failed, transactionStarted, albumMissing, songMissing
action = TextValue(Request.Form("action"))
id = PositiveId(Request.Form("id"))
If action <> "save" And action <> "delete" Then FailRequest "400 Bad Request", "La operación no es válida."
If action = "delete" And id = 0 Then FailRequest "400 Bad Request", "El identificador del álbum no es válido."
Set selectedSongs = Server.CreateObject("Scripting.Dictionary")
If action = "save" Then
    If Request.Form("id") <> "0" And id = 0 Then FailRequest "400 Bad Request", "El identificador del álbum no es válido."
    albumTitle = Trim(Request.Form("album_title"))
    albumYear = Trim(Request.Form("album_year"))
    albumPath = Trim(Request.Form("album_path"))
    For i = 1 To Request.Form("song_ids").Count
        songId = PositiveId(Request.Form("song_ids")(i))
        If songId = 0 Then FailRequest "400 Bad Request", "La selección de canciones no es válida."
        If Not selectedSongs.Exists(CStr(songId)) Then selectedSongs.Add CStr(songId), True
    Next
    If Len(albumTitle) = 0 Or Len(albumTitle) > 50 Then AlbumFormError "El nombre debe tener entre 1 y 50 caracteres."
    yearValue = Null
    If Len(albumYear) > 0 Then
        yearValue = PositiveId(albumYear)
        If yearValue = 0 Or Len(albumYear) > 4 Then AlbumFormError "Escribe un año entero entre 1 y 9999, o deja el campo vacío."
    End If
    If Len(albumPath) > 255 Then AlbumFormError "La ruta de portada no puede superar los 255 caracteres."
    If Len(albumPath) > 0 Then
        If Not IsCoverPath(albumPath) Then AlbumFormError "Usa una imagen local JPG, PNG, WebP, GIF o SVG dentro de assets, o deja la portada vacía."
    End If
End If
Set connection = OpenDatabase()
If connection Is Nothing Then
    If action = "save" Then AlbumFormError "No se pudo conectar con el catálogo. Los datos del formulario se han conservado."
    FailRequest "503 Service Unavailable", "No se pudo conectar con el catálogo. El álbum no se eliminó."
End If

failed = False
albumMissing = False
songMissing = False
On Error Resume Next
connection.BeginTrans
transactionStarted = (Err.Number = 0)
failed = Not transactionStarted
Err.Clear
On Error GoTo 0

If Not failed And id > 0 Then
    Set command = DbCommand(connection, "SELECT ID_ALBUM FROM dbo.TBL_ALBUM WITH (UPDLOCK, HOLDLOCK) WHERE ID_ALBUM = ?")
    AddParameter command, "id", adInteger, 4, id
    On Error Resume Next
    Set records = command.Execute
    failed = (Err.Number <> 0)
    Err.Clear
    On Error GoTo 0
    If Not failed Then
        albumMissing = records.EOF
        records.Close
        Set records = Nothing
    End If
End If

If Not failed And Not albumMissing Then
    If action = "delete" Then
        ' Solo se retiran los vínculos de este álbum. Las canciones y sus otros vínculos se conservan.
        ExecuteAlbumDelete "DELETE FROM dbo.TBL_TRACKLIST WHERE ID_ALBUM = ?"
        If Not failed Then ExecuteAlbumDelete "DELETE FROM dbo.TBL_ALBUM WHERE ID_ALBUM = ?"
    Else
        If id = 0 Then
            Set command = DbCommand(connection, "SET NOCOUNT ON; INSERT INTO dbo.TBL_ALBUM (TITLE_ALBUM, RELEASE_YEAR, ALBUM_IMAGE_PATH) VALUES (?, ?, ?); SELECT CONVERT(int, SCOPE_IDENTITY()) AS ID_ALBUM;")
        Else
            Set command = DbCommand(connection, "UPDATE dbo.TBL_ALBUM SET TITLE_ALBUM = ?, RELEASE_YEAR = ?, ALBUM_IMAGE_PATH = ? WHERE ID_ALBUM = ?")
        End If
        AddParameter command, "title", adVarChar, 50, albumTitle
        AddParameter command, "year", adInteger, 4, yearValue
        AddParameter command, "cover", adVarChar, 255, albumPath
        If id > 0 Then AddParameter command, "id", adInteger, 4, id
        On Error Resume Next
        If id = 0 Then
            Set records = command.Execute
            If Err.Number = 0 Then id = CLng(records("ID_ALBUM"))
            If Err.Number = 0 Then records.Close
        Else
            command.Execute
        End If
        failed = (Err.Number <> 0)
        Err.Clear
        On Error GoTo 0
        If Not failed Then ExecuteAlbumDelete "DELETE FROM dbo.TBL_TRACKLIST WHERE ID_ALBUM = ?"
        For Each key In selectedSongs.Keys
            If Not failed And Not songMissing Then
                ' INSERT SELECT valida la existencia bajo bloqueo hasta completar la transacción.
                Set command = DbCommand(connection, "SET NOCOUNT ON; INSERT INTO dbo.TBL_TRACKLIST (ID_ALBUM, ID_SONG) SELECT ?, ID_SONG FROM dbo.TBL_SONG WITH (HOLDLOCK) WHERE ID_SONG = ?; SELECT @@ROWCOUNT AS ADDED;")
                AddParameter command, "album", adInteger, 4, id
                AddParameter command, "song", adInteger, 4, CLng(key)
                affected = 0
                On Error Resume Next
                Set records = command.Execute
                If Err.Number = 0 Then affected = CLng(records("ADDED"))
                If Err.Number = 0 Then records.Close
                failed = (Err.Number <> 0)
                Err.Clear
                On Error GoTo 0
                If Not failed Then songMissing = (affected = 0)
            End If
        Next
    End If
End If

If Not failed And Not albumMissing And Not songMissing Then
    On Error Resume Next
    connection.CommitTrans
    failed = (Err.Number <> 0)
    Err.Clear
    On Error GoTo 0
End If
If transactionStarted And (failed Or albumMissing Or songMissing) Then
    On Error Resume Next
    connection.RollbackTrans
    Err.Clear
    On Error GoTo 0
End If
connection.Close
Set records = Nothing
Set command = Nothing
Set connection = Nothing
If albumMissing Then FailRequest "404 Not Found", "Este álbum ya no existe en el catálogo."
If action = "save" And (failed Or songMissing) Then
    ' Un alta fallida debe volver al formulario nuevo: el ID de la transacción se revirtió.
    id = PositiveId(Request.Form("id"))
    If songMissing Then AlbumFormError "Una canción seleccionada ya no existe. Revisa la selección; no se guardó ningún cambio."
    AlbumFormError "No se pudieron guardar los cambios. Se revirtió toda la operación y se conservaron los datos del formulario."
End If
If failed Then FailRequest "503 Service Unavailable", "No se pudo eliminar el álbum. Se revirtieron los cambios."
If action = "delete" Then
    Session("flash") = "Álbum eliminado. Sus canciones se conservan en el catálogo."
Else
    Session("flash") = "El álbum y su selección de canciones se guardaron."
End If
Response.Redirect "index.asp#gestionar-albumes"

Sub AlbumFormError(message)
    Session("album_form_id") = CStr(id)
    Session("album_form_title") = albumTitle
    Session("album_form_year") = albumYear
    Session("album_form_path") = albumPath
    Session("album_form_songs") = Join(selectedSongs.Keys, ",")
    Session("album_form_error") = message
    If id > 0 Then Response.Redirect "album.asp?id=" & id
    Response.Redirect "album.asp"
    Response.End
End Sub

Sub ExecuteAlbumDelete(sql)
    Set command = DbCommand(connection, sql)
    AddParameter command, "id", adInteger, 4, id
    On Error Resume Next
    command.Execute
    failed = (Err.Number <> 0)
    Err.Clear
    On Error GoTo 0
End Sub
%>
