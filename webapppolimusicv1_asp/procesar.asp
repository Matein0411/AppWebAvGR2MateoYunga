<%@ Language="VBScript" CodePage="65001" %>
<% Option Explicit %>
<!--#include file="includes/common.asp"-->
<%
RequireAdmin
RequirePost
Dim action, id, songName, songPath, connection, command, records, failed, transactionStarted
action = TextValue(Request.Form("action"))
id = PositiveId(Request.Form("id"))
If action <> "save" And action <> "delete" Then FailRequest "400 Bad Request", "La operación no es válida."
If action = "delete" And id = 0 Then FailRequest "400 Bad Request", "El identificador no es válido."
If action = "save" Then
    If Request.Form("id") <> "0" And id = 0 Then FailRequest "400 Bad Request", "El identificador no es válido."
    songName = Trim(Request.Form("song_name"))
    songPath = Trim(Request.Form("song_path"))
    If Len(songName) = 0 Or Len(songName) > 50 Then FormError "El nombre debe tener entre 1 y 50 caracteres."
    If Len(songPath) = 0 Or Len(songPath) > 255 Then FormError "La ruta debe tener entre 1 y 255 caracteres."
    If Len(SafeLocalPath(songPath)) = 0 Or LCase(Right(songPath, 4)) <> ".mp3" Then FormError "Usa una ruta MP3 local dentro de las carpetas de recursos permitidas."
End If
Set connection = OpenDatabase()
If connection Is Nothing Then
    If action = "save" Then FormError "No se pudo conectar con SQL Server. Los datos del formulario se han conservado."
    FailRequest "503 Service Unavailable", "No se pudo conectar con SQL Server. La canción no se eliminó."
End If

failed = False
transactionStarted = False
On Error Resume Next
connection.BeginTrans
transactionStarted = (Err.Number = 0)
If Not transactionStarted Then failed = True
Err.Clear
On Error GoTo 0
If Not failed And id > 0 Then
    ' Comprueba la existencia y conserva la canción durante ediciones y eliminaciones.
    Set command = DbCommand(connection, "SELECT ID_SONG FROM dbo.TBL_SONG WITH (UPDLOCK, HOLDLOCK) WHERE ID_SONG = ?")
    AddParameter command, "id", adInteger, 4, id
    On Error Resume Next
    Set records = command.Execute
    failed = (Err.Number <> 0)
    Err.Clear
    On Error GoTo 0
    If Not failed Then
        If records.EOF Then
            records.Close
            connection.RollbackTrans
            connection.Close
            FailRequest "404 Not Found", "La canción ya no existe."
        End If
        records.Close
        Set records = Nothing
    End If
End If
If Not failed Then
    If action = "delete" Then
        ExecuteDelete "DELETE FROM dbo.TBL_PLAYLIST_SONG WHERE ID_SONG = ?"
        If Not failed Then ExecuteDelete "DELETE FROM dbo.TBL_PLAYER WHERE ID_SONG = ?"
        If Not failed Then ExecuteDelete "DELETE FROM dbo.TBL_TRACKLIST WHERE ID_SONG = ?"
        If Not failed Then ExecuteDelete "DELETE FROM dbo.TBL_SONG WHERE ID_SONG = ?"
    Else
        If id = 0 Then
            Set command = DbCommand(connection, "INSERT INTO dbo.TBL_SONG (SONG_NAME, SONG_PATH, PLAYS) VALUES (?, ?, 0)")
        Else
            Set command = DbCommand(connection, "UPDATE dbo.TBL_SONG SET SONG_NAME = ?, SONG_PATH = ? WHERE ID_SONG = ?")
        End If
        AddParameter command, "name", adVarChar, 50, songName
        AddParameter command, "path", adVarChar, 255, songPath
        If id > 0 Then AddParameter command, "id", adInteger, 4, id
        On Error Resume Next
        command.Execute
        failed = (Err.Number <> 0)
        Err.Clear
        On Error GoTo 0
    End If
End If

If Not failed Then
    On Error Resume Next
    connection.CommitTrans
    failed = (Err.Number <> 0)
    Err.Clear
    On Error GoTo 0
End If
If failed And transactionStarted Then
    On Error Resume Next
    connection.RollbackTrans
    Err.Clear
    On Error GoTo 0
End If
connection.Close
Set command = Nothing
Set connection = Nothing
If failed Then
    If action = "save" Then FormError "No se pudieron guardar los cambios. Revisa la conexión e inténtalo de nuevo."
    FailRequest "503 Service Unavailable", "No se pudo eliminar la canción. Se revirtieron los cambios de la operación."
End If
If action = "delete" Then
    Session("flash") = "Canción eliminada del catálogo."
ElseIf id = 0 Then
    Session("flash") = "Tu nueva canción ya está en el catálogo."
Else
    Session("flash") = "Los cambios de la canción se guardaron."
End If
Response.Redirect "index.asp#catalogo"

Sub FormError(message)
    Session("form_id") = CStr(id)
    Session("form_name") = songName
    Session("form_path") = songPath
    Session("form_error") = message
    If id > 0 Then Response.Redirect "cancion.asp?id=" & id
    Response.Redirect "cancion.asp"
    Response.End
End Sub

Sub ExecuteDelete(sql)
    Set command = DbCommand(connection, sql)
    AddParameter command, "id", adInteger, 4, id
    On Error Resume Next
    command.Execute
    failed = (Err.Number <> 0)
    Err.Clear
    On Error GoTo 0
End Sub
%>
