<%@ Language="VBScript" CodePage="65001" %>
<% Option Explicit %>
<!--#include file="includes/common.asp"-->
<%
' Colección privada por usuario en las tablas existentes. GET nunca crea datos.
Dim userId, songId, desired, connection, command, records, sql, failed, transactionStarted
Dim liked, total, resultCode
Response.ContentType = "application/json"
userId = PositiveId(Session("id_usuario"))
If userId = 0 Or Len(TextValue(Session("usuario"))) = 0 Then JsonError "401 Unauthorized", "Inicia sesión para guardar tus canciones."
RequireLogin
RequirePost
songId = PositiveId(Request.Form("id"))
desired = TextValue(Request.Form("liked"))
If songId = 0 Or (desired <> "0" And desired <> "1") Then JsonError "400 Bad Request", "La canción o la acción no son válidas."
Set connection = OpenDatabase()
If connection Is Nothing Then JsonError "503 Service Unavailable", "No se pudo conectar con tu biblioteca. Inténtalo de nuevo."

' El bloqueo de la fila del usuario serializa sus solicitudes sin índices ni tablas nuevos.
' El estado deseado es idempotente: repetir un POST no duplica ni invierte el favorito.
sql = "SET NOCOUNT ON; DECLARE @UserId int = ?, @SongId int = ?, @Liked int = ?, @Title varchar(50) = ?, @PlaylistId int, @LockedUser int, @SongExists int; " & _
    "SELECT @LockedUser = ID_USER FROM dbo.TBL_USER WITH (UPDLOCK, HOLDLOCK) WHERE ID_USER = @UserId; " & _
    "SELECT @SongExists = ID_SONG FROM dbo.TBL_SONG WITH (HOLDLOCK) WHERE ID_SONG = @SongId; " & _
    "IF @LockedUser IS NULL SELECT 401 AS CODE, 0 AS LIKED, 0 AS TOTAL; " & _
    "ELSE IF @SongExists IS NULL SELECT 404 AS CODE, 0 AS LIKED, 0 AS TOTAL; " & _
    "ELSE BEGIN " & _
    "SELECT TOP (1) @PlaylistId = ID_PLAYLIST FROM dbo.TBL_PLAYLIST WHERE ID_USER = @UserId AND TYPE = 1 AND TITLE = @Title ORDER BY ID_PLAYLIST; " & _
    "IF @Liked = 1 BEGIN " & _
    "IF @PlaylistId IS NULL BEGIN INSERT INTO dbo.TBL_PLAYLIST (ID_USER, TITLE, CREATION_DATE, TYPE, PHOTO) VALUES (@UserId, @Title, GETDATE(), 1, 'assets/PlaylistImages/default.jpg'); SET @PlaylistId = CONVERT(int, SCOPE_IDENTITY()); END; " & _
    "INSERT INTO dbo.TBL_PLAYLIST_SONG (ID_PLAYLIST, ID_SONG) SELECT @PlaylistId, @SongId WHERE NOT EXISTS (SELECT 1 FROM dbo.TBL_PLAYLIST_SONG WHERE ID_PLAYLIST = @PlaylistId AND ID_SONG = @SongId); " & _
    "END ELSE DELETE FROM dbo.TBL_PLAYLIST_SONG WHERE ID_PLAYLIST = @PlaylistId AND ID_SONG = @SongId; " & _
    "SELECT 200 AS CODE, CASE WHEN EXISTS (SELECT 1 FROM dbo.TBL_PLAYLIST_SONG WHERE ID_PLAYLIST = @PlaylistId AND ID_SONG = @SongId) THEN 1 ELSE 0 END AS LIKED, (SELECT COUNT(*) FROM dbo.TBL_PLAYLIST_SONG WHERE ID_PLAYLIST = @PlaylistId) AS TOTAL; END;"
Set command = DbCommand(connection, sql)
AddParameter command, "userId", adInteger, 4, userId
AddParameter command, "songId", adInteger, 4, songId
AddParameter command, "liked", adInteger, 4, CLng(desired)
AddParameter command, "title", adVarChar, 50, LIKES_PLAYLIST_TITLE
failed = False
transactionStarted = False
On Error Resume Next
connection.BeginTrans
transactionStarted = (Err.Number = 0)
failed = Not transactionStarted
Err.Clear
If Not failed Then
    Set records = command.Execute
    failed = (Err.Number <> 0)
    Err.Clear
End If
If Not failed Then
    resultCode = CLng(records("CODE"))
    liked = (CLng(records("LIKED")) = 1)
    total = CLng(records("TOTAL"))
    records.Close
    failed = (Err.Number <> 0)
    Err.Clear
End If
If Not failed Then
    connection.CommitTrans
    failed = (Err.Number <> 0)
    Err.Clear
End If
If failed And transactionStarted Then
    connection.RollbackTrans
    Err.Clear
End If
On Error GoTo 0
connection.Close
Set records = Nothing
Set command = Nothing
Set connection = Nothing
If failed Then JsonError "503 Service Unavailable", "No se pudo guardar el cambio. Inténtalo de nuevo."
If resultCode = 401 Then JsonError "401 Unauthorized", "Tu usuario ya no está disponible. Inicia sesión de nuevo."
If resultCode = 404 Then JsonError "404 Not Found", "Esta canción ya no existe en el catálogo."
If liked Then
    Response.Write "{""ok"":true,""liked"":true,""count"":" & total & "}"
Else
    Response.Write "{""ok"":true,""liked"":false,""count"":" & total & "}"
End If

Sub JsonError(status, message)
    Response.Status = status
    Response.Write "{""ok"":false,""message"":""" & message & """}"
    Response.End
End Sub
%>
